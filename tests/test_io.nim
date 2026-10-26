## Reading and writing.
##
## Provides round-trip checks over the byte, stream, and path overloads, plus the write
## modes and the resource limits.

import std/os
import std/streams
import std/strutils
import std/unittest
import pmxforge
import ./support

proc tempPmxPath(name: string): string =
  ## Returns a unique destination under the system temporary directory.
  result = getTempDir() / ("pmxforge-" & name & "-" & $getCurrentProcessId() & ".pmx")

proc streamOf(data: seq[byte]): Stream =
  ## Wraps bytes in a stream whose total length the reader cannot know up front.
  var text = newString(data.len)
  for i, value in data:
    text[i] = char(value)
  newStringStream(text)

proc writeLe32(data: var seq[byte], offset: int, value: int32) =
  ## Replaces the little-endian int32 at `offset`.
  let raw = value
  copyMem(addr data[offset], unsafeAddr raw, 4)

suite "byte round trips":
  test "a model survives the write and read pair":
    ## The byte overloads are the shortest path between two models.
    let model = sampleModel()
    let bytes = writePmx(model)
    check bytes.len > 0
    let reloaded = readPmx(bytes)
    check samePmxContent(model, reloaded)
    check reloaded.directory.len == 0
    check model == reloaded

  test "every element section comes back unchanged":
    ## The fixture fills all ten collections on purpose.
    let reloaded = readPmx(modelBytes(sampleModel()))
    check reloaded.vertices.len == 4
    check reloaded.faces.len == 2
    check reloaded.textures.len == 1
    check reloaded.materials.len == 1
    check reloaded.bones.len == 3
    check reloaded.morphs.len == 5
    check reloaded.displayFrames.len == 2
    check reloaded.rigidBodies.len == 2
    check reloaded.joints.len == 1
    check reloaded.softBodies.len == 1
    check reloaded.bones[2].nameJA == "hand"
    check reloaded.morphs[0].panelType == mptMouth
    check reloaded.softBodies[0].vertexPins == @[0'i32, 3'i32]

  test "UTF-16 text survives the round trip":
    ## The header declares the encoding, and it is honored on the way back.
    let model = sampleModel()
    model.textEncoding = teUTF16LE
    let reloaded = readPmx(writePmx(model))
    check reloaded.textEncoding == teUTF16LE
    check reloaded.commentsJA == model.commentsJA
    check samePmxContent(model, reloaded)

  test "additional UV channels survive the round trip":
    ## All four extra channels share one vertex payload.
    let model = sampleModel()
    model.additionalUvCount = 1'i32
    for vertex in model.vertices:
      vertex.additionalUv = @[Vector4(x: 0.25'f32, y: 0.5'f32, z: 0.0'f32, w: 1.0'f32)]
    check model.isValid()
    let reloaded = readPmx(writePmx(model))
    check samePmxContent(model, reloaded)

  test "an empty buffer is refused":
    ## There is no header to read, so the call fails with a format error.
    let empty: seq[byte] = @[]
    expect PmxFormatError:
      discard readPmx(empty)

suite "stream round trips":
  test "a string stream carries the same bytes":
    ## The stream overload stages output before it touches the destination.
    let model = sampleModel()
    let target = newStringStream()
    writePmx(model, target)
    check target.getPosition() > 0
    target.setPosition(0)
    let reloaded = readPmx(target)
    check samePmxContent(model, reloaded)

  test "a failed write leaves the destination alone":
    ## A rejected model must not leave half a file in the caller's stream.
    let target = newStringStream()
    writePmx(sampleModel(), target)
    let original = StringStream(target).data
    expect ValueError:
      writePmx(damagedModel(), target)
    check StringStream(target).data == original

  test "a shorter StringStream overwrite drops the stale tail":
    ## StringStream keeps whatever followed the write, so a shorter PMX would
    ## re-read with a tail; the writer trims it.
    let target = newStringStream()
    writePmx(sampleModel(), target)
    let longLength = StringStream(target).data.len
    target.setPosition(0)
    let tiny = tinyModel(Vector3.zero)
    let expected = writePmx(tiny)
    check longLength > expected.len
    writePmx(tiny, target)
    check StringStream(target).data.len == expected.len
    target.setPosition(0)
    check readPmx(target).samePmxContent(tiny)

