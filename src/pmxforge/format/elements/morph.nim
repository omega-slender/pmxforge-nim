## Morph records and offsets.
##
## Provides `Morph` and the tagged offset payloads for vertex, UV, bone, material,
## group, flip, and impulse morphs.

import ../../core/vectors
import ../../core/colors
import ../internal/preconditions
import ../internal/copy_helpers

type
  MorphPanelType* {.size: sizeof(int32).} = enum ## UI panel category in MMD.
    mptSystem = 0 ## Reserved / system.
    mptEyebrow = 1 ## Eyebrows (bottom left).
    mptEye = 2 ## Eyes (top left).
    mptMouth = 3 ## Mouth / lips (top right).
    mptOther = 4 ## Other / miscellaneous (bottom right).

  MorphType* {.size: sizeof(int32).} = enum ## Target type modified by this morph.
    mtGroup = 0 ## Group (controls other morphs).
    mtVertex = 1 ## Vertex position offsets.
    mtBone = 2 ## Bone transform offsets.
    mtUV = 3 ## Primary UV offsets.
    mtUVExt1 = 4 ## Extra UV 1 offsets.
    mtUVExt2 = 5 ## Extra UV 2 offsets.
    mtUVExt3 = 6 ## Extra UV 3 offsets.
    mtUVExt4 = 7 ## Extra UV 4 offsets.
    mtMaterial = 8 ## Material color and texture tint offsets.
    mtFlip = 9 ## Flip morph (PMX 2.1).
    mtImpulse = 10 ## Physics impulse (PMX 2.1).

  GroupMorphOffset* = object ## Weight multiplier applied to another morph.
    morphIndex*: int32 ## Target morph index.
    influence*: float32 ## Multiplier / blend ratio.

  VertexMorphOffset* = object ## Position offset for a single vertex.
    vertexIndex*: int32 ## Target vertex index.
    translation*: Vector3 ## Position displacement vector.

  BoneMorphOffset* = object ## Position and rotation offset for a single bone.
    boneIndex*: int32 ## Target bone index.
    translation*: Vector3 ## Position displacement vector.
    rotation*: Quaternion ## Rotation offset quaternion.

  UVMorphOffset* = object ## Texture coordinate offset for a single vertex.
    vertexIndex*: int32 ## Target vertex index.
    floats*: Vector4 ## UV displacement (X, Y are primary UV; Z, W optional).

  MaterialMorphBlendMode* {.size: sizeof(int32).} = enum ## Blend operation for material morphs.
    mmbMultiply = 0 ## Multiply existing color.
    mmbAdd = 1 ## Add to existing color.

  MaterialMorphOffset* = object ## Color and shading offsets for a material.
    materialIndex*: int32 ## Target material index (-1 for all materials).
    blendMode*: MaterialMorphBlendMode ## Blend operation (multiply or add).
    diffuseColor*: RGBA ## Diffuse color and alpha offset.
    specularColor*: RGB ## Specular highlight color offset.
    specularStrength*: float32 ## Specular shininess power offset.
    ambientColor*: RGB ## Ambient color offset.
    edgeColor*: RGBA ## Outline edge color and alpha offset.
    edgeScale*: float32 ## Outline edge thickness scale offset.
    textureTint*: RGBA ## Diffuse texture tint multiplier/offset.
    sphereTint*: RGBA ## Sphere map tint multiplier/offset.
    toonTint*: RGBA ## Toon texture tint multiplier/offset.

  FlipMorphOffset* = object ## Group morph switching between targets based on weight (PMX 2.1).
    morphIndex*: int32 ## Target morph index.
    influence*: float32 ## Threshold weight for activation.

  ImpulseMorphOffset* = object ## Physics velocity and torque applied to a rigid body (PMX 2.1).
    rigidBodyIndex*: int32 ## Target rigid body index.
    localFlag*: bool ## If true, impulse vectors are in local space.
    movementSpeed*: Vector3 ## Linear velocity impulse vector.
    rotationTorque*: Vector3 ## Angular velocity torque vector.

  MorphOffsetKind* {.size: sizeof(int32).} = enum ## Internal tag for MorphOffset variant.
    moGroup = 0 ## Group offset.
    moVertex = 1 ## Vertex offset.
    moBone = 2 ## Bone offset.
    moUV = 3 ## UV offset.
    moMaterial = 4 ## Material offset.
    moFlip = 5 ## Flip offset.
    moImpulse = 6 ## Impulse offset.

  MorphOffset* = object ## Tagged union containing one morph offset payload.
    case kind*: MorphOffsetKind ## Active offset variant.
    of moGroup:
      group*: GroupMorphOffset ## Group offset payload.
    of moVertex:
      vertex*: VertexMorphOffset ## Vertex offset payload.
    of moBone:
      bone*: BoneMorphOffset ## Bone offset payload.
    of moUV:
      uv*: UVMorphOffset ## UV offset payload.
    of moMaterial:
      material*: MaterialMorphOffset ## Material offset payload.
    of moFlip:
      flip*: FlipMorphOffset ## Flip offset payload.
    of moImpulse:
      impulse*: ImpulseMorphOffset ## Impulse offset payload.

  Morph* = ref object ## Named morph and its ordered offset records.
    nameJA*: string ## Japanese morph name.
    nameEN*: string ## English / universal morph name.
    panelType*: MorphPanelType ## UI category panel (eyebrow, eye, mouth, other).
    morphType*: MorphType ## Target kind modified by this morph.
    offsetData*: seq[MorphOffset] ## List of offset records.

