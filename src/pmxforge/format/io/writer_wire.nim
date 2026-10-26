## Wire encoding for the writer.
##
## Provides the per-element serialization behind `writePmx`. Included by `writer.nim`;
## do not import it directly.

when not declared(PmxWriteLimits):
  {.fatal: "Include writer_wire.nim from writer.nim; do not import it.".}

const MaxWriterContextNameBytes = 48 ## Longest element name copied into a writer label.

func contextName(name: string): string =
  ## Returns a bounded name suffix for a diagnostic label; long names are left out.
  if name.len == 0 or name.len > MaxWriterContextNameBytes:
    ""
  else:
    " '" & name & "'"

type
  Writer = object ## State for one PMX write pass.
    writer: BinaryWriter ## Buffered stream writer.
    mode: PmxWriteMode ## Active write mode (strict, lenient, repair).
    textEncoding: TextEncoding ## Text encoding declared in header.
    additionalUvCount: int32 ## Number of extra UV channels (0-4).
    vertexIndexSize: int32 ## Byte width of vertex indices (1, 2, or 4).
    textureIndexSize: int32 ## Byte width of texture indices (1, 2, or 4).
    materialIndexSize: int32 ## Byte width of material indices (1, 2, or 4).
    boneIndexSize: int32 ## Byte width of bone indices (1, 2, or 4).
    morphIndexSize: int32 ## Byte width of morph indices (1, 2, or 4).
    rigidBodyIndexSize: int32 ## Byte width of rigid body indices (1, 2, or 4).
    maxStringBytes: int ## Maximum allowed bytes per string.

proc newWriter(
  stream: Stream,
  textEnc: TextEncoding,
  additionalUv: int32,
  vertexIdxSize: int32,
  textureIdxSize: int32,
  materialIdxSize: int32,
  boneIdxSize: int32,
  morphIdxSize: int32,
  rigidBodyIdxSize: int32,
  mode: PmxWriteMode,
  maxStringBytes: int
): Writer {.raises: [ValueError].} =
  ## Creates a writer with the model's text encoding and index widths.
  result.writer = newBinaryWriter(stream)
  result.mode = if mode == pwmRepair: pwmStrict else: mode
  result.textEncoding = textEnc
  result.additionalUvCount = additionalUv
  result.vertexIndexSize = vertexIdxSize
  result.textureIndexSize = textureIdxSize
  result.materialIndexSize = materialIdxSize
  result.boneIndexSize = boneIdxSize
  result.morphIndexSize = morphIdxSize
  result.rigidBodyIndexSize = rigidBodyIdxSize
  result.maxStringBytes = maxStringBytes

proc writeString(w: var Writer, text: string) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a length-prefixed string using the model's declared encoding.
  w.writer.writeString(text, int32(w.textEncoding), w.maxStringBytes)

proc checkCount(count: int, name: string) {.raises: [ValueError].} =
  ## Checks `count` before writing the PMX int32 count.
  if count > MaxElementCount:
    raise newException(ValueError, fmt"{name} count {count} exceeds the limit of {MaxElementCount}.")

proc writeVector2(w: var Writer, v: Vector2) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a `Vector2` as two `float32` values.
  checkFinite(v.x, "Vector2.x")
  checkFinite(v.y, "Vector2.y")
  w.writer.writeFloat32(v.x)
  w.writer.writeFloat32(v.y)

proc writeVector3(w: var Writer, v: Vector3) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a `Vector3` as three `float32` values.
  checkFinite(v.x, "Vector3.x")
  checkFinite(v.y, "Vector3.y")
  checkFinite(v.z, "Vector3.z")
  w.writer.writeFloat32(v.x)
  w.writer.writeFloat32(v.y)
  w.writer.writeFloat32(v.z)

proc writeVector4(w: var Writer, v: Vector4) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a `Vector4` as four `float32` values.
  checkFinite(v.x, "Vector4.x")
  checkFinite(v.y, "Vector4.y")
  checkFinite(v.z, "Vector4.z")
  checkFinite(v.w, "Vector4.w")
  w.writer.writeFloat32(v.x)
  w.writer.writeFloat32(v.y)
  w.writer.writeFloat32(v.z)
  w.writer.writeFloat32(v.w)

proc writeQuaternion(w: var Writer, q: Quaternion) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a quaternion as four `float32` values.
  checkFinite(q.x, "Quaternion.x")
  checkFinite(q.y, "Quaternion.y")
  checkFinite(q.z, "Quaternion.z")
  checkFinite(q.w, "Quaternion.w")
  w.writer.writeFloat32(q.x)
  w.writer.writeFloat32(q.y)
  w.writer.writeFloat32(q.z)
  w.writer.writeFloat32(q.w)

proc writeRGB(w: var Writer, c: RGB) {.raises: [IOError, OSError, ValueError].} =
  ## Writes RGB as three `float32` channel values.
  checkFinite(c.r, "RGB.r")
  checkFinite(c.g, "RGB.g")
  checkFinite(c.b, "RGB.b")
  w.writer.writeFloat32(c.r)
  w.writer.writeFloat32(c.g)
  w.writer.writeFloat32(c.b)

