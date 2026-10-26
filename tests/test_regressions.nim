## Regression tests for previously reported defects.
##
## Covers the stream overwrite that used to empty a file (F01), joint limits that are not
## minimum/maximum pairs (F02), legal flip self-references (F03), sub-texture sphere blending in PMX
## 2.0 (F04), float32 overflow on JavaScript (F05), streams that return short reads (F07), long
## diagnostic names (F10), the documented limits of `repair` (F12), and the face-repair wire
## contract (R13).

import std/[os, streams, strutils, unittest]
import pmxforge
import ./support

proc tempPmxPath(name: string): string =
  ## Returns a unique destination under the system temporary directory.
  result = getTempDir() / ("pmxforge-regression-" & name & "-" & $getCurrentProcessId() & ".pmx")

var savedWriteData {.threadvar.}: proc (
  s: Stream,
  buffer: pointer,
  bufferLength: int
) {.nimcall, gcsafe, raises: [IOError, OSError], tags: [WriteIOEffect].}

proc failingWriteData(
  s: Stream,
  buffer: pointer,
  bufferLength: int
) {.nimcall, raises: [IOError, OSError].} =
  ## Refuses every write, standing in for a full disk or a closed handle.
  raise newException(IOError, "injected write failure")

proc partialThenFail(
  s: Stream,
  buffer: pointer,
  bufferLength: int
) {.nimcall, gcsafe, raises: [IOError, OSError], tags: [WriteIOEffect].} =
  ## Writes one byte through the real file stream and then reports a failure.
  {.cast(gcsafe).}:
    savedWriteData(s, buffer, 1)
  raise newException(IOError, "injected partial write failure")

type
  ChunkStream = ref object of StreamObj ## Stream that returns at most `chunkSize` bytes per read.
    data: seq[byte]
    position: int
    chunkSize: int

proc chunkReadData(s: Stream, buffer: pointer, bufferLength: int): int {.nimcall, raises: [], gcsafe.} =
  ## Copies one chunk, never more than requested.
  let source = ChunkStream(s)
  if bufferLength <= 0 or source.position >= source.data.len:
    return 0
  result = min(min(bufferLength, source.chunkSize), source.data.len - source.position)
  copyMem(buffer, unsafeAddr source.data[source.position], result)
  source.position += result

proc chunkAtEnd(s: Stream): bool {.nimcall, raises: [], gcsafe.} =
  ## Reports the logical end of the chunked source.
  let source = ChunkStream(s)
  source.position >= source.data.len

proc chunkGetPosition(s: Stream): int {.nimcall, raises: [], gcsafe.} =
  ## Reports how many bytes the chunked source has handed out.
  ChunkStream(s).position

proc chunkedStream(data: seq[byte], chunkSize: int): Stream =
  ## Wraps bytes in a stream that answers every read with at most `chunkSize` bytes.
  let source = ChunkStream(data: data, chunkSize: chunkSize)
  source.readDataImpl = chunkReadData
  source.atEndImpl = chunkAtEnd
  source.getPositionImpl = chunkGetPosition
  result = source

proc partialFailureResult(path, original: string): tuple[failed: bool, content: string] =
  ## Overwrites `path` with a one-byte partial write followed by a failure, then reports the file content.
  writeFile(path, original)
  let target = newFileStream(path, fmReadWriteExisting)
  savedWriteData = target.writeDataImpl
  target.writeDataImpl = partialThenFail
  try:
    writePmx(sampleModel(), target)
  except IOError:
    result.failed = true
  target.writeDataImpl = savedWriteData
  target.flush()
  target.close()
  result.content = readFile(path)

