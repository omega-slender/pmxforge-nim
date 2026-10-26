## Binary PMX parser.
##
## Provides `readPmx` and `PmxReadLimits` to load PMX 2.0 and 2.1 models from a path,
## a stream, or a byte buffer. A face count that is not a multiple of three is rounded
## down instead of refused.

import streams
import math
import strformat

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  import os

import ../model
import ../errors
import ../limits
import ../internal/preconditions
import ./binary

const
  ValidIndexSizes = [1'i32, 2'i32, 4'i32] ## Allowed PMX index widths in bytes.
  GcObjectHeaderBytes = 16'i64 ## Conservative Nim GC object header size in bytes.

type
  PmxReadLimits* = object ## Resource limits for parsing untrusted PMX files.
    maxSourceBytes*: int64 ## Maximum input size in bytes.
    maxStringBytes*: int32 ## Maximum byte length for a single string.
    maxElementCount*: int32 ## Maximum entries per collection.
    maxTotalAllocationBytes*: int64 ## Total estimated memory limit during parsing.
    acceptNonFiniteFloats*: bool ## If true, accepts NaN and Inf instead of failing.

const
  SafePmxReadLimits* = PmxReadLimits(
    maxSourceBytes: 64 * 1024 * 1024,
    maxStringBytes: MaxStringBytes,
    maxElementCount: 250_000,
    maxTotalAllocationBytes: 64 * 1024 * 1024,
    acceptNonFiniteFloats: false
  ) ## Conservative limits for untrusted files and web services (64 MB).

  DesktopPmxReadLimits* = PmxReadLimits(
    maxSourceBytes: 256 * 1024 * 1024,
    maxStringBytes: MaxStringBytes,
    maxElementCount: 1_000_000,
    maxTotalAllocationBytes: 256 * 1024 * 1024,
    acceptNonFiniteFloats: false
  ) ## Standard limits for desktop applications (256 MB).

  TrustedLargePmxReadLimits* = PmxReadLimits(
    maxSourceBytes: 1024 * 1024 * 1024,
    maxStringBytes: MaxStringBytes,
    maxElementCount: MaxElementCount,
    maxTotalAllocationBytes: 1024 * 1024 * 1024,
    acceptNonFiniteFloats: false
  ) ## High limits for trusted large models (1 GB).

  DefaultPmxReadLimits* = SafePmxReadLimits ## Default limits used by readPmx.

type
  Reader = object ## Internal parsing state for one PMX model.
    reader: BinaryReader ## Buffered stream reader.
    sourceLength: int64 ## Expected total byte length (-1 if unknown).
    textEncoding: TextEncoding ## Text encoding declared in header.
    additionalUvCount: int32 ## Number of extra UV channels (0-4).
    vertexIndexSize: int32 ## Byte width of vertex indices (1, 2, or 4).
    textureIndexSize: int32 ## Byte width of texture indices (1, 2, or 4).
    materialIndexSize: int32 ## Byte width of material indices (1, 2, or 4).
    boneIndexSize: int32 ## Byte width of bone indices (1, 2, or 4).
    morphIndexSize: int32 ## Byte width of morph indices (1, 2, or 4).
    rigidBodyIndexSize: int32 ## Byte width of rigid body indices (1, 2, or 4).
    limits: PmxReadLimits ## Active resource limits.
    allocatedBytes: int64 ## Running total of estimated allocated memory.

  SourceLimitedStream = ref object of StreamObj ## Enforces maximum source bytes on a stream.
    parent: Stream ## Wrapped source stream.
    remaining: int64 ## Remaining bytes allowed to read.

  PmxSourceLimitIoError = object of IOError ## Internal error when source byte limit is hit.
  PmxTruncatedIoError = object of ValueError ## Internal error on unexpected end of stream.

when not defined(js):
  type
    ByteReadStream = ref object of StreamObj ## Zero-copy read stream over a byte buffer.
      data: seq[byte] ## Source byte buffer.
      position: int ## Current read offset.

  proc byteReadData(s: Stream, buffer: pointer, bufferLength: int): int {.nimcall, raises: [], gcsafe.} =
    ## Reads bytes directly from the backing buffer into memory.
    let source = ByteReadStream(s)
    if bufferLength <= 0 or source.position >= source.data.len:
      return 0
    result = min(bufferLength, source.data.len - source.position)
    copyMem(buffer, unsafeAddr source.data[source.position], result)
    source.position += result

  proc byteAtEnd(s: Stream): bool {.nimcall, raises: [], gcsafe.} =
    ## Returns true if the byte buffer has been fully read.
    let source = ByteReadStream(s)
    source.position >= source.data.len

  proc byteGetPosition(s: Stream): int {.nimcall, raises: [], gcsafe.} =
    ## Returns the current read offset in the byte buffer.
    ByteReadStream(s).position

  proc newByteReadStream(data: seq[byte]): ByteReadStream =
    ## Creates a zero-copy read stream over a byte buffer.
    new(result)
    result.data = data
    result.readDataImpl = byteReadData
    result.atEndImpl = byteAtEnd
    result.getPositionImpl = byteGetPosition

when defined(js):
  proc bytesToString(data: openArray[byte]): string =
    ## Converts a byte sequence to a string for JS streams.
    result = newString(data.len)
    for i, value in data:
      result[i] = char(value)

proc validateLimits(limits: PmxReadLimits) {.raises: [ValueError].} =
  ## Validates that read limits are within format bounds.
  if limits.maxSourceBytes < 0:
    raise newException(ValueError, "maxSourceBytes must be non-negative.")
  if limits.maxStringBytes < 0 or int64(limits.maxStringBytes) > int64(MaxPmxStringBytes):
    raise newException(
      ValueError, fmt"maxStringBytes must be in [0, {MaxPmxStringBytes}], got {limits.maxStringBytes}.")
  if limits.maxElementCount < 0 or limits.maxElementCount > MaxElementCount:
    raise newException(
      ValueError, fmt"maxElementCount must be in [0, {MaxElementCount}], got {limits.maxElementCount}.")
  if limits.maxTotalAllocationBytes < 0:
    raise newException(ValueError, "maxTotalAllocationBytes must be non-negative.")

proc validateSourceLength(limits: PmxReadLimits, sourceLength: int64) {.raises: [PmxLimitError].} =
  ## Ensures the source length does not exceed `maxSourceBytes`.
  if sourceLength >= 0 and sourceLength > limits.maxSourceBytes:
    raise newException(
      PmxLimitError,
      fmt"PMX source size {sourceLength} bytes exceeds the limit of {limits.maxSourceBytes} bytes.")

proc limitedReadData(
  s: Stream,
  buffer: pointer,
  bufferLength: int
): int {.nimcall, raises: [IOError, OSError], gcsafe.} =
  ## Reads up to `bufferLength` bytes while enforcing the remaining source budget.
  let limited = SourceLimitedStream(s)
  if bufferLength < 0:
    raise newException(IOError, "Negative source-limited read length.")
  if bufferLength == 0:
    return 0
  if limited.remaining == 0:
    if not limited.parent.atEnd():
      raise newException(PmxSourceLimitIoError, "PMX stream exceeds the configured source-size limit.")
    return 0
  let allowed = int(min(int64(bufferLength), limited.remaining))
  let read = limited.parent.readData(buffer, allowed)
  if read < 0 or read > allowed:
    raise newException(IOError, "Underlying stream returned an invalid read length.")
  result = read
  limited.remaining -= int64(read)

proc limitedAtEnd(s: Stream): bool {.nimcall, raises: [IOError, OSError], gcsafe.} =
  ## Returns true if the wrapped source stream is at its end.
  let limited = SourceLimitedStream(s)
  result = limited.parent.atEnd()
  if not result and limited.remaining == 0:
    raise newException(PmxSourceLimitIoError, "PMX stream grew beyond the configured source-size limit.")

proc limitedGetPosition(s: Stream): int {.nimcall, raises: [IOError, OSError], gcsafe.} =
  ## Returns the logical position of the wrapped stream when it can report one.
  let limited = SourceLimitedStream(s)
  if limited.parent.getPositionImpl == nil:
    raise newException(IOError, "The source stream does not report a position.")
  SourceLimitedStream(s).parent.getPosition()

proc newSourceLimitedStream(stream: Stream, maxBytes: int64): SourceLimitedStream {.raises: [ValueError].} =
  ## Wraps a stream so it cannot read past `maxBytes` bytes.
  if stream == nil:
    raise newException(ValueError, "Stream is nil.")
  new(result)
  result.parent = stream
  result.remaining = maxBytes
  result.readDataImpl = limitedReadData
  result.atEndImpl = limitedAtEnd
  result.getPositionImpl = limitedGetPosition

proc newReader(
  binaryReader: BinaryReader,
  textEnc: TextEncoding,
  additionalUv: int32,
  vertexIdxSize: int32,
  textureIdxSize: int32,
  materialIdxSize: int32,
  boneIdxSize: int32,
  morphIdxSize: int32,
  rigidBodyIdxSize: int32,
  limits: PmxReadLimits,
  sourceLength: int64
): Reader =
  ## Creates a `Reader` that keeps the bytes already read with the header.
  result.reader = binaryReader
  result.sourceLength = sourceLength
  result.textEncoding = textEnc
  result.additionalUvCount = additionalUv
  result.vertexIndexSize = vertexIdxSize
  result.textureIndexSize = textureIdxSize
  result.materialIndexSize = materialIdxSize
  result.boneIndexSize = boneIdxSize
  result.morphIndexSize = morphIdxSize
  result.rigidBodyIndexSize = rigidBodyIdxSize
  result.limits = limits

proc toEnum[E: enum](val: int32, fieldName: string): E {.raises: [ValueError].} =
  ## Converts an ordinal to `E`, reporting the field name when it is invalid.
  for candidate in E:
    if int32(candidate) == val:
      return candidate
  raise newException(ValueError, fmt"Invalid {fieldName} value {val}.")

proc chargeAllocation(r: var Reader, bytes: int64, name: string) {.raises: [ValueError].}

proc ensureTransientBudget(r: Reader, bytes: int64, name: string) {.raises: [ValueError].} =
  ## Checks a temporary allocation against the budget, then releases it.
  if bytes < 0 or bytes > r.limits.maxTotalAllocationBytes - r.allocatedBytes:
    raise newException(
      PmxLimitError,
      fmt"{name} temporary allocation of {bytes} bytes exceeds the remaining parser budget of " &
        $((r.limits.maxTotalAllocationBytes - r.allocatedBytes)) & " bytes.")

proc readString(r: var Reader): string {.raises: [IOError, OSError, ValueError].} =
  ## Reads a length-prefixed string using the model's declared encoding.
  let byteLength = r.reader.readStringLength(r.limits.maxStringBytes)
  let temporaryBytes =
    case r.textEncoding
    of teUTF8:
      int64(byteLength) + int64(sizeof(string))
    of teUTF16LE:
      let maxDecodedBytes = int64(byteLength) * 2'i64
      int64(byteLength) + 2'i64 * maxDecodedBytes + int64(sizeof(string))
  r.ensureTransientBudget(temporaryBytes, "string decoding")
  result = r.reader.readStringPayload(byteLength, int32(r.textEncoding), r.limits.maxStringBytes)
  when defined(js):
    let retainedBytes = result.len
  else:
    let retainedBytes = result.capacity
  r.chargeAllocation(int64(retainedBytes) + int64(sizeof(string)), "string")

proc readBool(r: var Reader, fieldName: string): bool {.raises: [IOError, OSError, ValueError].} =
  ## Reads a PMX boolean byte; only `0` and `1` are valid.
  let value = r.reader.readInt(1)
  case value
  of 0:
    false
  of 1:
    true
  else:
    raise newException(ValueError, fmt"Invalid {fieldName} boolean value {value}.")

proc readVector2(r: var Reader): Vector2 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a `Vector2` as two consecutive `float32` values.
  Vector2(x: r.reader.readFloat32(), y: r.reader.readFloat32())

proc readVector3(r: var Reader): Vector3 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a `Vector3` as three consecutive `float32` values.
  Vector3(x: r.reader.readFloat32(), y: r.reader.readFloat32(), z: r.reader.readFloat32())

proc readVector4(r: var Reader): Vector4 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a `Vector4` as four consecutive `float32` values.
  Vector4(
    x: r.reader.readFloat32(),
    y: r.reader.readFloat32(),
    z: r.reader.readFloat32(),
    w: r.reader.readFloat32()
  )

proc readQuaternion(r: var Reader): Quaternion {.raises: [IOError, OSError, ValueError].} =
  ## Reads a quaternion as four consecutive `float32` values.
  Quaternion(
    x: r.reader.readFloat32(),
    y: r.reader.readFloat32(),
    z: r.reader.readFloat32(),
    w: r.reader.readFloat32()
  )

proc radiansToDegrees(
  value: float32,
  label: string,
  acceptNonFinite: bool
): float32 {.raises: [ValueError].} =
  ## Converts radians to degrees, rejecting a result a `float32` cannot represent, so every
  ## backend refuses the same bytes.
  result = radToDeg(value)
  if not acceptNonFinite and not isFiniteFloat32(result):
    raise newException(PmxFormatError, fmt"{label} overflows the degree representation.")

proc readRGB(r: var Reader): RGB {.raises: [IOError, OSError, ValueError].} =
  ## Reads an RGB color as three consecutive `float32` values.
  RGB(r: r.reader.readFloat32(), g: r.reader.readFloat32(), b: r.reader.readFloat32())

proc readRGBA(r: var Reader): RGBA {.raises: [IOError, OSError, ValueError].} =
  ## Reads an RGBA color as four consecutive `float32` values.
  RGBA(
    r: r.reader.readFloat32(),
    g: r.reader.readFloat32(),
    b: r.reader.readFloat32(),
    a: r.reader.readFloat32()
  )

proc readVertexIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads an unsigned vertex index; this field has no null sentinel.
  r.reader.readVertexIndex(r.vertexIndexSize)

proc readTextureIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed texture reference; all bits set means `-1` (none).
  r.reader.readIndex(r.textureIndexSize)

proc readMaterialIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed material reference; all bits set means `-1` (none).
  r.reader.readIndex(r.materialIndexSize)

proc readBoneIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed bone reference; all bits set means `-1` (none).
  r.reader.readIndex(r.boneIndexSize)

proc readMorphIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed morph reference; all bits set means `-1` (none).
  r.reader.readIndex(r.morphIndexSize)

proc readRigidBodyIndex(r: var Reader): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed rigid-body reference; all bits set means `-1` (none).
  r.reader.readIndex(r.rigidBodyIndexSize)

proc validateCount(r: var Reader, count: int32, name: string) {.raises: [ValueError].} =
  ## Checks `count` before allocating a collection.
  if count < 0:
    raise newException(ValueError, fmt"{name} count is negative ({count}).")
  if count > r.limits.maxElementCount:
    raise newException(
      PmxLimitError, fmt"{name} count {count} exceeds the limit of {r.limits.maxElementCount}.")

proc remainingSourceBytes(r: Reader): int64 {.raises: [IOError, OSError].} =
  ## Bytes still allowed in this parse: the measured file/buffer length, or the
  ## source budget minus what the buffered reader has already consumed.
  let consumed = r.reader.logicalPosition()
  if r.sourceLength >= 0:
    r.sourceLength - consumed
  else:
    r.limits.maxSourceBytes - consumed

proc ensureMinimumSerializedBytes(
  r: Reader,
  count,
  bytesPerItem: int32,
  name: string
) {.raises: [IOError, OSError, ValueError].} =
  ## Rejects truncated inputs before allocating collection memory.
  if count == 0:
    return
  let remaining = r.remainingSourceBytes()
  let required = int64(count) * int64(bytesPerItem)
  if remaining < required:
    raise newException(
      PmxTruncatedIoError,
      fmt"{name} count {count} requires at least {required} bytes, but only " & $(max(remaining, 0'i64)) &
        " remain in the PMX source.")

proc allocateSeq[T](
  r: var Reader,
  count: int32,
  name: string,
  minimumSerializedBytes = 1'i32
): seq[T] {.raises: [IOError, OSError, ValueError].} =
  ## Accounts for the sequence storage against the memory budget before allocating it.
  r.validateCount(count, name)
  r.ensureMinimumSerializedBytes(count, minimumSerializedBytes, name)
  let sequenceBytes = int64(count) * int64(sizeof(T))
  let serializedBytes = int64(count) * int64(minimumSerializedBytes)
  r.chargeAllocation(max(sequenceBytes, serializedBytes), fmt"{name} sequence")
  result = newSeq[T](count)

proc chargeAllocation(r: var Reader, bytes: int64, name: string) {.raises: [ValueError].} =
  ## Accounts for memory the model keeps against the read budget.
  if bytes < 0 or bytes > r.limits.maxTotalAllocationBytes - r.allocatedBytes:
    raise newException(
      PmxLimitError,
      fmt"{name} allocation of {bytes} bytes exceeds the remaining parser budget of " &
        $((r.limits.maxTotalAllocationBytes - r.allocatedBytes)) & " bytes.")
  r.allocatedBytes += bytes

template chargeRefObject(r: var Reader, T: typedesc, name: string) =
  ## Accounts for heap objects against the memory budget.
  r.chargeAllocation(int64(sizeof(default(T)[])) + GcObjectHeaderBytes, name & " object")

proc readDeform(
  r: var Reader,
  deformType: DeformKind
): DeformData {.raises: [IOError, OSError, ValueError].} =
  ## Reads the payload for one `DeformKind` variant.
  case deformType
  of dkBDEF1:
    result = DeformData(kind: dkBDEF1, bdef1: BDEF1(boneIndex1: r.readBoneIndex()))
  of dkBDEF2:
    result = DeformData(
      kind: dkBDEF2,
      bdef2: BDEF2(
        boneIndex1: r.readBoneIndex(),
        boneIndex2: r.readBoneIndex(),
        boneWeight1: r.reader.readFloat32()
      )
    )
  of dkBDEF4:
    result = DeformData(
      kind: dkBDEF4,
      bdef4: BDEF4(
        boneIndex1: r.readBoneIndex(),
        boneIndex2: r.readBoneIndex(),
        boneIndex3: r.readBoneIndex(),
        boneIndex4: r.readBoneIndex(),
        boneWeight1: r.reader.readFloat32(),
        boneWeight2: r.reader.readFloat32(),
        boneWeight3: r.reader.readFloat32(),
        boneWeight4: r.reader.readFloat32()
      )
    )
  of dkSDEF:
    result = DeformData(
      kind: dkSDEF,
      sdef: SDEF(
        boneIndex1: r.readBoneIndex(),
        boneIndex2: r.readBoneIndex(),
        boneWeight1: r.reader.readFloat32(),
        c: r.readVector3(),
        r0: r.readVector3(),
        r1: r.readVector3()
      )
    )
  of dkQDEF:
    result = DeformData(
      kind: dkQDEF,
      qdef: QDEF(
        boneIndex1: r.readBoneIndex(),
        boneIndex2: r.readBoneIndex(),
        boneIndex3: r.readBoneIndex(),
        boneIndex4: r.readBoneIndex(),
        boneWeight1: r.reader.readFloat32(),
        boneWeight2: r.reader.readFloat32(),
        boneWeight3: r.reader.readFloat32(),
        boneWeight4: r.reader.readFloat32()
      )
    )

proc readVertex(r: var Reader): Vertex {.raises: [IOError, OSError, ValueError].} =
  ## Reads a vertex and all of its UV, deform, and edge fields.
  r.chargeRefObject(Vertex, "vertex")
  new(result)
  result.position = r.readVector3()
  result.normal = r.readVector3()
  result.uv = r.readVector2()

  result.additionalUv = allocateSeq[Vector4](r, r.additionalUvCount, "vertex additional UV", 16)
  for i in 0 ..< r.additionalUvCount:
    result.additionalUv[i] = r.readVector4()

  let dType = toEnum[DeformKind](int32(r.reader.readUInt8()), "deform type")
  result.weightDeform = r.readDeform(dType)
  result.edgeScale = r.reader.readFloat32()

proc readFace(r: var Reader): Face {.raises: [IOError, OSError, ValueError].} =
  ## Reads a face as three vertex indices.
  r.chargeRefObject(Face, "face")
  Face(
    vertexIndex1: r.readVertexIndex(),
    vertexIndex2: r.readVertexIndex(),
    vertexIndex3: r.readVertexIndex()
  )

proc readTexture(r: var Reader): Texture {.raises: [IOError, OSError, ValueError].} =
  ## Reads a texture entry and decodes its path.
  r.chargeRefObject(Texture, "texture")
  let path = r.readString()
  Texture(path: path)

proc readMaterial(r: var Reader): Material {.raises: [IOError, OSError, ValueError].} =
  ## Reads a material record. The face count is stored as three indices per face, so
  ## divide it by three to get triangles.
  r.chargeRefObject(Material, "material")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.diffuseColor = r.readRGB()
  result.alpha = r.reader.readFloat32()
  result.specularColor = r.readRGB()
  result.specularStrength = r.reader.readFloat32()
  result.ambientColor = r.readRGB()
  result.flags = toMaterialFlags(int32(r.reader.readUInt8()))
  result.edgeColor = r.readRGBA()
  result.edgeScale = r.reader.readFloat32()
  result.textureIndex = r.readTextureIndex()
  result.sphereTextureIndex = r.readTextureIndex()
  result.sphereBlendMode = toEnum[SphereBlendMode](r.reader.readInt(1), "sphereBlendMode")
  result.internalToon = r.readBool("material internalToon")

  if result.internalToon:
    result.toonTextureIndex = r.reader.readInt(1)
  else:
    result.toonTextureIndex = r.readTextureIndex()

  result.comment = r.readString()
  let rawFaceCount = r.reader.readInt(4)

  if rawFaceCount < 0:
    raise newException(
      ValueError, fmt"Material '{result.nameJA}'. Face index count is negative ({rawFaceCount}).")
  result.faceCount = rawFaceCount div 3

proc readBone(r: var Reader): Bone {.raises: [IOError, OSError, ValueError].} =
  ## Reads a bone record and converts IK angles from radians to degrees.
  r.chargeRefObject(Bone, "bone")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.position = r.readVector3()
  result.parentBoneIndex = r.readBoneIndex()
  result.layer = r.reader.readInt(4)
  result.flags = toBoneFlags(int32(r.reader.readUInt16()))

  if result.flags.connection:
    result.tailIndex = r.readBoneIndex()
  else:
    result.tailPosition = r.readVector3()
    result.tailIndex = -1

  if result.flags.inheritRotation or result.flags.inheritTranslation:
    result.inheritParentIndex = r.readBoneIndex()
    result.inheritParentInfluence = r.reader.readFloat32()
  else:
    result.inheritParentIndex = -1

  if result.flags.fixedAxis:
    result.fixedAxisDirection = r.readVector3()

  if result.flags.localCoordinate:
    result.localXVector = r.readVector3()
    result.localZVector = r.readVector3()

  if result.flags.externalParentDeform:
    result.externalParentKey = r.reader.readInt(4)
  else:
    result.externalParentKey = -1

  if result.flags.ik:
    result.ik.targetIndex = r.readBoneIndex()
    result.ik.loopCount = r.reader.readInt(4)
    result.ik.limitAngle = radiansToDegrees(
      r.reader.readFloat32(), "Bone IK limitAngle", r.limits.acceptNonFiniteFloats)

    let linkCount = r.reader.readInt(4)
    result.ik.links = allocateSeq[IKLink](r, linkCount, "IK link", r.boneIndexSize + 1)

    for i in 0 ..< linkCount:
      result.ik.links[i].boneIndex = r.readBoneIndex()
      result.ik.links[i].hasLimits = r.readBool("IK link hasLimits")
      if result.ik.links[i].hasLimits:
        let rawMin = r.readVector3()
        let rawMax = r.readVector3()
        result.ik.links[i].limitMin = Vector3(
          x: radiansToDegrees(rawMin.x, "IK link minimum.x", r.limits.acceptNonFiniteFloats),
          y: radiansToDegrees(rawMin.y, "IK link minimum.y", r.limits.acceptNonFiniteFloats),
          z: radiansToDegrees(rawMin.z, "IK link minimum.z", r.limits.acceptNonFiniteFloats)
        )
        result.ik.links[i].limitMax = Vector3(
          x: radiansToDegrees(rawMax.x, "IK link maximum.x", r.limits.acceptNonFiniteFloats),
          y: radiansToDegrees(rawMax.y, "IK link maximum.y", r.limits.acceptNonFiniteFloats),
          z: radiansToDegrees(rawMax.z, "IK link maximum.z", r.limits.acceptNonFiniteFloats)
        )

proc readMorph(r: var Reader): Morph {.raises: [IOError, OSError, ValueError].} =
  ## Reads a morph and the offset layout its type selects.
  r.chargeRefObject(Morph, "morph")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.panelType = toEnum[MorphPanelType](r.reader.readInt(1), "panelType")
  result.morphType = toEnum[MorphType](r.reader.readInt(1), "morphType")

  let offsetCount = r.reader.readInt(4)
  let minOffsetBytes =
    case result.morphType
    of mtGroup, mtFlip:
      r.morphIndexSize + 4
    of mtVertex:
      r.vertexIndexSize + 12
    of mtBone:
      r.boneIndexSize + 28
    of mtUV, mtUVExt1, mtUVExt2, mtUVExt3, mtUVExt4:
      r.vertexIndexSize + 16
    of mtMaterial:
      r.materialIndexSize + 113
    of mtImpulse:
      r.rigidBodyIndexSize + 25
  result.offsetData = allocateSeq[MorphOffset](r, offsetCount, "morph offset", minOffsetBytes)

  for i in 0 ..< offsetCount:
    case result.morphType
    of mtGroup:
      result.offsetData[i] = MorphOffset(
        kind: moGroup,
        group: GroupMorphOffset(morphIndex: r.readMorphIndex(), influence: r.reader.readFloat32())
      )
    of mtVertex:
      result.offsetData[i] = MorphOffset(
        kind: moVertex,
        vertex: VertexMorphOffset(vertexIndex: r.readVertexIndex(), translation: r.readVector3())
      )
    of mtBone:
      result.offsetData[i] = MorphOffset(
        kind: moBone,
        bone: BoneMorphOffset(
          boneIndex: r.readBoneIndex(),
          translation: r.readVector3(),
          rotation: r.readQuaternion()
        )
      )
    of mtUV, mtUVExt1, mtUVExt2, mtUVExt3, mtUVExt4:
      result.offsetData[i] = MorphOffset(
        kind: moUV,
        uv: UVMorphOffset(vertexIndex: r.readVertexIndex(), floats: r.readVector4())
      )
    of mtMaterial:
      result.offsetData[i] = MorphOffset(
        kind: moMaterial,
        material: MaterialMorphOffset(
          materialIndex: r.readMaterialIndex(),
          blendMode: toEnum[MaterialMorphBlendMode](r.reader.readInt(1), "material morph blendMode"),
          diffuseColor: r.readRGBA(),
          specularColor: r.readRGB(),
          specularStrength: r.reader.readFloat32(),
          ambientColor: r.readRGB(),
          edgeColor: r.readRGBA(),
          edgeScale: r.reader.readFloat32(),
          textureTint: r.readRGBA(),
          sphereTint: r.readRGBA(),
          toonTint: r.readRGBA()
        )
      )
    of mtFlip:
      result.offsetData[i] = MorphOffset(
        kind: moFlip,
        flip: FlipMorphOffset(morphIndex: r.readMorphIndex(), influence: r.reader.readFloat32())
      )
    of mtImpulse:
      result.offsetData[i] = MorphOffset(
        kind: moImpulse,
        impulse: ImpulseMorphOffset(
          rigidBodyIndex: r.readRigidBodyIndex(),
          localFlag: r.readBool("impulse morph localFlag"),
          movementSpeed: r.readVector3(),
          rotationTorque: r.readVector3()
        )
      )

proc readDisplaySlot(r: var Reader): DisplaySlot {.raises: [IOError, OSError, ValueError].} =
  ## Reads a display slot and its bone or morph entries.
  r.chargeRefObject(DisplaySlot, "display slot")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.specialFlag = r.readBool("display slot specialFlag")

  let count = r.reader.readInt(4)
  result.frames = allocateSeq[DisplayFrame](r, count, "display frame", 2)

  for i in 0 ..< count:
    let frameType = toEnum[DisplayFrameType](r.reader.readInt(1), "display frame type")
    let index =
      if frameType == dftBone:
        r.readBoneIndex()
      else:
        r.readMorphIndex()

    result.frames[i] = DisplayFrame(frameType: frameType, targetIndex: index)

proc readRigidBody(r: var Reader): RigidBody {.raises: [IOError, OSError, ValueError].} =
  ## Reads a rigid body, converting the stored zero-based group to one-based.
  r.chargeRefObject(RigidBody, "rigid body")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.relatedBoneIndex = r.readBoneIndex()
  result.groupId = r.reader.readInt(1) + 1

  result.nonCollisionMask = toCollisionMask(int32(r.reader.readUInt16()))
  result.shape = toEnum[RigidBodyShape](r.reader.readInt(1), "rigid body shape")
  result.shapeSize = r.readVector3()
  result.shapePosition = r.readVector3()
  result.shapeRotation = r.readVector3()
  result.mass = r.reader.readFloat32()
  result.moveAttenuation = r.reader.readFloat32()
  result.rotationDamping = r.reader.readFloat32()
  result.repulsion = r.reader.readFloat32()
  result.frictionForce = r.reader.readFloat32()
  result.physicsMode = toEnum[PhysicsMode](r.reader.readInt(1), "physics mode")

proc readJoint(r: var Reader): Joint {.raises: [IOError, OSError, ValueError].} =
  ## Reads a joint connecting two rigid bodies.
  r.chargeRefObject(Joint, "joint")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.jointType = toEnum[JointType](r.reader.readInt(1), "joint type")
  result.rigidBodyIndexA = r.readRigidBodyIndex()
  result.rigidBodyIndexB = r.readRigidBodyIndex()
  result.position = r.readVector3()
  result.rotation = r.readVector3()
  result.positionMinimum = r.readVector3()
  result.positionMaximum = r.readVector3()
  result.rotationMinimum = r.readVector3()
  result.rotationMaximum = r.readVector3()
  result.positionSpring = r.readVector3()
  result.rotationSpring = r.readVector3()

proc readSoftBody(r: var Reader): SoftBody {.raises: [IOError, OSError, ValueError].} =
  ## Reads a PMX 2.1 soft body record, converting zero-based groups to one-based.
  r.chargeRefObject(SoftBody, "soft body")
  new(result)
  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.shape = toEnum[SoftBodyShape](r.reader.readInt(1), "soft body shape")
  result.materialIndex = r.readMaterialIndex()
  result.groupId = r.reader.readInt(1) + 1

  result.nonCollisionMask = toCollisionMask(int32(r.reader.readUInt16()))
  result.flags = toSoftBodyFlags(int32(r.reader.readUInt8()))
  result.bLinkCreateDistance = r.reader.readInt(4)
  result.numberOfClusters = r.reader.readInt(4)
  result.totalMass = r.reader.readFloat32()
  result.collisionMargin = r.reader.readFloat32()
  result.aerodynamicsModel = toEnum[AerodynamicsModel](r.reader.readInt(4), "aerodynamics model")

  result.config.vcf = r.reader.readFloat32()
  result.config.dp = r.reader.readFloat32()
  result.config.dg = r.reader.readFloat32()
  result.config.lf = r.reader.readFloat32()
  result.config.pr = r.reader.readFloat32()
  result.config.vc = r.reader.readFloat32()
  result.config.df = r.reader.readFloat32()
  result.config.mt = r.reader.readFloat32()
  result.config.chr = r.reader.readFloat32()
  result.config.khr = r.reader.readFloat32()
  result.config.`shr` = r.reader.readFloat32()
  result.config.ahr = r.reader.readFloat32()

  result.cluster.srhrCl = r.reader.readFloat32()
  result.cluster.skhrCl = r.reader.readFloat32()
  result.cluster.sshrCl = r.reader.readFloat32()
  result.cluster.srSpltCl = r.reader.readFloat32()
  result.cluster.skSpltCl = r.reader.readFloat32()
  result.cluster.ssSpltCl = r.reader.readFloat32()

  result.iteration.vIt = r.reader.readInt(4)
  result.iteration.pIt = r.reader.readInt(4)
  result.iteration.dIt = r.reader.readInt(4)
  result.iteration.cIt = r.reader.readInt(4)

  result.material.lst = r.reader.readFloat32()
  result.material.ast = r.reader.readFloat32()
  result.material.vst = r.reader.readFloat32()

  let anchorCount = r.reader.readInt(4)
  result.anchorRigidBodies = allocateSeq[AnchorRigidBody](
    r, anchorCount, "anchor rigid body", r.rigidBodyIndexSize + r.vertexIndexSize + 1)

  for i in 0 ..< anchorCount:
    result.anchorRigidBodies[i] = AnchorRigidBody(
      rigidBodyIndex: r.readRigidBodyIndex(),
      vertexIndex: r.readVertexIndex(),
      nearMode: r.readBool("soft body anchor nearMode")
    )

  let pinnedCount = r.reader.readInt(4)
  result.vertexPins = allocateSeq[int32](r, pinnedCount, "vertex pin", r.vertexIndexSize)

  for i in 0 ..< pinnedCount:
    result.vertexPins[i] = r.readVertexIndex()

proc readPmxInternal(
  s: Stream,
  limits: PmxReadLimits,
  sourceLength: int64): PmxModel {.raises: [IOError, OSError, ValueError].} =
  ## Parses a PMX model from an open stream after validating headers and limits.
  if s == nil:
    raise newException(ValueError, "Stream is nil.")
  validateLimits(limits)
  validateSourceLength(limits, sourceLength)
  let modelObjectBytes = int64(sizeof(typeof(PmxModel()[])))
  if modelObjectBytes > limits.maxTotalAllocationBytes:
    raise newException(
      PmxLimitError,
      fmt"PMX model object requires {modelObjectBytes} bytes, exceeding the allocation budget of {limits.maxTotalAllocationBytes} bytes."
    )
  new(result)
  var initReader = newBinaryReader(s, limits.acceptNonFiniteFloats)
  var header = newString(4)
  try:
    for i in 0 ..< header.len:
      header[i] = char(initReader.readUInt8())
  except PmxTruncatedError:
    raise newException(PmxTruncatedError, "Stream truncated. Could not read PMX header.")

  if header != "PMX ":
    raise newException(ValueError, fmt"Invalid PMX header magic {repr(header)}. Expected 'PMX '.")
  let rawVersionBits = initReader.readUInt32()

  if rawVersionBits == 0x40000000'u32:
    result.version = pmx20
  elif rawVersionBits == 0x40066666'u32:
    result.version = pmx21
  else:
    raise newException(ValueError, fmt"Unsupported PMX version bits 0x{rawVersionBits:08X}.")

  let flagsSize = int32(initReader.readUInt8())
  if flagsSize != 8:
    raise newException(PmxFormatError, fmt"Unsupported globals count {flagsSize}; expected exactly 8.")

  result.textEncoding = toEnum[TextEncoding](int32(initReader.readUInt8()), "text encoding")
  result.additionalUvCount = int32(initReader.readUInt8())
  if result.additionalUvCount > 4:
    raise newException(
      ValueError, fmt"Additional UV count {result.additionalUvCount} is out of range [0, 4].")

  let vSize = int32(initReader.readUInt8())
  let tSize = int32(initReader.readUInt8())
  let mSize = int32(initReader.readUInt8())
  let bSize = int32(initReader.readUInt8())
  let mrSize = int32(initReader.readUInt8())
  let rSize = int32(initReader.readUInt8())

  for (sz, name) in
    [
      (vSize, "vertex"),
      (tSize, "texture"),
      (mSize, "material"),
      (bSize, "bone"),
      (mrSize, "morph"),
      (rSize, "rigid body")
    ]:
    if sz notin ValidIndexSizes:
      raise newException(ValueError, fmt"Invalid {name} index size {sz}.")

  var r = newReader(
    initReader, result.textEncoding, result.additionalUvCount, vSize, tSize, mSize, bSize, mrSize, rSize,
    limits, sourceLength)
  r.allocatedBytes = modelObjectBytes

  result.nameJA = r.readString()
  result.nameEN = r.readString()
  result.commentsJA = r.readString()
  result.commentsEN = r.readString()

  let vCount = r.reader.readInt(4)
  result.vertices = allocateSeq[Vertex](
    r, vCount, "vertex", 37 + result.additionalUvCount * 16 + r.boneIndexSize)

  for i in 0 ..< vCount:
    result.vertices[i] = r.readVertex()

  let rawFaceCount = r.reader.readInt(4)
  if rawFaceCount < 0:
    raise newException(ValueError, fmt"Face index count is negative ({rawFaceCount}).")

  let fCount = rawFaceCount div 3
  result.faces = allocateSeq[Face](r, fCount, "face", 3 * r.vertexIndexSize)
  for i in 0 ..< fCount:
    result.faces[i] = r.readFace()
  for _ in 0 ..< (rawFaceCount mod 3):
    discard r.readVertexIndex()

  let texCount = r.reader.readInt(4)
  result.textures = allocateSeq[Texture](r, texCount, "texture", 4)
  for i in 0 ..< texCount:
    result.textures[i] = r.readTexture()

  let matCount = r.reader.readInt(4)
  result.materials = allocateSeq[Material](r, matCount, "material", 84 + 2 * r.textureIndexSize)
  for i in 0 ..< matCount:
    result.materials[i] = r.readMaterial()

  let boneCount = r.reader.readInt(4)
  result.bones = allocateSeq[Bone](r, boneCount, "bone", 26 + 2 * r.boneIndexSize)
  for i in 0 ..< boneCount:
    result.bones[i] = r.readBone()

  let morphCount = r.reader.readInt(4)
  result.morphs = allocateSeq[Morph](r, morphCount, "morph", 14)
  for i in 0 ..< morphCount:
    result.morphs[i] = r.readMorph()

  let displayCount = r.reader.readInt(4)
  result.displayFrames = allocateSeq[DisplaySlot](r, displayCount, "display slot", 13)
  for i in 0 ..< displayCount:
    result.displayFrames[i] = r.readDisplaySlot()

  let rigidBodyCount = r.reader.readInt(4)
  result.rigidBodies = allocateSeq[RigidBody](r, rigidBodyCount, "rigid body", 69 + r.boneIndexSize)
  for i in 0 ..< rigidBodyCount:
    result.rigidBodies[i] = r.readRigidBody()

  let jointCount = r.reader.readInt(4)
  result.joints = allocateSeq[Joint](r, jointCount, "joint", 105 + 2 * r.rigidBodyIndexSize)
  for i in 0 ..< jointCount:
    result.joints[i] = r.readJoint()

  if result.version == pmx21:
    let softBodyCount = r.reader.readInt(4)
    result.softBodies = allocateSeq[SoftBody](r, softBodyCount, "soft body", 141 + r.materialIndexSize)
    for i in 0 ..< softBodyCount:
      result.softBodies[i] = r.readSoftBody()
  else:
    result.softBodies = @[]

  if not r.reader.isEnd():
    raise newException(ValueError, "PMX stream has trailing bytes after the last section.")

proc parsePmx(
  s: Stream,
  limits: PmxReadLimits,
  sourceLength: int64
): PmxModel {.raises: [IOError, OSError, ValueError].} =
  ## Internal parsing wrapper that translates I/O exceptions into format errors.
  try:
    result = readPmxInternal(s, limits, sourceLength)
  except PmxSourceLimitIoError as exc:
    raise newException(PmxLimitError, exc.msg, exc)
  except PmxTruncatedIoError as exc:
    raise newException(PmxTruncatedError, exc.msg, exc)
  except PmxFormatError:
    raise
  except ValueError as exc:
    raise newException(PmxFormatError, exc.msg, exc)

proc readPmx*(s: Stream, limits = DefaultPmxReadLimits): PmxModel {.raises: [IOError, OSError, ValueError].} =
  ## Reads a PMX model from an open stream.
  validateLimits(limits)
  parsePmx(newSourceLimitedStream(s, limits.maxSourceBytes), limits, -1)

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  proc readPmx*(
    filePath: string,
    limits = DefaultPmxReadLimits
  ): PmxModel {.raises: [IOError, OSError, ValueError].} =
    ## Reads a PMX model from disk, saving the parent directory for relative texture paths.
    if filePath.len == 0:
      raise newException(ValueError, "File path must not be empty.")
    if '\0' in filePath:
      raise newException(ValueError, "File path must not contain NUL bytes.")
    validateLimits(limits)
    let s = newFileStream(filePath, fmRead)
    if s == nil:
      if not fileExists(filePath):
        raise newException(IOError, fmt"File not found: '{filePath}'.")
      raise newException(IOError, fmt"Cannot open '{filePath}'. Permission denied or file is locked.")
    defer: s.close()

    var sourceLength = -1'i64
    try:
      sourceLength = int64(getFileSize(filePath))
    except OSError:
      discard
    validateSourceLength(limits, sourceLength)

    let limited = newSourceLimitedStream(s, sourceLength)
    result = parsePmx(limited, limits, sourceLength)
    result.directory = normalizedPath(absolutePath(parentDir(filePath)))

proc readPmx*(
  data: seq[byte],
  limits = DefaultPmxReadLimits
): PmxModel {.raises: [IOError, OSError, ValueError].} =
  ## Reads a PMX model from an in-memory byte buffer.
  validateLimits(limits)
  if data.len == 0:
    raise newException(PmxFormatError, "Data buffer is empty.")
  validateSourceLength(limits, int64(data.len))

  when defined(js):
    let s = newStringStream(bytesToString(data))
  else:
    let s = newByteReadStream(data)
  result = parsePmx(s, limits, int64(data.len))
