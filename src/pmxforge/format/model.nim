## PMX model container.
##
## Provides `PmxModel` with the complete element set, plus `copy`, comparison, and the in-place `repair` pass
## that normalizes a damaged model.

import ../core/vectors
import ../core/colors
import ./enums
import ./elements/all as elementTypes
import ./flags
import ./limits
import ./internal/preconditions
import ./internal/copy_helpers

type
  PmxModel* = ref object ## PMX model document containing all geometry, rigging, and physics data.
    version*: PmxVersion ## Format version (pmx20 or pmx21).
    nameJA*: string ## Japanese model name.
    nameEN*: string ## English / universal model name.
    commentsJA*: string ## Japanese description / comments.
    commentsEN*: string ## English description / comments.
    textEncoding*: TextEncoding ## Internal string encoding (UTF-8 or UTF-16LE).
    additionalUvCount*: int32 ## Number of extra UV channels per vertex (0 to 4).
    directory*: string ## Directory path for resolving relative texture files.
    vertices*: seq[Vertex] ## Vertex buffer.
    faces*: seq[Face] ## Triangle face list.
    textures*: seq[Texture] ## Texture file path table.
    materials*: seq[Material] ## Material and rendering settings.
    bones*: seq[Bone] ## Skeleton hierarchy and IK chains.
    morphs*: seq[Morph] ## Blend shape morphs.
    displayFrames*: seq[DisplaySlot] ## UI display groups for bones and morphs.
    rigidBodies*: seq[RigidBody] ## Bullet physics rigid bodies.
    joints*: seq[Joint] ## Physics constraint joints.
    softBodies*: seq[SoftBody] ## Soft body simulation records (PMX 2.1).

export vectors, colors, enums, elementTypes, flags

proc newPmxModel*(
  nameJA = "",
  version = pmx21,
  textEncoding = teUTF8,
  nameEN = nameJA,
  commentsJA = "",
  commentsEN = "",
  additionalUvCount = 0'i32,
  directory = "",
  vertices: seq[Vertex] = @[],
  faces: seq[Face] = @[],
  textures: seq[Texture] = @[],
  materials: seq[Material] = @[],
  bones: seq[Bone] = @[],
  morphs: seq[Morph] = @[],
  displayFrames: seq[DisplaySlot] = @[],
  rigidBodies: seq[RigidBody] = @[],
  joints: seq[Joint] = @[],
  softBodies: seq[SoftBody] = @[]
): PmxModel {.raises: [ValueError].} =
  ## Creates a new PMX model, deep-copying all provided elements.
  requireValidEnum(version, "PMX version")
  requireValidEnum(textEncoding, "Text encoding")
  if additionalUvCount < 0 or additionalUvCount > 4:
    raise newException(ValueError, "Additional UV count must be in the range [0, 4].")
  PmxModel(
    version: version,
    textEncoding: textEncoding,
    nameJA: nameJA,
    nameEN: nameEN,
    commentsJA: commentsJA,
    commentsEN: commentsEN,
    additionalUvCount: additionalUvCount,
    directory: directory,
    vertices: copyRefSeq(vertices),
    faces: copyRefSeq(faces),
    textures: copyRefSeq(textures),
    materials: copyRefSeq(materials),
    bones: copyRefSeq(bones),
    morphs: copyRefSeq(morphs),
    displayFrames: copyRefSeq(displayFrames),
    rigidBodies: copyRefSeq(rigidBodies),
    joints: copyRefSeq(joints),
    softBodies: copyRefSeq(softBodies)
  )

proc samePmxContent*(a, b: PmxModel): bool =
  ## Compares serializable model content, ignoring the runtime `directory` path.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.version == b.version and a.nameJA == b.nameJA and a.nameEN == b.nameEN and
    a.commentsJA == b.commentsJA and a.commentsEN == b.commentsEN and a.textEncoding == b.textEncoding and
    a.additionalUvCount == b.additionalUvCount and a.vertices == b.vertices and a.faces == b.faces and
    a.textures == b.textures and a.materials == b.materials and a.bones == b.bones and
    a.morphs == b.morphs and a.displayFrames == b.displayFrames and a.rigidBodies == b.rigidBodies and
    a.joints == b.joints and a.softBodies == b.softBodies

proc `==`*(a, b: PmxModel): bool =
  ## Compares models for full equality, including the `directory` field.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.directory == b.directory and a.samePmxContent(b)

proc copy*(obj: PmxModel): PmxModel =
  ## Returns an independent deep copy of the entire model.
  if isNil(obj):
    return nil
  PmxModel(
    version: obj.version,
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    commentsJA: copyString(obj.commentsJA),
    commentsEN: copyString(obj.commentsEN),
    textEncoding: obj.textEncoding,
    additionalUvCount: obj.additionalUvCount,
    directory: copyString(obj.directory),
    vertices: copyRefSeq(obj.vertices),
    faces: copyRefSeq(obj.faces),
    textures: copyRefSeq(obj.textures),
    materials: copyRefSeq(obj.materials),
    bones: copyRefSeq(obj.bones),
    morphs: copyRefSeq(obj.morphs),
    displayFrames: copyRefSeq(obj.displayFrames),
    rigidBodies: copyRefSeq(obj.rigidBodies),
    joints: copyRefSeq(obj.joints),
    softBodies: copyRefSeq(obj.softBodies)
  )

