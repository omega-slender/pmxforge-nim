## Regression tests for stream tolerance, destination links, and write limits.
##
## Covers a stream that cannot report its position (H01), the destination directory link
## policy (H02), tolerance for a corrupt face count (H03), the repair contract for IK links
## (H04), the documented flag-bit normalization (H05), the shared text budget (H06), the
## pre-copy validation contract (H07), and the staged writer (H08).

import std/[os, osproc, streams, strutils, unittest]
import pmxforge
import ./support

type
  PositionlessStream = ref object of StreamObj
    ## Readable stream that deliberately leaves `getPositionImpl` unset, like
    ## `osproc.FileHandleStream` or a host adapter over a decompressor.
    payload: string
    offset: int

  CollectStream = ref object of StreamObj
    ## Write-only sink with no position support, like a pipe or a socket.
    collected: string

proc plRead(s: Stream, buffer: pointer, bufferLength: int): int {.nimcall, raises: [], gcsafe.} =
  ## Copies up to `bufferLength` bytes from the backing payload.
  let source = PositionlessStream(s)
  if bufferLength <= 0 or source.offset >= source.payload.len:
    return 0
  result = min(bufferLength, source.payload.len - source.offset)
  copyMem(buffer, unsafeAddr source.payload[source.offset], result)
  source.offset += result

proc plAtEnd(s: Stream): bool {.nimcall, raises: [], gcsafe.} =
  ## Reports the end of the backing payload.
  let source = PositionlessStream(s)
  source.offset >= source.payload.len

proc positionless(payload: string): Stream =
  ## Wraps bytes in a stream without a `getPosition` implementation.
  let source = PositionlessStream(payload: payload)
  source.readDataImpl = plRead
  source.atEndImpl = plAtEnd
  Stream(source)

proc csWrite(s: Stream, buffer: pointer, bufferLength: int) {.nimcall, raises: [IOError], gcsafe.} =
  ## Appends to the collected payload.
  let sink = CollectStream(s)
  if bufferLength <= 0:
    return
  let oldLen = sink.collected.len
  sink.collected.setLen(oldLen + bufferLength)
  copyMem(addr sink.collected[oldLen], buffer, bufferLength)

proc collectStream(): CollectStream =
  ## Creates a write-only stream without position support.
  new(result)
  result.writeDataImpl = csWrite

proc rawString(data: seq[byte]): string =
  ## Converts a byte sequence into the raw string a stream carries.
  result = newString(data.len)
  for i, value in data:
    result[i] = char(value)

proc makeDirectoryLink(linkPath, targetPath: string): bool =
  ## Creates a junction on Windows or a directory symlink elsewhere. Returns false when the
  ## platform refuses, so the suite skips instead of failing.
  try:
    when defined(windows):
      let (_, exitCode) = execCmdEx(
        "cmd /c mklink /J \"" & linkPath & "\" \"" & targetPath & "\"")
      result = exitCode == 0
    else:
      createSymlink(targetPath, linkPath)
      result = true
  except CatchableError:
    result = false

proc removeDirectoryLink(path: string) =
  ## Removes a junction or a directory symlink without touching its target. `removeDir`
  ## cannot delete a Windows junction, and its failure would fail the test that created it.
  try:
    when defined(windows):
      discard execCmdEx("cmd /c rmdir \"" & path & "\"")
    else:
      if symlinkExists(path):
        removeFile(path)
  except CatchableError:
    discard

proc scratchRoot(name: string): string =
  ## Returns a unique scratch directory under the system temporary directory.
  result = getTempDir() / ("pmxforge-hardening-" & name & "-" & $getCurrentProcessId())
  removeDir(result)
  createDir(result)

suite "hardening: stream position":
  test "H01 reads a model from a stream that cannot report its position":
    ## `std/streams` calls `getPositionImpl` without a nil check, so this used to be a
    ## SIGSEGV instead of a parse.
    let payload = rawString(writePmx(sampleModel()))
    check readPmx(positionless(payload)).samePmxContent(sampleModel())

  test "H01 a truncated positionless stream fails as truncated":
    let payload = rawString(writePmx(sampleModel()))
    expect PmxTruncatedError:
      discard readPmx(positionless(payload[0 ..< payload.len div 2]))

  test "H01 a stream positioned past the start keeps its whole budget":
    let payload = rawString(writePmx(sampleModel()))
    var s = newStringStream("PAD" & payload)
    s.setPosition(3)
    check readPmx(s).samePmxContent(sampleModel())

suite "hardening: destination directories":
  test "H02 writes a model through a directory link":
    let root = scratchRoot("dir-link")
    defer:
      removeDirectoryLink(root / "alias")
      removeDir(root)
    createDir(root / "real")
    if not makeDirectoryLink(root / "alias", root / "real"):
      skip()
    writePmx(sampleModel(), root / "alias" / "model.pmx")
    check fileExists(root / "real" / "model.pmx")
    check readPmx(root / "real" / "model.pmx").samePmxContent(sampleModel())

  test "H02 refuses a destination that is itself a link":
    let root = scratchRoot("leaf-link")
    defer:
      removeDirectoryLink(root / "leaf.pmx")
      removeDir(root)
    createDir(root / "real")
    if not makeDirectoryLink(root / "leaf.pmx", root / "real"):
      skip()
    expect IOError:
      writePmx(sampleModel(), root / "leaf.pmx")