suite "F01 file stream overwrite":
  test "a failed write leaves the existing file's bytes and length intact":
    ## The old rollback truncated a FileStream to zero at position 0, so a refused write destroyed the
    ## original file. A stream write is not atomic, but it must not discard what it has not replaced.
    let path = tempPmxPath("failed-write")
    let original = "existing PMX bytes that must survive 0123456789"
    try:
      writeFile(path, original)
      let target = newFileStream(path, fmReadWriteExisting)
      defer: target.close()
      target.writeDataImpl = failingWriteData
      expect IOError:
        writePmx(sampleModel(), target)
      check getFileSize(path) == int64(original.len)
      check readFile(path) == original
    finally:
      removeFile(path)

  test "a partial write is rolled back from the snapshot":
    ## The payload is longer than the original, so recovery has to rewrite the prefix and truncate.
    let path = tempPmxPath("partial-short")
    let original = repeat('a', 128)
    try:
      let outcome = partialFailureResult(path, original)
      check outcome.failed
      check getFileSize(path) == int64(original.len)
      check outcome.content == original
    finally:
      removeFile(path)

  test "a partial write restores the prefix and leaves a longer original tail intact":
    ## The original is longer than the payload, so only the overwritten prefix is captured.
    let path = tempPmxPath("partial-long")
    let original = repeat('b', 5000)
    try:
      let outcome = partialFailureResult(path, original)
      check outcome.failed
      check getFileSize(path) == int64(original.len)
      check outcome.content == original
    finally:
      removeFile(path)

  test "a successful shorter overwrite still trims the stale tail":
    ## Truncation moved after the write, so the commit path keeps working.
    let path = tempPmxPath("short-overwrite")
    try:
      writePmx(sampleModel(), path)
      let longSize = getFileSize(path)
      let tiny = tinyModel(Vector3.zero)
      let expected = writePmx(tiny)
      check longSize > int64(expected.len)
      let target = newFileStream(path, fmReadWriteExisting)
      defer: target.close()
      writePmx(tiny, target)
      flush(target)
      check getFileSize(path) == int64(expected.len)
      check readPmx(path).samePmxContent(tiny)
    finally:
      removeFile(path)