suite "file round trips":
  test "the path overload records the model directory":
    ## Relative texture paths are resolved against that directory.
    let path = tempPmxPath("roundtrip")
    try:
      let model = sampleModel()
      writePmx(model, path)
      check fileExists(path)
      let reloaded = readPmx(path)
      check samePmxContent(model, reloaded)
      check not (model == reloaded)
      check reloaded.directory == normalizedPath(absolutePath(parentDir(path)))
    finally:
      removeFile(path)

  test "an existing file is replaced":
    ## The writer commits a whole new file instead of appending.
    let path = tempPmxPath("replace")
    try:
      writePmx(sampleModel(), path)
      let firstSize = getFileSize(path)
      writePmx(sampleModel(), path)
      check getFileSize(path) == firstSize
      check readPmx(path).isValid()
    finally:
      removeFile(path)

  test "a shorter FileStream overwrite drops the stale tail":
    ## The commit path truncates the destination to the staged length. Old PMX
    ## bytes left behind there would re-read as trailing garbage, which would
    ## later fail the reader, so the truncate has to actually run.
    let path = tempPmxPath("overwrite")
    try:
      writePmx(sampleModel(), path)
      let longSize = getFileSize(path)
      let tiny = tinyModel(Vector3.zero)
      let expected = writePmx(tiny)
      check longSize > int64(expected.len)
      let s = newFileStream(path, fmReadWrite)
      defer: s.close()
      writePmx(tiny, s)
      flush(s)
      check getFileSize(path) == int64(expected.len)
      check readPmx(path).samePmxContent(tiny)
    finally:
      removeFile(path)

  test "a missing file reports an IOError":
    ## Callers can tell a missing path from malformed data.
    expect IOError:
      discard readPmx(tempPmxPath("missing"))
    expect ValueError:
      discard readPmx("")

  test "a file padded after the fact is refused by the path overload":
    ## The path overload caps the stream at the measured size, so bytes appended
    ## between the size check and the read cannot slip into the parser.
    let path = tempPmxPath("padded")
    try:
      writePmx(sampleModel(), path)
      writeFile(path, readFile(path) & "junk")
      expect ValueError:
        discard readPmx(path)
    finally:
      removeFile(path)

suite "write modes":
  test "strict writing refuses a damaged model":
    ## The default mode holds the model to the full contract.
    expect ValueError:
      discard writePmx(damagedModel())

  test "lenient writing keeps defects that still fit the wire":
    ## Dangling references are preserved instead of being dropped.
    let bytes = writePmx(damagedModel(), mode = pwmLenient)
    check bytes.len > 0
    let reloaded = readPmx(bytes)
    check reloaded.materials[0].textureIndex == 9'i32
    check not reloaded.isValid()

  test "repair writing fixes a private copy":
    ## The caller's model is left exactly as it was.
    let model = damagedModel()
    let bytes = writePmx(model, mode = pwmRepair)
    check model.materials[0].textureIndex == 9'i32
    let reloaded = readPmx(bytes)
    check reloaded.isValid()
    check reloaded.materials[0].textureIndex == -1'i32

  test "the version is upgraded when 2.1 data shows up":
    ## A PMX 2.0 model holding QDEF vertices is promoted on the way out.
    let model = newPmxModel(
      nameJA = "qdef",
      version = pmx20,
      vertices = @[newVertex(weightDeform = newQDEF(0'i32, 1'i32, 2'i32, 3'i32))],
      bones = @[
        newBone(nameJA = "b0"),
        newBone(nameJA = "b1"),
        newBone(nameJA = "b2"),
        newBone(nameJA = "b3")
      ]
    )
    check model.version == pmx20
    let reloaded = readPmx(writePmx(model))
    check reloaded.version == pmx21
    check model.version == pmx20

  test "the upgrade can be turned off":
    ## Without it, the writer refuses data the target version cannot hold.
    let model = newPmxModel(
      nameJA = "qdef",
      version = pmx20,
      vertices = @[newVertex(weightDeform = newQDEF(0'i32, 1'i32, 2'i32, 3'i32))],
      bones = @[
        newBone(nameJA = "b0"),
        newBone(nameJA = "b1"),
        newBone(nameJA = "b2"),
        newBone(nameJA = "b3")
      ]
    )
    expect ValueError:
      discard writePmx(model, autoUpgradeVersion = false)

  test "lenient writing also refuses a physics group outside [1, 16]":
    ## Group IDs are physics inputs, not nullable references, so lenient writing
    ## does not keep footguns in that byte either.
    let model = sampleModel()
    model.rigidBodies[1].groupId = 0'i32
    check not model.isValid(strict = false)
    expect ValueError:
      discard writePmx(model, mode = pwmLenient)