proc isValid*(
  morph: Morph,
  vertexCount = -1'i32,
  boneCount = -1'i32,
  materialCount = -1'i32,
  morphCount = -1'i32,
  rigidBodyCount = -1'i32
): bool {.raises: [].}
  ## Returns true when the type, panel, and targets are valid.

proc newMorph*(
  nameJA = "",
  morphType = mtVertex,
  panelType = mptOther,
  nameEN = nameJA,
  offsetData: seq[MorphOffset] = @[]
): Morph {.raises: [ValueError].} =
  ## Creates a morph with its panel, type, and offsets.
  requireValidEnum(morphType, "Morph type")
  requireValidEnum(panelType, "Morph panel")
  result = Morph(
    nameJA: nameJA,
    nameEN: nameEN,
    panelType: panelType,
    morphType: morphType,
    offsetData: copySeq(offsetData)
  )
  if not result.isValid():
    raise newException(ValueError, "Morph contains invalid local values.")

proc getExpectedMorphOffsetKind*(morphType: MorphType): MorphOffsetKind {.raises: [ValueError].} =
  ## Maps a morph type to the offset variant it must carry.
  requireValidEnum(morphType, "Morph type")
  case morphType
  of mtGroup:
    moGroup
  of mtVertex:
    moVertex
  of mtBone:
    moBone
  of mtUV, mtUVExt1, mtUVExt2, mtUVExt3, mtUVExt4:
    moUV
  of mtMaterial:
    moMaterial
  of mtFlip:
    moFlip
  of mtImpulse:
    moImpulse

func isPmx21Only*(morph: Morph): bool {.inline.} =
  ## Returns true if this morph requires PMX 2.1 (flip or impulse).
  morph != nil and morph.morphType in {mtFlip, mtImpulse}

proc `==`*(a, b: MorphOffset): bool =
  ## Compares two morph offsets for equality.
  if a.kind != b.kind:
    return false
  case a.kind
  of moGroup:
    a.group == b.group
  of moVertex:
    a.vertex == b.vertex
  of moBone:
    a.bone == b.bone
  of moUV:
    a.uv == b.uv
  of moMaterial:
    a.material == b.material
  of moFlip:
    a.flip == b.flip
  of moImpulse:
    a.impulse == b.impulse

proc `==`*(a, b: Morph): bool =
  ## Compares two morphs for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.panelType == b.panelType and
    a.morphType == b.morphType and a.offsetData == b.offsetData

proc copy*(obj: Morph): Morph =
  ## Returns a deep copy of the morph and its offsets.
  if isNil(obj):
    return nil
  Morph(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    panelType: obj.panelType,
    morphType: obj.morphType,
    offsetData: copySeq(obj.offsetData)
  )

proc isValid*(
  morph: Morph,
  vertexCount: int32,
  boneCount: int32,
  materialCount: int32,
  morphCount: int32,
  rigidBodyCount: int32
): bool =
  if not isValidOptionalCount(vertexCount) or not isValidOptionalCount(boneCount) or
      not isValidOptionalCount(materialCount) or not isValidOptionalCount(morphCount) or
      not isValidOptionalCount(rigidBodyCount):
    return false
  if morph == nil:
    return false
  try:
    requireValidEnum(morph.panelType, "Morph panel")
    requireValidEnum(morph.morphType, "Morph type")
    let expected = getExpectedMorphOffsetKind(morph.morphType)
    for offset in morph.offsetData:
      if offset.kind != expected:
        return false
      case offset.kind
      of moGroup:
        checkFinite(offset.group.influence, "Morph group influence")
        if offset.group.morphIndex < -1 or (morphCount >= 0 and offset.group.morphIndex >= morphCount):
          return false
      of moVertex:
        checkFinite(offset.vertex.translation, "Morph vertex translation")
        if offset.vertex.vertexIndex < 0 or (vertexCount >= 0 and offset.vertex.vertexIndex >= vertexCount):
          return false
      of moBone:
        checkFinite(offset.bone.translation, "Morph bone translation")
        checkFinite(offset.bone.rotation, "Morph bone rotation")
        if offset.bone.boneIndex < -1 or (boneCount >= 0 and offset.bone.boneIndex >= boneCount):
          return false
      of moUV:
        checkFinite(offset.uv.floats, "Morph UV values")
        if offset.uv.vertexIndex < 0 or (vertexCount >= 0 and offset.uv.vertexIndex >= vertexCount):
          return false
      of moMaterial:
        requireValidEnum(offset.material.blendMode, "Material morph blend mode")
        checkFinite(offset.material.diffuseColor, "Material morph diffuse")
        checkFinite(offset.material.specularColor, "Material morph specular")
        checkFinite(offset.material.specularStrength, "Material morph specular strength")
        checkFinite(offset.material.ambientColor, "Material morph ambient")
        checkFinite(offset.material.edgeColor, "Material morph edge")
        checkFinite(offset.material.edgeScale, "Material morph edge scale")
        checkFinite(offset.material.textureTint, "Material morph texture tint")
        checkFinite(offset.material.sphereTint, "Material morph sphere tint")
        checkFinite(offset.material.toonTint, "Material morph toon tint")
        if offset.material.materialIndex < -1 or
            (materialCount >= 0 and offset.material.materialIndex >= materialCount):
          return false
      of moFlip:
        checkFinite(offset.flip.influence, "Morph flip influence")
        if offset.flip.morphIndex < -1 or (morphCount >= 0 and offset.flip.morphIndex >= morphCount):
          return false
      of moImpulse:
        checkFinite(offset.impulse.movementSpeed, "Morph impulse movement")
        checkFinite(offset.impulse.rotationTorque, "Morph impulse torque")
        if offset.impulse.rigidBodyIndex < -1 or
            (rigidBodyCount >= 0 and offset.impulse.rigidBodyIndex >= rigidBodyCount):
          return false
    true
  except ValueError:
    false