suite "F02 joint limit semantics":
  test "ConeTwist spans are values, not an ordered minimum/maximum pair":
    ## rotationMinimum holds twistSpan/swingSpan2/swingSpan1 and rotationMaximum is unused, so
    ## (0.5, 0.5, 0.5) against zero is a valid joint.
    let joint = newJoint(
      nameJA = "cone",
      jointType = jtConeTwist,
      rigidBodyIndexA = 0'i32,
      rigidBodyIndexB = 1'i32,
      rotationMinimum = Vector3(x: 0.5'f32, y: 0.5'f32, z: 0.5'f32),
      rotationMaximum = Vector3.zero
    )
    check joint.isValid()
    let model = sampleModel()
    model.joints = @[joint]
    validate(model)
    let reloaded = readPmx(writePmx(model))
    check reloaded.joints[0].rotationMinimum == joint.rotationMinimum
    check reloaded.joints[0].rotationMaximum == joint.rotationMaximum

  test "repair does not zero repurposed ConeTwist components":
    let model = sampleModel()
    model.joints = @[
      newJoint(
        nameJA = "cone",
        jointType = jtConeTwist,
        rigidBodyIndexA = 0'i32,
        rigidBodyIndexB = 1'i32,
        rotationMinimum = Vector3(x: 0.5'f32, y: 0.25'f32, z: 0.75'f32),
        rotationMaximum = Vector3.zero
      )
    ]
    model.repair()
    check model.joints[0].rotationMinimum == Vector3(x: 0.5'f32, y: 0.25'f32, z: 0.75'f32)

  test "six-DOF limits still have to be ordered":
    ## The per-type rule must not weaken the types that really do store lower/upper bounds.
    let joint = newJoint(nameJA = "six", jointType = jt6DOF)
    joint.positionMinimum = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32)
    joint.positionMaximum = Vector3.zero
    check not joint.isValid()
    let model = sampleModel()
    model.joints = @[joint]
    expect ValueError:
      validate(model)

  test "Slider and Hinge only order the axes they use":
    let slider = newJoint(
      nameJA = "slider",
      jointType = jtSlider,
      rigidBodyIndexA = 0'i32,
      rigidBodyIndexB = 1'i32,
      positionMinimum = Vector3(x: 0.0'f32, y: 9.0'f32, z: 9.0'f32),
      positionMaximum = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      rotationMinimum = Vector3(x: 0.0'f32, y: 9.0'f32, z: 9.0'f32),
      rotationMaximum = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32)
    )
    check slider.isValid()
    let hinge = newJoint(
      nameJA = "hinge",
      jointType = jtHinge,
      rigidBodyIndexA = 0'i32,
      rigidBodyIndexB = 1'i32,
      rotationMinimum = Vector3(x: 0.0'f32, y: 9.0'f32, z: 9.0'f32),
      rotationMaximum = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32)
    )
    check hinge.isValid()
    let pointToPoint = newJoint(
      nameJA = "p2p",
      jointType = jtPointToPoint,
      rigidBodyIndexA = 0'i32,
      rigidBodyIndexB = 1'i32,
      positionMinimum = Vector3(x: 9.0'f32, y: 9.0'f32, z: 9.0'f32),
      positionMaximum = Vector3.zero,
      rotationMinimum = Vector3(x: 9.0'f32, y: 9.0'f32, z: 9.0'f32),
      rotationMaximum = Vector3.zero
    )
    check pointToPoint.isValid()

suite "F03 flip morph references":
  test "a flip morph may reference itself and survives a round trip":
    ## The specification allows self-registration and evaluates flip targets in stages.
    let model = sampleModel()
    let flipIndex = int32(model.morphs.len)
    model.morphs.add newMorph(
      nameJA = "flip",
      morphType = mtFlip,
      offsetData = @[
        MorphOffset(
          kind: moFlip,
          flip: FlipMorphOffset(morphIndex: flipIndex, influence: 0.5'f32)
        )
      ]
    )
    validate(model)
    let reloaded = readPmx(writePmx(model))
    check reloaded.morphs[flipIndex].offsetData.len == 1
    check reloaded.morphs[flipIndex].offsetData[0].flip.morphIndex == flipIndex

  test "repair keeps a valid flip self-reference":
    let model = sampleModel()
    let flipIndex = int32(model.morphs.len)
    model.morphs.add newMorph(
      nameJA = "flip",
      morphType = mtFlip,
      offsetData = @[
        MorphOffset(
          kind: moFlip,
          flip: FlipMorphOffset(morphIndex: flipIndex, influence: 0.5'f32)
        )
      ]
    )
    model.repair()
    check model.morphs[flipIndex].offsetData.len == 1
    check model.isValid()

  test "two flips may reference each other":
    let model = sampleModel()
    let firstIndex = int32(model.morphs.len)
    let secondIndex = firstIndex + 1
    model.morphs.add newMorph(
      nameJA = "flip a",
      morphType = mtFlip,
      offsetData = @[
        MorphOffset(kind: moFlip, flip: FlipMorphOffset(morphIndex: secondIndex, influence: 0.5'f32))
      ]
    )
    model.morphs.add newMorph(
      nameJA = "flip b",
      morphType = mtFlip,
      offsetData = @[
        MorphOffset(kind: moFlip, flip: FlipMorphOffset(morphIndex: firstIndex, influence: 0.5'f32))
      ]
    )
    validate(model)
    model.repair()
    check model.morphs[firstIndex].offsetData.len == 1
    check model.morphs[secondIndex].offsetData.len == 1

  test "a group morph still cannot reference itself":
    let model = sampleModel()
    let groupIndex = int32(model.morphs.len)
    model.morphs.add newMorph(
      nameJA = "group",
      morphType = mtGroup,
      offsetData = @[
        MorphOffset(kind: moGroup, group: GroupMorphOffset(morphIndex: groupIndex, influence: 1.0'f32))
      ]
    )
    expect ValueError:
      validate(model)

suite "F04 sub-texture sphere blending":
  test "a PMX 2.0 model may use sbmSubTexture and stays 2.0":
    let model = sampleModel()
    model.version = pmx20
    model.softBodies = @[]
    model.additionalUvCount = 1'i32
    for vertex in model.vertices:
      vertex.additionalUv = @[Vector4(x: 0.25'f32, y: 0.5'f32, z: 0.0'f32, w: 1.0'f32)]
    for material in model.materials:
      material.sphereBlendMode = sbmSubTexture
    check not model.isPmx21Only
    validate(model)
    let reloaded = readPmx(writePmx(model))
    check reloaded.version == pmx20
    check reloaded.materials[0].sphereBlendMode == sbmSubTexture
    check reloaded.isValid()

  test "sub-texture blending still requires an additional UV channel":
    let model = sampleModel()
    model.materials[0].sphereBlendMode = sbmSubTexture
    expect ValueError:
      validate(model)

suite "F05 float32 representability":
  test "a product that overflows float32 is not considered writable":
    ## On JavaScript the product stays a finite double until DataView.setFloat32 encodes it; the check
    ## has to round first so validate and the writer agree with the native backend.
    let model = sampleModel()
    var left = 1.0e30'f32
    var right = 1.0e30'f32
    model.vertices[0].position.x = left * right
    check not model.isValid()
    check not isValid(model, strict = false)
    expect ValueError:
      discard writePmx(model)

  test "a finite float32 value is still accepted":
    let model = sampleModel()
    model.vertices[0].position.x = 3.0e38'f32
    check model.isValid()
    check readPmx(writePmx(model)).vertices[0].position.x == 3.0e38'f32
    model.vertices[0].position.x = Inf
    check not model.isValid()
    expect ValueError:
      discard writePmx(model)

suite "F07 short stream reads":
  test "a stream that returns one to seven bytes per read still parses":
    ## readStr(4) used to treat a short read as end of file; the buffered reader accumulates chunks.
    let bytes = writePmx(sampleModel())
    for chunkSize in [1, 2, 3, 7]:
      let reloaded = readPmx(chunkedStream(bytes, chunkSize))
      check samePmxContent(sampleModel(), reloaded)

  test "a chunked stream reports true truncation":
    var bytes = writePmx(sampleModel())
    bytes.setLen(bytes.len - 3)
    expect PmxTruncatedError:
      discard readPmx(chunkedStream(bytes, 1))

suite "F10 diagnostic context":
  test "a long morph name is not copied into every offset label":
    ## Labels are built per offset; a 60 KiB name would otherwise multiply text work by the offset
    ## count. The capped context still identifies the element, and errors keep working.
    let model = tinyModel(Vector3.zero)
    let longName = repeat('x', 60_000)
    var offsets = newSeq[MorphOffset](20_000)
    for i in 0 ..< offsets.len:
      offsets[i] = MorphOffset(kind: moGroup, group: GroupMorphOffset(morphIndex: -1'i32))
    model.morphs = @[newMorph(nameJA = longName, morphType = mtGroup, offsetData = offsets)]
    validate(model)
    model.morphs[0].offsetData[0].group.morphIndex = 9'i32
    var message = ""
    try:
      validate(model)
    except ValueError as exc:
      message = exc.msg
    check "Morph[0]" in message
    check longName notin message

suite "F12 repair contract":
  test "repair is best effort for version-gated data":
    ## `repair` keeps the declared 2.0 version, so QDEF data still fails strict validation; only the
    ## writer's auto-upgrade promotes the file. This is documented, not silently fixed.
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
    model.repair()
    check model.version == pmx20
    check not model.isValid()
    check readPmx(writePmx(model)).version == pmx21

  test "repairWithReport is empty when the pass makes the model valid":
    ## The report is the strict contract applied after the repair, not a list of values that changed.
    let model = damagedModel()
    let issues = repairWithReport(model)
    check issues.len == 0
    check model.isValid()

  test "repairWithReport names version-gated data it cannot remove":
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
    let issues = repairWithReport(model)
    check issues.len == 2
    check "QDEF" in issues[0]
    check "autoUpgradeVersion" in issues[1]
    check model.version == pmx20

  test "repairWithReport names text it does not rewrite":
    ## Repair has no text policy; the remaining strict failure names the field.
    let model = newPmxModel(nameJA = "\xFF", version = pmx21, textEncoding = teUTF8)
    let issues = repairWithReport(model)
    check issues.len == 1
    check "nameJA" in issues[0]

  test "repairWithReport rejects a nil model and invalid limits":
    let empty: PmxModel = nil
    expect ValueError:
      discard repairWithReport(empty)
    expect ValueError:
      discard repairWithReport(sampleModel(), -1)

suite "R01 checked stdio flush":
  when defined(posix):
    test "a failing flush raises instead of being ignored":
      ## `/dev/full` accepts buffered writes and fails when the buffer is flushed. The
      ## stream writer used to ignore that failure because `flushFile` discards `fflush`.
      if fileExists("/dev/full"):
        let target = newFileStream("/dev/full", fmWrite)
        check target != nil
        if target != nil:
          var message = ""
          try:
            writePmx(sampleModel(), target)
          except IOError as exc:
            message = exc.msg
          finally:
            target.close()
          check "flush" in message

suite "R02 material morph repair":
  test "an out-of-range material target is dropped, not widened to all materials":
    let model = newPmxModel(
      materials = @[newMaterial()],
      morphs = @[
        newMorph(
          nameJA = "wide",
          morphType = mtMaterial,
          offsetData = @[
            MorphOffset(
              kind: moMaterial,
              material: MaterialMorphOffset(
                materialIndex: 99'i32,
                blendMode: mmbAdd,
                diffuseColor: RGBA(r: 1.0'f32)
              )
            )
          ]
        )
      ]
    )
    check not model.isValid()
    let repaired = readPmx(writePmx(model, mode = pwmRepair))
    check repaired.isValid()
    check repaired.morphs[0].offsetData.len == 0

  test "an explicit -1 keeps meaning every material":
    ## The wildcard is legal when the file asks for it; repair must not remove it.
    let model = newPmxModel(
      materials = @[newMaterial()],
      morphs = @[
        newMorph(
          nameJA = "all",
          morphType = mtMaterial,
          offsetData = @[
            MorphOffset(
              kind: moMaterial,
              material: MaterialMorphOffset(materialIndex: -1'i32, blendMode: mmbAdd)
            )
          ]
        )
      ]
    )
    check model.isValid()
    let repaired = readPmx(writePmx(model, mode = pwmRepair))
    check repaired.isValid()
    check repaired.morphs[0].offsetData.len == 1
    check repaired.morphs[0].offsetData[0].material.materialIndex == -1'i32

suite "R03 scalar division":
  test "a subnormal divisor does not overflow through a reciprocal":
    ## `x / x` is exactly one; computing `1 / x` first would overflow and multiply by
    ## infinity instead.
    let tiny = 1.0e-40'f32
    check Vector2(x: tiny, y: tiny) / tiny == Vector2(x: 1.0'f32, y: 1.0'f32)
    check Vector3(x: tiny, y: tiny, z: tiny) / tiny == Vector3(x: 1.0'f32, y: 1.0'f32, z: 1.0'f32)
    check Vector4(x: tiny, y: tiny, z: tiny, w: tiny) / tiny ==
      Vector4(x: 1.0'f32, y: 1.0'f32, z: 1.0'f32, w: 1.0'f32)
    check Quaternion(x: tiny, y: tiny, z: tiny, w: tiny) / tiny ==
      Quaternion(x: 1.0'f32, y: 1.0'f32, z: 1.0'f32, w: 1.0'f32)
    check RGB(r: tiny, g: tiny, b: tiny) / tiny == RGB(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32)
    check RGBA(r: tiny, g: tiny, b: tiny, a: tiny) / tiny ==
      RGBA(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32, a: 1.0'f32)

  test "compound division follows the same rule":
    let tiny = 1.0e-40'f32
    var vector = Vector3(x: tiny, y: tiny, z: tiny)
    vector /= tiny
    check vector == Vector3(x: 1.0'f32, y: 1.0'f32, z: 1.0'f32)
    var colour = RGBA(r: tiny, g: tiny, b: tiny, a: tiny)
    colour /= tiny
    check colour == RGBA(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32, a: 1.0'f32)

suite "R04 axis-angle boundary":
  test "an axis at the normalization threshold yields identity, not a non-unit quaternion":
    ## `normalize` returns vectors at or below `Epsilon` unchanged; the angle
    ## constructor has to use the same boundary.
    let q = fromAxisAngle(Vector3(x: Epsilon, y: 0.0'f32, z: 0.0'f32), 1.0'f32)
    check q == Quaternion.identity

  test "an axis just above the threshold produces a unit quaternion":
    let q = fromAxisAngle(Vector3(x: Epsilon * 2.0'f32, y: 0.0'f32, z: 0.0'f32), 1.0'f32)
    check abs(q.length - 1.0'f32) < 1.0e-5'f32

  test "a degenerate look direction yields identity":
    let q = lookRotation(Vector3(x: Epsilon, y: 0.0'f32, z: 0.0'f32))
    check q == Quaternion.identity

suite "R13 face repair stays encodable":
  test "isolated face.repair does not block pwmLenient":
    ## A corner past the vertex list used to become -1, which writeVertexIndex rejects.
    let model = sampleModel()
    model.faces[0].vertexIndex3 = 9'i32
    model.faces[0].repair(vertexCount = int32(model.vertices.len))
    check model.faces[0].vertexIndex3 == 9'i32
    let bytes = writePmx(model, mode = pwmLenient)
    check bytes.len > 0

  test "model.repair still drops faces that cannot be encoded strictly":
    let model = sampleModel()
    model.faces[0].vertexIndex3 = 9'i32
    model.repair()
    check model.isValid()
    check model.faces.len == 1
    check model.materials[0].faceCount == 1'i32
    discard writePmx(model)