proc writeRGBA(w: var Writer, c: RGBA) {.raises: [IOError, OSError, ValueError].} =
  ## Writes RGBA as four `float32` channel values.
  checkFinite(c.r, "RGBA.r")
  checkFinite(c.g, "RGBA.g")
  checkFinite(c.b, "RGBA.b")
  checkFinite(c.a, "RGBA.a")
  w.writer.writeFloat32(c.r)
  w.writer.writeFloat32(c.g)
  w.writer.writeFloat32(c.b)
  w.writer.writeFloat32(c.a)

proc writeVertexIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes an unsigned vertex index; this field has no null sentinel.
  w.writer.writeVertexIndex(idx, w.vertexIndexSize)

proc writeTextureIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed texture reference; `-1` is the null sentinel.
  w.writer.writeIndex(idx, w.textureIndexSize)

proc writeMaterialIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed material reference; `-1` is the null sentinel.
  w.writer.writeIndex(idx, w.materialIndexSize)

proc writeBoneIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed bone reference; `-1` is the null sentinel.
  w.writer.writeIndex(idx, w.boneIndexSize)

proc writeMorphIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed morph reference; `-1` is the null sentinel.
  w.writer.writeIndex(idx, w.morphIndexSize)

proc writeRigidBodyIndex(w: var Writer, idx: int32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed rigid-body reference; `-1` is the null sentinel.
  w.writer.writeIndex(idx, w.rigidBodyIndexSize)

proc checkWeight(weight: float32, label: string) {.raises: [ValueError].} =
  ## Writes a weight after checking that it lies in `[0, 1]`.
  checkUnitRange(weight, fmt"{label} weight")

proc writeDeform(w: var Writer, deform: DeformData) {.raises: [IOError, OSError, ValueError].} =
  ## Writes the deform kind byte and its bone payload. Weights are checked first, so a
  ## bad weight never reaches the stream.
  case deform.kind
  of dkBDEF1:
    w.writer.writeUInt8(0'u8)
    w.writeBoneIndex(deform.bdef1.boneIndex1)

  of dkBDEF2:
    if w.mode == pwmStrict:
      checkWeight(deform.bdef2.boneWeight1, "BDEF2")
    w.writer.writeUInt8(1'u8)
    w.writeBoneIndex(deform.bdef2.boneIndex1)
    w.writeBoneIndex(deform.bdef2.boneIndex2)
    w.writer.writeFloat32(deform.bdef2.boneWeight1)

  of dkBDEF4:
    if w.mode == pwmStrict:
      checkWeight(deform.bdef4.boneWeight1, "BDEF4[0]")
      checkWeight(deform.bdef4.boneWeight2, "BDEF4[1]")
      checkWeight(deform.bdef4.boneWeight3, "BDEF4[2]")
      checkWeight(deform.bdef4.boneWeight4, "BDEF4[3]")
    w.writer.writeUInt8(2'u8)
    w.writeBoneIndex(deform.bdef4.boneIndex1)
    w.writeBoneIndex(deform.bdef4.boneIndex2)
    w.writeBoneIndex(deform.bdef4.boneIndex3)
    w.writeBoneIndex(deform.bdef4.boneIndex4)
    w.writer.writeFloat32(deform.bdef4.boneWeight1)
    w.writer.writeFloat32(deform.bdef4.boneWeight2)
    w.writer.writeFloat32(deform.bdef4.boneWeight3)
    w.writer.writeFloat32(deform.bdef4.boneWeight4)

  of dkSDEF:
    if w.mode == pwmStrict:
      checkWeight(deform.sdef.boneWeight1, "SDEF")
    w.writer.writeUInt8(3'u8)
    w.writeBoneIndex(deform.sdef.boneIndex1)
    w.writeBoneIndex(deform.sdef.boneIndex2)
    w.writer.writeFloat32(deform.sdef.boneWeight1)
    w.writeVector3(deform.sdef.c)
    w.writeVector3(deform.sdef.r0)
    w.writeVector3(deform.sdef.r1)

  of dkQDEF:
    if w.mode == pwmStrict:
      checkWeight(deform.qdef.boneWeight1, "QDEF[0]")
      checkWeight(deform.qdef.boneWeight2, "QDEF[1]")
      checkWeight(deform.qdef.boneWeight3, "QDEF[2]")
      checkWeight(deform.qdef.boneWeight4, "QDEF[3]")
    w.writer.writeUInt8(4'u8)
    w.writeBoneIndex(deform.qdef.boneIndex1)
    w.writeBoneIndex(deform.qdef.boneIndex2)
    w.writeBoneIndex(deform.qdef.boneIndex3)
    w.writeBoneIndex(deform.qdef.boneIndex4)
    w.writer.writeFloat32(deform.qdef.boneWeight1)
    w.writer.writeFloat32(deform.qdef.boneWeight2)
    w.writer.writeFloat32(deform.qdef.boneWeight3)
    w.writer.writeFloat32(deform.qdef.boneWeight4)

proc writeVertex(w: var Writer, vertex: Vertex) {.raises: [IOError, OSError, ValueError].} =
  ## Writes position, normal, UV, deform data, and edge scale.
  if vertex == nil:
    raise newException(ValueError, "Vertex is nil.")

  if vertex.additionalUv.len > 4:
    raise newException(
      ValueError, fmt"Vertex has {vertex.additionalUv.len} additional UV sets, maximum is 4.")

  if int32(vertex.additionalUv.len) != w.additionalUvCount:
    raise newException(
      ValueError,
      fmt"Vertex has {vertex.additionalUv.len} additional UV sets; model.additionalUvCount requires exactly {w.additionalUvCount}."
    )

  w.writeVector3(vertex.position)
  w.writeVector3(vertex.normal)
  w.writeVector2(vertex.uv)

  for i in 0 ..< w.additionalUvCount:
    w.writeVector4(vertex.additionalUv[i])

  w.writeDeform(vertex.weightDeform)
  if w.mode == pwmStrict:
    checkNonNegativeFinite(vertex.edgeScale, "Vertex edgeScale")
  else:
    checkFinite(vertex.edgeScale, "Vertex edgeScale")
  w.writer.writeFloat32(vertex.edgeScale)

proc writeFace(w: var Writer, face: Face) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a face as three vertex indices.
  if face == nil:
    raise newException(ValueError, "Face is nil.")
  w.writeVertexIndex(face.vertexIndex1)
  w.writeVertexIndex(face.vertexIndex2)
  w.writeVertexIndex(face.vertexIndex3)

proc writeTexture(w: var Writer, tex: Texture) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a texture path as a length-prefixed string.
  if tex == nil:
    raise newException(ValueError, "Texture is nil.")
  w.writeString(tex.path)

proc writeMaterial(w: var Writer, mat: Material) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a material record. The wire stores three indices per face, so `faceCount`
  ## is multiplied by three.
  if mat == nil:
    raise newException(ValueError, "Material is nil.")
  let flags = toMask(mat.flags)
  if mat.faceCount < 0:
    raise newException(ValueError, fmt"Material '{mat.nameJA}'. faceCount is negative ({mat.faceCount}).")
  if mat.faceCount > (high(int32) div 3):
    raise newException(ValueError, fmt"Material '{mat.nameJA}'. faceCount {mat.faceCount} is too large.")
  if flags < 0 or flags > 0xFF:
    raise newException(ValueError, fmt"Material '{mat.nameJA}'. flags {flags} do not fit the PMX byte field.")
  if w.mode == pwmStrict:
    checkUnitRange(mat.alpha, fmt"Material '{mat.nameJA}'. Alpha")
    checkNonNegativeFinite(mat.specularStrength, fmt"Material '{mat.nameJA}'. specularStrength")
    checkNonNegativeFinite(mat.edgeScale, fmt"Material '{mat.nameJA}'. edgeScale")
  else:
    checkFinite(mat.alpha, fmt"Material '{mat.nameJA}'. Alpha")
    checkFinite(mat.specularStrength, fmt"Material '{mat.nameJA}'. specularStrength")
    checkFinite(mat.edgeScale, fmt"Material '{mat.nameJA}'. edgeScale")
  if mat.internalToon and (mat.toonTextureIndex < -128 or mat.toonTextureIndex > 127):
    raise newException(
      ValueError, fmt"Material '{mat.nameJA}'. toonTextureIndex does not fit the PMX byte field.")
  if w.mode == pwmStrict and mat.internalToon and (mat.toonTextureIndex < 0 or mat.toonTextureIndex > 9):
    raise newException(
      ValueError, fmt"Material '{mat.nameJA}'. Toon index {mat.toonTextureIndex} is out of range [0, 9].")

  w.writeString(mat.nameJA)
  w.writeString(mat.nameEN)
  w.writeRGB(mat.diffuseColor)
  w.writer.writeFloat32(mat.alpha)
  w.writeRGB(mat.specularColor)
  w.writer.writeFloat32(mat.specularStrength)
  w.writeRGB(mat.ambientColor)
  w.writer.writeUInt8(uint8(flags))
  w.writeRGBA(mat.edgeColor)
  w.writer.writeFloat32(mat.edgeScale)
  w.writeTextureIndex(mat.textureIndex)
  w.writeTextureIndex(mat.sphereTextureIndex)
  w.writer.writeInt(int32(mat.sphereBlendMode), 1)
  w.writer.writeInt(if mat.internalToon: 1 else: 0, 1)

  if mat.internalToon:
    w.writer.writeInt(mat.toonTextureIndex, 1)
  else:
    w.writeTextureIndex(mat.toonTextureIndex)

  w.writeString(mat.comment)
  w.writer.writeInt(mat.faceCount * 3, 4)

proc writeBone(w: var Writer, bone: Bone) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a bone record, converting IK angles from degrees to radians.
  if bone == nil:
    raise newException(ValueError, "Bone is nil.")

  let flags = toMask(bone.flags)
  let hasIK = bone.flags.ik
  let hasFixedAxis = bone.flags.fixedAxis
  let hasLocalAxis = bone.flags.localCoordinate
  let hasInheritRot = bone.flags.inheritRotation
  let hasInheritTrans = bone.flags.inheritTranslation

  if flags < 0 or flags > 0xFFFF:
    raise newException(ValueError, fmt"Bone '{bone.nameJA}'. flags {flags} do not fit the PMX field.")

  if w.mode == pwmStrict and hasIK and bone.ik.loopCount <= 0:
    raise newException(
      ValueError, fmt"Bone '{bone.nameJA}'. IK loopCount {bone.ik.loopCount} must be greater than 0.")

  if hasIK:
    if w.mode == pwmStrict:
      checkNonNegativeFinite(bone.ik.limitAngle, fmt"Bone '{bone.nameJA}'. IK limitAngle")
    else:
      checkFinite(bone.ik.limitAngle, fmt"Bone '{bone.nameJA}'. IK limitAngle")

  if hasInheritRot or hasInheritTrans:
    checkFinite(bone.inheritParentInfluence, fmt"Bone '{bone.nameJA}'. inheritParentInfluence")

  w.writeString(bone.nameJA)
  w.writeString(bone.nameEN)
  w.writeVector3(bone.position)
  w.writeBoneIndex(bone.parentBoneIndex)
  w.writer.writeInt(bone.layer, 4)
  w.writer.writeUInt16(uint16(flags))

  if bone.flags.connection:
    w.writeBoneIndex(bone.tailIndex)
  else:
    w.writeVector3(bone.tailPosition)

  if hasInheritRot or hasInheritTrans:
    w.writeBoneIndex(bone.inheritParentIndex)
    w.writer.writeFloat32(bone.inheritParentInfluence)

  if hasFixedAxis:
    w.writeVector3(bone.fixedAxisDirection)

  if hasLocalAxis:
    w.writeVector3(bone.localXVector)
    w.writeVector3(bone.localZVector)

  if bone.flags.externalParentDeform:
    w.writer.writeInt(bone.externalParentKey, 4)

  if hasIK:
    w.writeBoneIndex(bone.ik.targetIndex)
    w.writer.writeInt(bone.ik.loopCount, 4)
    w.writer.writeFloat32(degToRad(bone.ik.limitAngle))
    checkCount(bone.ik.links.len, fmt"Bone '{bone.nameJA}'. IK link")
    w.writer.writeInt(int32(bone.ik.links.len), 4)

    for link in bone.ik.links:
      w.writeBoneIndex(link.boneIndex)
      w.writer.writeInt(if link.hasLimits: 1 else: 0, 1)

      if link.hasLimits:
        w.writeVector3(
          Vector3(x: degToRad(link.limitMin.x), y: degToRad(link.limitMin.y), z: degToRad(link.limitMin.z)))
        w.writeVector3(
          Vector3(x: degToRad(link.limitMax.x), y: degToRad(link.limitMax.y), z: degToRad(link.limitMax.z)))

proc writeMorph(w: var Writer, morph: Morph) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a morph and its offsets. Every offset kind is checked against `morphType`
  ## before anything is written.
  if morph == nil:
    raise newException(ValueError, "Morph is nil.")

  let morphCtx = "Morph" & contextName(morph.nameJA)
  let expectedKind = getExpectedMorphOffsetKind(morph.morphType)
  for i, offset in morph.offsetData:
    if offset.kind != expectedKind:
      raise newException(
        ValueError,
        fmt"{morphCtx}. Offset [{i}] has kind '{offset.kind}', expected '{expectedKind}'.")

  w.writeString(morph.nameJA)
  w.writeString(morph.nameEN)
  w.writer.writeInt(int32(morph.panelType), 1)
  w.writer.writeInt(int32(morph.morphType), 1)
  checkCount(morph.offsetData.len, fmt"{morphCtx}. offset")
  w.writer.writeInt(int32(morph.offsetData.len), 4)

  for offset in morph.offsetData:
    case offset.kind
    of moGroup:
      checkFinite(offset.group.influence, fmt"{morphCtx}. group influence")
      w.writeMorphIndex(offset.group.morphIndex)
      w.writer.writeFloat32(offset.group.influence)
    of moVertex:
      w.writeVertexIndex(offset.vertex.vertexIndex)
      w.writeVector3(offset.vertex.translation)
    of moBone:
      w.writeBoneIndex(offset.bone.boneIndex)
      w.writeVector3(offset.bone.translation)
      w.writeQuaternion(offset.bone.rotation)
    of moUV:
      w.writeVertexIndex(offset.uv.vertexIndex)
      w.writeVector4(offset.uv.floats)
    of moMaterial:
      w.writeMaterialIndex(offset.material.materialIndex)
      w.writer.writeInt(int32(offset.material.blendMode), 1)
      w.writeRGBA(offset.material.diffuseColor)
      w.writeRGB(offset.material.specularColor)
      checkFinite(offset.material.specularStrength, fmt"{morphCtx}. material specularStrength")
      w.writer.writeFloat32(offset.material.specularStrength)
      w.writeRGB(offset.material.ambientColor)
      w.writeRGBA(offset.material.edgeColor)
      checkFinite(offset.material.edgeScale, fmt"{morphCtx}. material edgeScale")
      w.writer.writeFloat32(offset.material.edgeScale)
      w.writeRGBA(offset.material.textureTint)
      w.writeRGBA(offset.material.sphereTint)
      w.writeRGBA(offset.material.toonTint)
    of moFlip:
      checkFinite(offset.flip.influence, fmt"{morphCtx}. flip influence")
      w.writeMorphIndex(offset.flip.morphIndex)
      w.writer.writeFloat32(offset.flip.influence)
    of moImpulse:
      w.writeRigidBodyIndex(offset.impulse.rigidBodyIndex)
      w.writer.writeInt(if offset.impulse.localFlag: 1 else: 0, 1)
      w.writeVector3(offset.impulse.movementSpeed)
      w.writeVector3(offset.impulse.rotationTorque)

proc writeDisplaySlot(w: var Writer, slot: DisplaySlot) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a display slot and its frames. Each frame starts with a one-byte type, 0
  ## for a bone and 1 for a morph.
  if slot == nil:
    raise newException(ValueError, "DisplaySlot is nil.")

  w.writeString(slot.nameJA)
  w.writeString(slot.nameEN)
  w.writer.writeInt(if slot.specialFlag: 1 else: 0, 1)
  checkCount(slot.frames.len, fmt"DisplaySlot '{slot.nameJA}'. frame")
  w.writer.writeInt(int32(slot.frames.len), 4)

  for frame in slot.frames:
    w.writer.writeInt(int32(frame.frameType), 1)
    case frame.frameType
    of dftBone:
      w.writeBoneIndex(frame.targetIndex)
    of dftMorph:
      w.writeMorphIndex(frame.targetIndex)

proc writeRigidBody(w: var Writer, body: RigidBody) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a rigid body. The collision group is stored zero-based and must be in 1 .. 16.
  if body == nil:
    raise newException(ValueError, "RigidBody is nil.")
  if body.groupId notin 1'i32..16'i32:
    raise newException(
      ValueError, fmt"RigidBody '{body.nameJA}'. Group ID {body.groupId} is out of range [1, 16].")
  let nonCollisionMask = toMask(body.nonCollisionMask)
  if nonCollisionMask < 0 or nonCollisionMask > 0xFFFF:
    raise newException(
      ValueError, fmt"RigidBody '{body.nameJA}'. nonCollisionMask {nonCollisionMask} exceeds 0xFFFF.")
  if w.mode == pwmStrict:
    checkNonNegativeFinite(body.mass, fmt"RigidBody '{body.nameJA}'. Mass")
    checkNonNegativeFinite(body.moveAttenuation, fmt"RigidBody '{body.nameJA}'. moveAttenuation")
    checkNonNegativeFinite(body.rotationDamping, fmt"RigidBody '{body.nameJA}'. rotationDamping")
    checkNonNegativeFinite(body.repulsion, fmt"RigidBody '{body.nameJA}'. repulsion")
    checkNonNegativeFinite(body.frictionForce, fmt"RigidBody '{body.nameJA}'. frictionForce")
  else:
    checkFinite(body.mass, fmt"RigidBody '{body.nameJA}'. Mass")
    checkFinite(body.moveAttenuation, fmt"RigidBody '{body.nameJA}'. moveAttenuation")
    checkFinite(body.rotationDamping, fmt"RigidBody '{body.nameJA}'. rotationDamping")
    checkFinite(body.repulsion, fmt"RigidBody '{body.nameJA}'. repulsion")
    checkFinite(body.frictionForce, fmt"RigidBody '{body.nameJA}'. frictionForce")
  checkFinite(body.shapeSize, fmt"RigidBody '{body.nameJA}'. shapeSize")
  if w.mode == pwmStrict and (body.shapeSize.x < 0 or body.shapeSize.y < 0 or body.shapeSize.z < 0):
    raise newException(ValueError, fmt"RigidBody '{body.nameJA}'. shapeSize must be non-negative.")

  w.writeString(body.nameJA)
  w.writeString(body.nameEN)
  w.writeBoneIndex(body.relatedBoneIndex)
  w.writer.writeInt(body.groupId - 1, 1)
  w.writer.writeUInt16(uint16(nonCollisionMask))
  w.writer.writeInt(int32(body.shape), 1)
  w.writeVector3(body.shapeSize)
  w.writeVector3(body.shapePosition)
  w.writeVector3(body.shapeRotation)
  w.writer.writeFloat32(body.mass)
  w.writer.writeFloat32(body.moveAttenuation)
  w.writer.writeFloat32(body.rotationDamping)
  w.writer.writeFloat32(body.repulsion)
  w.writer.writeFloat32(body.frictionForce)
  w.writer.writeInt(int32(body.physicsMode), 1)

proc writeJoint(w: var Writer, joint: Joint) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a joint connecting two rigid bodies.
  if joint == nil:
    raise newException(ValueError, "Joint is nil.")
  w.writeString(joint.nameJA)
  w.writeString(joint.nameEN)
  w.writer.writeInt(int32(joint.jointType), 1)
  w.writeRigidBodyIndex(joint.rigidBodyIndexA)
  w.writeRigidBodyIndex(joint.rigidBodyIndexB)
  w.writeVector3(joint.position)
  w.writeVector3(joint.rotation)
  w.writeVector3(joint.positionMinimum)
  w.writeVector3(joint.positionMaximum)
  w.writeVector3(joint.rotationMinimum)
  w.writeVector3(joint.rotationMaximum)
  w.writeVector3(joint.positionSpring)
  w.writeVector3(joint.rotationSpring)

proc writeSoftBody(w: var Writer, sb: SoftBody) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a soft body. As with rigid bodies, the collision group must be in 1 .. 16
  ## and the wire stores it zero-based.
  if sb == nil:
    raise newException(ValueError, "SoftBody is nil.")
  if sb.groupId notin 1'i32..16'i32:
    raise newException(
      ValueError, fmt"SoftBody '{sb.nameJA}'. Group ID {sb.groupId} is out of range [1, 16].")
  let nonCollisionMask = toMask(sb.nonCollisionMask)
  let flags = toMask(sb.flags)
  if nonCollisionMask < 0 or nonCollisionMask > 0xFFFF:
    raise newException(
      ValueError, fmt"SoftBody '{sb.nameJA}'. nonCollisionMask {nonCollisionMask} exceeds 0xFFFF.")
  if flags < 0 or flags > 0xFF:
    raise newException(ValueError, fmt"SoftBody '{sb.nameJA}'. flags {flags} do not fit the PMX byte field.")
  if w.mode == pwmStrict:
    checkNonNegativeFinite(sb.totalMass, fmt"SoftBody '{sb.nameJA}'. totalMass")
    checkNonNegativeFinite(sb.collisionMargin, fmt"SoftBody '{sb.nameJA}'. collisionMargin")
  else:
    checkFinite(sb.totalMass, fmt"SoftBody '{sb.nameJA}'. totalMass")
    checkFinite(sb.collisionMargin, fmt"SoftBody '{sb.nameJA}'. collisionMargin")

  w.writeString(sb.nameJA)
  w.writeString(sb.nameEN)
  w.writer.writeInt(int32(sb.shape), 1)
  w.writeMaterialIndex(sb.materialIndex)
  w.writer.writeInt(sb.groupId - 1, 1)
  w.writer.writeUInt16(uint16(nonCollisionMask))
  w.writer.writeUInt8(uint8(flags))
  w.writer.writeInt(sb.bLinkCreateDistance, 4)
  w.writer.writeInt(sb.numberOfClusters, 4)
  w.writer.writeFloat32(sb.totalMass)
  w.writer.writeFloat32(sb.collisionMargin)
  w.writer.writeInt(int32(sb.aerodynamicsModel), 4)
  checkFinite(sb.config.vcf, fmt"SoftBody '{sb.nameJA}'. config.vcf")
  w.writer.writeFloat32(sb.config.vcf)
  checkFinite(sb.config.dp, fmt"SoftBody '{sb.nameJA}'. config.dp")
  w.writer.writeFloat32(sb.config.dp)
  checkFinite(sb.config.dg, fmt"SoftBody '{sb.nameJA}'. config.dg")
  w.writer.writeFloat32(sb.config.dg)
  checkFinite(sb.config.lf, fmt"SoftBody '{sb.nameJA}'. config.lf")
  w.writer.writeFloat32(sb.config.lf)
  checkFinite(sb.config.pr, fmt"SoftBody '{sb.nameJA}'. config.pr")
  w.writer.writeFloat32(sb.config.pr)
  checkFinite(sb.config.vc, fmt"SoftBody '{sb.nameJA}'. config.vc")
  w.writer.writeFloat32(sb.config.vc)
  checkFinite(sb.config.df, fmt"SoftBody '{sb.nameJA}'. config.df")
  w.writer.writeFloat32(sb.config.df)
  checkFinite(sb.config.mt, fmt"SoftBody '{sb.nameJA}'. config.mt")
  w.writer.writeFloat32(sb.config.mt)
  checkFinite(sb.config.chr, fmt"SoftBody '{sb.nameJA}'. config.chr")
  w.writer.writeFloat32(sb.config.chr)
  checkFinite(sb.config.khr, fmt"SoftBody '{sb.nameJA}'. config.khr")
  w.writer.writeFloat32(sb.config.khr)
  checkFinite(sb.config.`shr`, fmt"SoftBody '{sb.nameJA}'. config.shr")
  w.writer.writeFloat32(sb.config.`shr`)
  checkFinite(sb.config.ahr, fmt"SoftBody '{sb.nameJA}'. config.ahr")
  w.writer.writeFloat32(sb.config.ahr)
  checkFinite(sb.cluster.srhrCl, fmt"SoftBody '{sb.nameJA}'. cluster.srhrCl")
  w.writer.writeFloat32(sb.cluster.srhrCl)
  checkFinite(sb.cluster.skhrCl, fmt"SoftBody '{sb.nameJA}'. cluster.skhrCl")
  w.writer.writeFloat32(sb.cluster.skhrCl)
  checkFinite(sb.cluster.sshrCl, fmt"SoftBody '{sb.nameJA}'. cluster.sshrCl")
  w.writer.writeFloat32(sb.cluster.sshrCl)
  checkFinite(sb.cluster.srSpltCl, fmt"SoftBody '{sb.nameJA}'. cluster.srSpltCl")
  w.writer.writeFloat32(sb.cluster.srSpltCl)
  checkFinite(sb.cluster.skSpltCl, fmt"SoftBody '{sb.nameJA}'. cluster.skSpltCl")
  w.writer.writeFloat32(sb.cluster.skSpltCl)
  checkFinite(sb.cluster.ssSpltCl, fmt"SoftBody '{sb.nameJA}'. cluster.ssSpltCl")
  w.writer.writeFloat32(sb.cluster.ssSpltCl)
  w.writer.writeInt(sb.iteration.vIt, 4)
  w.writer.writeInt(sb.iteration.pIt, 4)
  w.writer.writeInt(sb.iteration.dIt, 4)
  w.writer.writeInt(sb.iteration.cIt, 4)
  if w.mode == pwmStrict:
    checkNonNegativeFinite(sb.material.lst, fmt"SoftBody '{sb.nameJA}'. material.lst")
  else:
    checkFinite(sb.material.lst, fmt"SoftBody '{sb.nameJA}'. material.lst")
  w.writer.writeFloat32(sb.material.lst)
  if w.mode == pwmStrict:
    checkNonNegativeFinite(sb.material.ast, fmt"SoftBody '{sb.nameJA}'. material.ast")
  else:
    checkFinite(sb.material.ast, fmt"SoftBody '{sb.nameJA}'. material.ast")
  w.writer.writeFloat32(sb.material.ast)
  if w.mode == pwmStrict:
    checkNonNegativeFinite(sb.material.vst, fmt"SoftBody '{sb.nameJA}'. material.vst")
  else:
    checkFinite(sb.material.vst, fmt"SoftBody '{sb.nameJA}'. material.vst")
  w.writer.writeFloat32(sb.material.vst)
  checkCount(sb.anchorRigidBodies.len, fmt"SoftBody '{sb.nameJA}'. anchor rigid body")
  w.writer.writeInt(int32(sb.anchorRigidBodies.len), 4)

  for anchor in sb.anchorRigidBodies:
    w.writeRigidBodyIndex(anchor.rigidBodyIndex)
    w.writeVertexIndex(anchor.vertexIndex)
    w.writer.writeInt(if anchor.nearMode: 1 else: 0, 1)

  checkCount(sb.vertexPins.len, fmt"SoftBody '{sb.nameJA}'. vertex pin")
  w.writer.writeInt(int32(sb.vertexPins.len), 4)
  for pin in sb.vertexPins:
    w.writeVertexIndex(pin)

proc getVertexIndexSize(count: int): int32 {.raises: [ValueError].} =
  ## Returns the smallest width for vertex indices. They are unsigned and have no null
  ## sentinel, so each width offers its full range.
  if count <= 0x100:
    return 1
  elif count <= 0x10000:
    return 2
  elif count <= 0x7FFFFFFF:
    return 4
  else:
    raise newException(ValueError, fmt"Too many vertices ({count}). Maximum is 2,147,483,647.")

proc getIndexSize(count: int): int32 {.raises: [ValueError].} =
  ## Returns the smallest width for signed references. Each width keeps `-1` as null
  ## and holds up to 127 or 32767.
  if count <= 0x80:
    return 1
  elif count <= 0x8000:
    return 2
  elif count <= 0x7FFFFFFF:
    return 4
  else:
    raise newException(ValueError, fmt"Too many elements ({count}). Maximum is 2,147,483,647.")

proc prepareWriteModel(
  model: PmxModel,
  autoUpgradeVersion: bool,
  mode: PmxWriteMode,
  maxStringBytes: int
): PmxModel {.raises: [ValueError].} =
  ## Prepares the model for writing, making a repaired or upgraded copy if needed.
  requireValidEnum(mode, "PMX write mode")
  if model == nil:
    raise newException(ValueError, "PmxModel is nil.")
  let needsCopy =
    mode == pwmRepair or (autoUpgradeVersion and model.version == pmx20 and model.isPmx21Only)
  if needsCopy:
    validateWritePreparation(model, maxStringBytes)
  if mode == pwmRepair:
    result = model.copy()
    try:
      result.repair()
    except ValueError as exc:
      raise newException(ValueError, fmt"Could not repair model for PMX output: {exc.msg}")
  else:
    result = model
  if autoUpgradeVersion and result != nil and result.version == pmx20 and result.isPmx21Only:
    if mode != pwmRepair:
      result = result.copy()
    result.version = pmx21

proc validateWritableModel(
  model: PmxModel,
  mode: PmxWriteMode,
  maxStringBytes: int
) {.raises: [ValueError].} =
  ## Checks the model against the selected write mode before encoding it.
  if model == nil:
    raise newException(ValueError, "Model is nil.")
  if model.additionalUvCount < 0 or model.additionalUvCount > 4:
    raise newException(ValueError, fmt"Additional UV count {model.additionalUvCount} is out of range [0, 4].")
  if mode in {pwmStrict, pwmRepair}:
    validate(model, maxStringBytes)
  else:
    validateWireSafe(model, maxStringBytes)
    if model.version == pmx20 and model.isPmx21Only:
      raise newException(
        ValueError, "The model uses PMX 2.1-only data; enable autoUpgradeVersion or target PMX 2.1.")

proc writePmxValidated(
  model: PmxModel,
  s: Stream,
  mode: PmxWriteMode,
  maxStringBytes: int
) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a validated model to the stream, computing index sizes automatically.
  let vertexIndexSize = if mode == pwmLenient: 4'i32 else: getVertexIndexSize(model.vertices.len)
  let textureIndexSize = if mode == pwmLenient: 4'i32 else: getIndexSize(model.textures.len)
  let materialIndexSize = if mode == pwmLenient: 4'i32 else: getIndexSize(model.materials.len)
  let boneIndexSize = if mode == pwmLenient: 4'i32 else: getIndexSize(model.bones.len)
  let morphIndexSize = if mode == pwmLenient: 4'i32 else: getIndexSize(model.morphs.len)
  let rigidBodyIndexSize = if mode == pwmLenient: 4'i32 else: getIndexSize(model.rigidBodies.len)

  var w = newWriter(
    s, model.textEncoding, model.additionalUvCount, vertexIndexSize, textureIndexSize, materialIndexSize,
    boneIndexSize, morphIndexSize, rigidBodyIndexSize, mode, maxStringBytes)

  w.writer.writeRawStr("PMX ")
  w.writer.writeFloat32(model.version.toFileVersion)
  w.writer.writeUInt8(8)
  w.writer.writeUInt8(uint8(model.textEncoding))
  w.writer.writeUInt8(uint8(model.additionalUvCount))
  w.writer.writeUInt8(uint8(vertexIndexSize))
  w.writer.writeUInt8(uint8(textureIndexSize))
  w.writer.writeUInt8(uint8(materialIndexSize))
  w.writer.writeUInt8(uint8(boneIndexSize))
  w.writer.writeUInt8(uint8(morphIndexSize))
  w.writer.writeUInt8(uint8(rigidBodyIndexSize))

  w.writeString(model.nameJA)
  w.writeString(model.nameEN)
  w.writeString(model.commentsJA)
  w.writeString(model.commentsEN)

  w.writer.writeInt(int32(model.vertices.len), 4)
  for v in model.vertices:
    w.writeVertex(v)

  if model.faces.len > high(int32) div 3:
    raise newException(ValueError, "Face count is too large to encode as PMX face indices.")
  w.writer.writeInt(int32(model.faces.len * 3), 4)
  for f in model.faces:
    w.writeFace(f)

  w.writer.writeInt(int32(model.textures.len), 4)
  for t in model.textures:
    w.writeTexture(t)

  w.writer.writeInt(int32(model.materials.len), 4)
  for m in model.materials:
    w.writeMaterial(m)

  w.writer.writeInt(int32(model.bones.len), 4)
  for b in model.bones:
    w.writeBone(b)

  w.writer.writeInt(int32(model.morphs.len), 4)
  for m in model.morphs:
    w.writeMorph(m)

  w.writer.writeInt(int32(model.displayFrames.len), 4)
  for d in model.displayFrames:
    w.writeDisplaySlot(d)

  w.writer.writeInt(int32(model.rigidBodies.len), 4)
  for r in model.rigidBodies:
    w.writeRigidBody(r)

  w.writer.writeInt(int32(model.joints.len), 4)
  for j in model.joints:
    w.writeJoint(j)

  if model.version == pmx21:
    w.writer.writeInt(int32(model.softBodies.len), 4)
    for sb in model.softBodies:
      w.writeSoftBody(sb)

  w.writer.flush()