proc repair*(
  morph: Morph,
  vertexCount = -1'i32,
  boneCount = -1'i32,
  materialCount = -1'i32,
  morphCount = -1'i32,
  rigidBodyCount = -1'i32
) {.raises: [ValueError].} =
  ## Drops bad offsets, clamps values, and fixes references.
  requireValidOptionalCount(vertexCount, "Morph vertexCount")
  requireValidOptionalCount(boneCount, "Morph boneCount")
  requireValidOptionalCount(materialCount, "Morph materialCount")
  requireValidOptionalCount(morphCount, "Morph morphCount")
  requireValidOptionalCount(rigidBodyCount, "Morph rigidBodyCount")
  if morph == nil:
    return
  if int(morph.panelType) < 0 or int(morph.panelType) > 4:
    morph.panelType = mptOther
  if int(morph.morphType) < 0 or int(morph.morphType) > 10:
    morph.morphType = mtVertex
  let expected = getExpectedMorphOffsetKind(morph.morphType)
  var writeIndex = 0
  for readIndex in 0 ..< morph.offsetData.len:
    var offset = morph.offsetData[readIndex]
    if offset.kind != expected:
      continue
    var keep = true
    case offset.kind
    of moGroup:
      offset.group.influence = repairFinite(offset.group.influence)
      if offset.group.morphIndex < -1 or (morphCount >= 0 and offset.group.morphIndex >= morphCount):
        offset.group.morphIndex = -1
    of moVertex:
      offset.vertex.translation = repairFinite(offset.vertex.translation)
      keep = offset.vertex.vertexIndex >= 0 and (vertexCount < 0 or offset.vertex.vertexIndex < vertexCount)
    of moBone:
      offset.bone.translation = repairFinite(offset.bone.translation)
      offset.bone.rotation = repairFinite(offset.bone.rotation)
      if offset.bone.boneIndex < -1 or (boneCount >= 0 and offset.bone.boneIndex >= boneCount):
        offset.bone.boneIndex = -1
    of moUV:
      offset.uv.floats = repairFinite(offset.uv.floats)
      keep = offset.uv.vertexIndex >= 0 and (vertexCount < 0 or offset.uv.vertexIndex < vertexCount)
    of moMaterial:
      if int(offset.material.blendMode) < 0 or int(offset.material.blendMode) > 1:
        offset.material.blendMode = mmbMultiply
      offset.material.diffuseColor = repairFinite(offset.material.diffuseColor)
      offset.material.specularColor = repairFinite(offset.material.specularColor)
      offset.material.specularStrength = repairFinite(offset.material.specularStrength)
      offset.material.ambientColor = repairFinite(offset.material.ambientColor)
      offset.material.edgeColor = repairFinite(offset.material.edgeColor)
      offset.material.edgeScale = repairFinite(offset.material.edgeScale)
      offset.material.textureTint = repairFinite(offset.material.textureTint)
      offset.material.sphereTint = repairFinite(offset.material.sphereTint)
      offset.material.toonTint = repairFinite(offset.material.toonTint)
      if offset.material.materialIndex < -1 or
          (materialCount >= 0 and offset.material.materialIndex >= materialCount):
        keep = false
    of moFlip:
      offset.flip.influence = repairFinite(offset.flip.influence)
      if offset.flip.morphIndex < -1 or (morphCount >= 0 and offset.flip.morphIndex >= morphCount):
        offset.flip.morphIndex = -1
    of moImpulse:
      offset.impulse.movementSpeed = repairFinite(offset.impulse.movementSpeed)
      offset.impulse.rotationTorque = repairFinite(offset.impulse.rotationTorque)
      if offset.impulse.rigidBodyIndex < -1 or
          (rigidBodyCount >= 0 and offset.impulse.rigidBodyIndex >= rigidBodyCount):
        offset.impulse.rigidBodyIndex = -1
    if keep:
      morph.offsetData[writeIndex] = offset
      inc writeIndex
  morph.offsetData.setLen(writeIndex)