suite "hardening: reader tolerance":
  test "H03 rounds a material face count down instead of refusing the file":
    let model = newPmxModel(
      nameJA = "f",
      vertices = @[newVertex()],
      faces = @[newFace(0'i32, 0'i32, 0'i32)],
      materials = @[newMaterial(nameJA = "m", faceCount = 1'i32)],
      bones = @[newBone(nameJA = "r")])
    var bytes = writePmx(model)
    var patchAt = -1
    for i in countdown(bytes.len - 4, 0):
      if bytes[i] == 3'u8 and bytes[i + 1] == 0'u8 and bytes[i + 2] == 0'u8 and bytes[i + 3] == 0'u8:
        patchAt = i
        break
    check patchAt > 0
    bytes[patchAt] = 4'u8
    let back = readPmx(bytes)
    check back.materials[0].faceCount == 1'i32
    check back.isValid()

  test "H03 a negative material face count is still a format error":
    let model = newPmxModel(
      nameJA = "f",
      vertices = @[newVertex()],
      faces = @[newFace(0'i32, 0'i32, 0'i32)],
      materials = @[newMaterial(nameJA = "m", faceCount = 1'i32)],
      bones = @[newBone(nameJA = "r")])
    var bytes = writePmx(model)
    var patchAt = -1
    for i in countdown(bytes.len - 4, 0):
      if bytes[i] == 3'u8 and bytes[i + 1] == 0'u8 and bytes[i + 2] == 0'u8 and bytes[i + 3] == 0'u8:
        patchAt = i
        break
    check patchAt > 0
    for offset in 0 .. 3:
      bytes[patchAt + offset] = 0xFF'u8
    expect PmxFormatError:
      discard readPmx(bytes)

  test "H03 consumes a trailing face index so the sections stay aligned":
    ## The model-level index count frames the stream, so dropping the remainder is not
    ## enough: the stray index has to be read, or every following section shifts.
    let model = newPmxModel(
      nameJA = "f",
      vertices = @[newVertex()],
      faces = @[newFace(0'i32, 0'i32, 0'i32)],
      materials = @[newMaterial(nameJA = "m", faceCount = 1'i32)],
      bones = @[newBone(nameJA = "r")])
    let bytes = writePmx(model)
    let signature = @[3'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    var at = -1
    var matches = 0
    for i in 0 .. bytes.len - signature.len:
      var same = true
      for j in 0 ..< signature.len:
        if bytes[i + j] != signature[j]:
          same = false
          break
      if same:
        inc matches
        if at < 0:
          at = i
    check matches == 1
    check at > 0
    var corrupt = bytes[0 ..< at]
    corrupt.add @[4'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8, 0'u8]
    for i in at + 7 ..< bytes.len:
      corrupt.add bytes[i]
    let back = readPmx(corrupt)
    check back.faces.len == 1
    check back.nameJA == "f"
    check back.isValid()

suite "hardening: repair contract":
  test "H04 repair clears IK links when the IK flag is off":
    var bone = newBone(nameJA = "b")
    bone.flags.ik = false
    bone.ik.links = @[newIKLink(boneIndex = 0'i32)]
    check bone.ik.links.len == 1
    bone.repair()
    check bone.ik.links.len == 0

  test "H04 repair keeps IK links when the flag is set":
    var bone = newBone(nameJA = "b")
    bone.flags.ik = true
    bone.ik = newBoneIK(targetIndex = 0'i32, loopCount = 1'i32,
                        links = @[newLimitedIKLink(boneIndex = 0'i32)])
    bone.repair()
    check bone.ik.links.len == 1

suite "hardening: documented normalisation":
  test "H05 undefined bone flag bits are dropped on read":
    ## Documented behavior: only the bits this library models survive a read/write pair.
    check toMask(toBoneFlags(0xC002)) == 0x0002
    check toMask(toBoneFlags(0x0042)) == 0x0002

suite "hardening: write limits":
  test "H06 PmxWriteLimits carries the text budget into validation and encoding":
    let bigName = repeat('a', 70_000)
    let model = newPmxModel(nameJA = bigName)
    expect ValueError:
      discard writePmx(model)
    let limits = PmxWriteLimits(maxOutputBytes: 4 * 1024 * 1024, maxStringBytes: 200_000)
    let bytes = writePmx(model, limits)
    check bytes.len > bigName.len
    var readLimits = SafePmxReadLimits
    readLimits.maxStringBytes = 200_000
    check readPmx(bytes, readLimits).nameJA.len == bigName.len
    expect ValueError:
      discard writePmx(model, limits, maxStringBytes = 1024)

  test "H06 an invalid limit configuration fails before anything is written":
    expect ValueError:
      discard writePmx(sampleModel(), PmxWriteLimits(maxOutputBytes: 1024, maxStringBytes: -5))

suite "hardening: pre-copy validation":
  test "H07 a nil element is rejected in every write mode":
    var model = sampleModel()
    model.bones.add(nil)
    expect ValueError:
      discard writePmx(model)
    expect ValueError:
      discard writePmx(model, mode = pwmRepair)
    expect ValueError:
      discard writePmx(model, mode = pwmLenient)

suite "hardening: staged writer":
  test "H08 the byte sink returns exactly the payload it accepted":
    let model = sampleModel()
    let first = writePmx(model)
    let second = writePmx(model)
    check first == second
    check readPmx(first).samePmxContent(model)

  test "H08 a stream write truncates a longer previous payload":
    let model = sampleModel()
    let payload = writePmx(model)
    var s = newStringStream(repeat('x', payload.len * 2))
    s.setPosition(0)
    writePmx(model, s)
    check StringStream(s).data.len == payload.len
    check readPmx(newStringStream(StringStream(s).data)).samePmxContent(model)

  test "H08 a write-only stream without position support receives the payload":
    let model = sampleModel()
    let payload = writePmx(model)
    let sink = collectStream()
    writePmx(model, sink)
    check sink.collected.len == payload.len
    check readPmx(newStringStream(sink.collected)).samePmxContent(model)