suite "IK angle units":
  test "IK limit angles stay degrees across a round trip":
    ## The wire stores radians and the API holds degrees; the writer and the
    ## reader must convert in opposite directions without drift.
    let model = sampleModel()
    model.bones[2].flags.ik = true
    model.bones[2].ik = newBoneIK(
      targetIndex = 1'i32,
      loopCount = 10'i32,
      limitAngle = 2.0'f32,
      links = @[
        newLimitedIKLink(
          1'i32,
          Vector3(x: -0.5'f32, y: -0.5'f32, z: -0.5'f32),
          Vector3(x: 0.5'f32, y: 0.5'f32, z: 0.5'f32)
        )
      ]
    )
    let again = readPmx(writePmx(model))
    check again.bones[2].flags.ik
    check again.bones[2].ik.limitAngle == 2.0'f32
    check again.bones[2].ik.links[0].limitMin ==
      Vector3(x: -0.5'f32, y: -0.5'f32, z: -0.5'f32)
    check again.bones[2].ik.links[0].limitMax ==
      Vector3(x: 0.5'f32, y: 0.5'f32, z: 0.5'f32)

suite "limits":
  test "the published presets are consistent":
    ## readPmx defaults to the conservative preset. Alloc budgets cover the source size
    ## so a file at the source cap is not refused mid-parse for estimated memory.
    check DefaultPmxReadLimits == SafePmxReadLimits
    check SafePmxReadLimits.maxSourceBytes < DesktopPmxReadLimits.maxSourceBytes
    check DesktopPmxReadLimits.maxSourceBytes <
          TrustedLargePmxReadLimits.maxSourceBytes
    check SafePmxReadLimits.maxTotalAllocationBytes >= SafePmxReadLimits.maxSourceBytes
    check DesktopPmxReadLimits.maxTotalAllocationBytes >= DesktopPmxReadLimits.maxSourceBytes
    check TrustedLargePmxReadLimits.maxTotalAllocationBytes >=
          TrustedLargePmxReadLimits.maxSourceBytes
    check UnboundedPmxWriteLimits.maxOutputBytes == high(int64)

  test "the source size limit stops oversized input":
    ## The check happens before any parsing work.
    let bytes = modelBytes(sampleModel())
    var limits = DefaultPmxReadLimits
    limits.maxSourceBytes = 8
    expect PmxLimitError:
      discard readPmx(bytes, limits)

  test "a stream without a length cannot charge counts it never sent":
    ## Streams report an unknown source length, so the serialized minimum has
    ## to bound the allocation charge on its own. An empty model with four empty
    ## strings puts the vertex count at byte 33: 8 header + 8 globals + 1 count
    ## byte + 4 length-prefixed empty strings.
    var data = writePmx(newPmxModel(nameJA = ""))
    writeLe32(data, 33, 250_000)
    var limits = DefaultPmxReadLimits
    limits.maxTotalAllocationBytes = 8_000_000
    try:
      discard readPmx(streamOf(data), limits)
      check false
    except ValueError as exc:
      check exc of PmxLimitError
      check "vertex sequence" in exc.msg

  test "a stream still refuses a count that cannot fit in the source budget":
    ## Unknown length used to skip the remaining-bytes check. The source cap
    ## minus bytes already consumed is now the stand-in for file size.
    var data = writePmx(newPmxModel(nameJA = ""))
    writeLe32(data, 33, 250_000)
    var limits = DefaultPmxReadLimits
    limits.maxSourceBytes = 1_000_000
    limits.maxTotalAllocationBytes = 64 * 1024 * 1024
    try:
      discard readPmx(streamOf(data), limits)
      check false
    except ValueError as exc:
      check exc of PmxTruncatedError
      check "remain in the PMX source" in exc.msg

  test "the string limit stops oversized text":
    ## Services can cap a single field without capping the whole file.
    let bytes = modelBytes(sampleModel())
    var limits = DefaultPmxReadLimits
    limits.maxStringBytes = 2
    expect PmxLimitError:
      discard readPmx(bytes, limits)

  test "invalid limits are configuration errors":
    ## They are reported before the source is touched.
    let bytes = modelBytes(sampleModel())
    var limits = DefaultPmxReadLimits
    limits.maxElementCount = -2
    expect ValueError:
      discard readPmx(bytes, limits)

  test "the output size limit stops oversized writes":
    ## Staging refuses to grow past the budget.
    expect PmxLimitError:
      discard writePmx(sampleModel(), PmxWriteLimits(maxOutputBytes: 16))
    expect ValueError:
      discard writePmx(sampleModel(), PmxWriteLimits(maxOutputBytes: -1))

suite "corpus":
  let corpus = getEnv("PMXFORGE_CORPUS")
  if corpus.len == 0:
    test "corpus files are skipped when PMXFORGE_CORPUS is unset":
      ## Point the variable at a directory of real files to enable this.
      skip()
  else:
    test "every corpus file parses and validates":
      ## Real models are the only way to cover the long tail of the format.
      for entryKind, path in walkDir(corpus):
        if entryKind == pcFile and path.toLowerAscii.endsWith(".pmx"):
          let model = readPmx(path, DesktopPmxReadLimits)
          validate(model)
          check samePmxContent(model, readPmx(writePmx(model)))