proc validateRepairPreconditions(target: PmxModel) {.raises: [ValueError].} =
  ## Rejects nil elements and oversized collections.
  template rejectNil(items: untyped, label: string) =
    ## Raises ValueError when an element is nil.
    for i, item in items:
      if item == nil:
        raise newException(ValueError, label & "[" & $i & "] is nil and cannot be repaired safely.")
  rejectNil(target.vertices, "Vertex")
  rejectNil(target.faces, "Face")
  rejectNil(target.textures, "Texture")
  rejectNil(target.materials, "Material")
  rejectNil(target.bones, "Bone")
  rejectNil(target.morphs, "Morph")
  rejectNil(target.displayFrames, "DisplaySlot")
  rejectNil(target.rigidBodies, "RigidBody")
  rejectNil(target.joints, "Joint")
  rejectNil(target.softBodies, "SoftBody")

  template checkRepairCount(items: untyped, label: string) =
    ## Raises ValueError when the collection is too large.
    checkElementCount(items.len, label)
  checkRepairCount(target.vertices, "Vertex")
  checkRepairCount(target.faces, "Face")
  checkRepairCount(target.textures, "Texture")
  checkRepairCount(target.materials, "Material")
  checkRepairCount(target.bones, "Bone")
  checkRepairCount(target.morphs, "Morph")
  checkRepairCount(target.displayFrames, "Display slot")
  checkRepairCount(target.rigidBodies, "Rigid body")
  checkRepairCount(target.joints, "Joint")
  checkRepairCount(target.softBodies, "Soft body")
  for i, bone in target.bones:
    checkRepairCount(bone.ik.links, "Bone[" & $i & "] IK link")
  for i, morph in target.morphs:
    checkRepairCount(morph.offsetData, "Morph[" & $i & "] offset")
  for i, slot in target.displayFrames:
    checkRepairCount(slot.frames, "DisplaySlot[" & $i & "] frame")
  for i, body in target.softBodies:
    checkRepairCount(body.anchorRigidBodies, "SoftBody[" & $i & "] anchor")
    checkRepairCount(body.vertexPins, "SoftBody[" & $i & "] vertex pin")

proc repairGlobals(target: PmxModel) =
  ## Fixes the version, the encoding, and the extra UV channel count. The count is raised
  ## when a morph or a material needs more channels.
  if int(target.version) < 0 or int(target.version) > 1:
    target.version = pmx21
  if int(target.textEncoding) < 0 or int(target.textEncoding) > 1:
    target.textEncoding = teUTF8
  target.additionalUvCount = max(0'i32, min(4'i32, target.additionalUvCount))

  for morph in target.morphs:
    if morph != nil and int(morph.morphType) >= int(mtUVExt1) and int(morph.morphType) <= int(mtUVExt4):
      case morph.morphType
      of mtUVExt1:
        target.additionalUvCount = max(target.additionalUvCount, 1'i32)
      of mtUVExt2:
        target.additionalUvCount = max(target.additionalUvCount, 2'i32)
      of mtUVExt3:
        target.additionalUvCount = max(target.additionalUvCount, 3'i32)
      of mtUVExt4:
        target.additionalUvCount = max(target.additionalUvCount, 4'i32)
      else:
        discard

  for material in target.materials:
    if material != nil and (material.flags.vertexColor or material.sphereBlendMode == sbmSubTexture):
      target.additionalUvCount = max(target.additionalUvCount, 1'i32)

proc repairMaterialFaces(target: PmxModel) {.raises: [ValueError].} =
  ## Drops faces with unusable vertex indices, then recounts each material `faceCount`.
  ## Texture references are repaired on the way.
  let vertexCount = int32(target.vertices.len)
  let textureCount = int32(target.textures.len)
  for material in target.materials:
    material.repair(textureCount)
  if target.materials.len == 0:
    target.faces = @[]
    return
  var kept = newSeqOfCap[Face](target.faces.len)
  var cursor = 0
  for materialIndex, material in target.materials:
    let declared = int(material.faceCount)
    var consumed = 0
    var owned = 0
    while cursor < target.faces.len and consumed < declared:
      let face = target.faces[cursor]
      inc cursor
      inc consumed
      face.repair(vertexCount)
      if face.isValid(vertexCount):
        kept.add(face)
        inc owned
    if materialIndex == target.materials.high:
      while cursor < target.faces.len:
        let face = target.faces[cursor]
        inc cursor
        face.repair(vertexCount)
        if face.isValid(vertexCount):
          kept.add(face)
          inc owned
    if owned > int(high(int32)):
      raise newException(ValueError, "Repaired material face count exceeds the int32 range.")
    material.faceCount = int32(owned)
  target.faces = kept

proc repairElements(target: PmxModel) {.raises: [ValueError].} =
  ## Repairs every element in place: vertices, faces, bones, morphs, display slots, rigid
  ## bodies, joints, and soft bodies.
  let boneCount = int32(target.bones.len)
  let vertexCount = int32(target.vertices.len)
  let materialCount = int32(target.materials.len)
  let morphCount = int32(target.morphs.len)
  let rigidBodyCount = int32(target.rigidBodies.len)

  for i in 0 ..< target.vertices.len:
    target.vertices[i].repair(boneCount, target.additionalUvCount)
  repairMaterialFaces(target)
  for i in 0 ..< target.bones.len:
    target.bones[i].repair(boneCount)
  for i in 0 ..< target.morphs.len:
    target.morphs[i].repair(vertexCount, boneCount, materialCount, morphCount, rigidBodyCount)
  for i in 0 ..< target.displayFrames.len:
    target.displayFrames[i].repair(boneCount, morphCount)
  for i in 0 ..< target.rigidBodies.len:
    target.rigidBodies[i].repair(boneCount)
  for i in 0 ..< target.joints.len:
    target.joints[i].repair(rigidBodyCount)
  for i in 0 ..< target.softBodies.len:
    target.softBodies[i].repair(materialCount, rigidBodyCount, vertexCount)

proc breakBoneCycles(target: PmxModel, inheritance: bool) =
  ## Breaks parent or inheritance cycles. The link that closes the cycle is cleared, so the
  ## bone ends up with no parent or no inheritance source.
  let count = target.bones.len
  var state = newSeq[int8](count)
  for start in 0 ..< count:
    if state[start] != 0:
      continue
    var path: seq[int] = @[]
    var current = start
    while current >= 0 and current < count and state[current] == 0:
      state[current] = 1
      path.add(current)
      current =
        if inheritance:
          (if target.bones[current].flags.inheritRotation or
              target.bones[current].flags.inheritTranslation:
           int(target.bones[current].inheritParentIndex)
           else: -1)
        else:
          int(target.bones[current].parentBoneIndex)

    if current >= 0 and current < count and state[current] == 1:
      let edgeOwner = path[^1]
      if inheritance:
        target.bones[edgeOwner].inheritParentIndex = -1
        target.bones[edgeOwner].flags.inheritRotation = false
        target.bones[edgeOwner].flags.inheritTranslation = false
      else:
        target.bones[edgeOwner].parentBoneIndex = -1
    for node in path:
      state[node] = 2

proc breakMorphCycles(target: PmxModel) =
  ## Breaks group morph cycles. Flip morphs are left alone: the format lets a flip
  ## reference itself or another flip.
  let morphCountForGraph = target.morphs.len
  var morphState = newSeq[int8](morphCountForGraph)
  var dropOffset = newSeq[seq[bool]](morphCountForGraph)
  for i, morph in target.morphs:
    dropOffset[i] = newSeq[bool](morph.offsetData.len)

  for start in 0 ..< morphCountForGraph:
    if morphState[start] != 0:
      continue
    type MorphFrame = tuple[node: int, nextEdge: int]
    var stack: seq[MorphFrame] = @[(start, 0)]
    morphState[start] = 1
    while stack.len > 0:
      let top = stack[^1]
      if top.nextEdge >= target.morphs[top.node].offsetData.len:
        morphState[top.node] = 2
        discard stack.pop()
        continue

      stack[^1].nextEdge = top.nextEdge + 1
      let edgeIndex = top.nextEdge
      let morph = target.morphs[top.node]
      let next =
        if morph.morphType == mtGroup:
          int(morph.offsetData[edgeIndex].group.morphIndex)
        else:
          -1
      if next < 0 or next >= morphCountForGraph:
        continue
      if morphState[next] == 0:
        morphState[next] = 1
        stack.add((next, 0))
      elif morphState[next] == 1:
        dropOffset[top.node][edgeIndex] = true

  for morphIndex, morph in target.morphs:
    var writeIndex = 0
    for readIndex in 0 ..< morph.offsetData.len:
      if not dropOffset[morphIndex][readIndex]:
        morph.offsetData[writeIndex] = morph.offsetData[readIndex]
        inc writeIndex
    morph.offsetData.setLen(writeIndex)

proc repair*(obj: PmxModel) {.raises: [ValueError].} =
  ## Repairs the model in place: clamps values, breaks cycles, and fixes references. It keeps
  ## the declared version, so PMX 2.1 data inside a 2.0 model still fails `validate`.
  if obj == nil:
    return
  validateRepairPreconditions(obj)
  repairGlobals(obj)
  repairElements(obj)
  breakBoneCycles(obj, false)
  breakBoneCycles(obj, true)
  breakMorphCycles(obj)
