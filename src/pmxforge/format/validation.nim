## Model validation.
##
## Provides `validate` for the strict semantic contract and `validateWireSafe` for the looser rule that a
## model can still be written to bytes.

import strformat
import ./model
import ./limits
import ./io/text_codec
import ./internal/preconditions

const MaxContextNameBytes = 48 ## Longest element name copied into a diagnostic label.

func contextName(name: string): string =
  ## Returns a name suffix for diagnostic labels, empty for very long names.
  if name.len == 0 or name.len > MaxContextNameBytes:
    ""
  else:
    " '" & name & "'"

proc validateEnumFields(model: PmxModel) {.raises: [ValueError].} =
  ## Rejects enum fields whose ordinal is not defined by the format.
  requireValidEnum(model.version, "Model.version")
  requireValidEnum(model.textEncoding, "Model.textEncoding")
  for i, material in model.materials:
    requireValidEnum(material.sphereBlendMode, fmt"Material[{i}].sphereBlendMode")
  for i, morph in model.morphs:
    requireValidEnum(morph.panelType, fmt"Morph[{i}].panelType")
    requireValidEnum(morph.morphType, fmt"Morph[{i}].morphType")
    for j, offset in morph.offsetData:
      requireValidEnum(offset.kind, fmt"Morph[{i}].offsetData[{j}].kind")
      if offset.kind == moMaterial:
        requireValidEnum(offset.material.blendMode, fmt"Morph[{i}].offsetData[{j}].material.blendMode")
  for i, slot in model.displayFrames:
    for j, frame in slot.frames:
      requireValidEnum(frame.frameType, fmt"DisplaySlot[{i}].frames[{j}].frameType")
  for i, body in model.rigidBodies:
    requireValidEnum(body.shape, fmt"RigidBody[{i}].shape")
    requireValidEnum(body.physicsMode, fmt"RigidBody[{i}].physicsMode")
  for i, joint in model.joints:
    requireValidEnum(joint.jointType, fmt"Joint[{i}].jointType")
  for i, softBody in model.softBodies:
    requireValidEnum(softBody.shape, fmt"SoftBody[{i}].shape")
    requireValidEnum(softBody.aerodynamicsModel, fmt"SoftBody[{i}].aerodynamicsModel")

proc validateTextValue(
  text: string,
  encoding: TextEncoding,
  label: string,
  maxBytes: int
) {.raises: [ValueError].} =
  ## Checks one string for length and encoding, naming the field on failure.
  try:
    case encoding
    of teUTF8:
      if text.len > maxBytes:
        raise newException(ValueError, fmt"{label} exceeds {maxBytes} encoded bytes.")
      validateUtf8(text)
    of teUTF16LE:
      if int64(text.len) > int64(maxBytes) * 2'i64:
        raise newException(ValueError, fmt"{label} is too large to encode within {maxBytes} bytes.")
      discard utf16LeByteLength(text, maxBytes)
  except ValueError as exc:
    raise newException(ValueError, fmt"{label} is not encodable: {exc.msg}")

proc validateTexts(model: PmxModel, maxBytes = MaxStringBytes) {.raises: [ValueError].} =
  ## Checks every text field in the model for length and encoding.
  if maxBytes < 0 or int64(maxBytes) > int64(MaxPmxStringBytes):
    raise newException(ValueError, fmt"String byte limit {maxBytes} is outside [0, {MaxPmxStringBytes}].")
  let encoding = model.textEncoding
  validateTextValue(model.nameJA, encoding, "Model.nameJA", maxBytes)
  validateTextValue(model.nameEN, encoding, "Model.nameEN", maxBytes)
  validateTextValue(model.commentsJA, encoding, "Model.commentsJA", maxBytes)
  validateTextValue(model.commentsEN, encoding, "Model.commentsEN", maxBytes)
  for i, texture in model.textures:
    validateTextValue(texture.path, encoding, fmt"Texture[{i}].path", maxBytes)
  for i, material in model.materials:
    validateTextValue(material.nameJA, encoding, fmt"Material[{i}].nameJA", maxBytes)
    validateTextValue(material.nameEN, encoding, fmt"Material[{i}].nameEN", maxBytes)
    validateTextValue(material.comment, encoding, fmt"Material[{i}].comment", maxBytes)
  for i, bone in model.bones:
    validateTextValue(bone.nameJA, encoding, fmt"Bone[{i}].nameJA", maxBytes)
    validateTextValue(bone.nameEN, encoding, fmt"Bone[{i}].nameEN", maxBytes)
  for i, morph in model.morphs:
    validateTextValue(morph.nameJA, encoding, fmt"Morph[{i}].nameJA", maxBytes)
    validateTextValue(morph.nameEN, encoding, fmt"Morph[{i}].nameEN", maxBytes)
  for i, slot in model.displayFrames:
    validateTextValue(slot.nameJA, encoding, fmt"DisplaySlot[{i}].nameJA", maxBytes)
    validateTextValue(slot.nameEN, encoding, fmt"DisplaySlot[{i}].nameEN", maxBytes)
  for i, body in model.rigidBodies:
    validateTextValue(body.nameJA, encoding, fmt"RigidBody[{i}].nameJA", maxBytes)
    validateTextValue(body.nameEN, encoding, fmt"RigidBody[{i}].nameEN", maxBytes)
  for i, joint in model.joints:
    validateTextValue(joint.nameJA, encoding, fmt"Joint[{i}].nameJA", maxBytes)
    validateTextValue(joint.nameEN, encoding, fmt"Joint[{i}].nameEN", maxBytes)
  for i, softBody in model.softBodies:
    validateTextValue(softBody.nameJA, encoding, fmt"SoftBody[{i}].nameJA", maxBytes)
    validateTextValue(softBody.nameEN, encoding, fmt"SoftBody[{i}].nameEN", maxBytes)

template checkIndex(idx, maxExclusive: int32, label: untyped) =
  ## Checks a reference; -1 is null, others must be in range. The label only evaluates on
  ## failure, so callers can pass `fmt"..."` inside per-element loops.
  if idx != -1:
    if maxExclusive <= 0:
      raise newException(ValueError, label & " index " & $idx & " is out of range; collection is empty.")
    if idx < 0 or idx >= maxExclusive:
      let upper = maxExclusive - 1
      raise newException(ValueError, label & " index " & $idx & " is out of range [0, " & $upper & "].")

template checkVertexIndex(idx, vertexCount: int32, label: untyped) =
  ## Checks a vertex index; negatives are never valid.
  if vertexCount <= 0:
    raise newException(ValueError, label & " vertex index " & $idx & " is out of range; collection is empty.")
  if idx < 0 or idx >= vertexCount:
    let upper = vertexCount - 1
    raise newException(ValueError, label & " vertex index " & $idx & " is out of range [0, " & $upper & "].")

proc validateNoNilRefs(model: PmxModel) {.raises: [ValueError].} =
  ## Rejects nil elements before their fields are accessed.
  if model == nil:
    raise newException(ValueError, "PmxModel is nil.")
  template check(items: untyped, label: string) =
    ## Raises ValueError if any item in the sequence is nil.
    for i, item in items:
      if item == nil:
        raise newException(ValueError, label & "[" & $i & "] is nil.")
  check(model.vertices, "Vertex")
  check(model.faces, "Face")
  check(model.textures, "Texture")
  check(model.materials, "Material")
  check(model.bones, "Bone")
  check(model.morphs, "Morph")
  check(model.displayFrames, "DisplaySlot")
  check(model.rigidBodies, "RigidBody")
  check(model.joints, "Joint")
  check(model.softBodies, "SoftBody")

proc validateElementCounts(model: PmxModel) {.raises: [ValueError].} =
  ## Checks that all collection counts fit within MaxElementCount.
  checkElementCount(model.vertices.len, "Vertex")
  checkElementCount(model.faces.len, "Face")
  checkElementCount(model.textures.len, "Texture")
  checkElementCount(model.materials.len, "Material")
  checkElementCount(model.bones.len, "Bone")
  checkElementCount(model.morphs.len, "Morph")
  checkElementCount(model.displayFrames.len, "Display slot")
  checkElementCount(model.rigidBodies.len, "Rigid body")
  checkElementCount(model.joints.len, "Joint")
  checkElementCount(model.softBodies.len, "Soft body")
  for i, bone in model.bones:
    if bone != nil:
      checkElementCount(bone.ik.links.len, fmt"Bone[{i}] IK link")
  for i, morph in model.morphs:
    if morph != nil:
      checkElementCount(morph.offsetData.len, fmt"Morph[{i}] offset")
  for i, slot in model.displayFrames:
    if slot != nil:
      checkElementCount(slot.frames.len, fmt"DisplaySlot[{i}] frame")
  for i, softBody in model.softBodies:
    if softBody != nil:
      checkElementCount(softBody.anchorRigidBodies.len, fmt"SoftBody[{i}] anchor")
      checkElementCount(softBody.vertexPins.len, fmt"SoftBody[{i}] vertex pin")

proc validateRawTextStorage(model: PmxModel, maxBytes: int) {.raises: [ValueError].} =
  ## Bounds the raw text bytes before a repair copy rewrites the encoding.
  template check(value, fieldLabel: untyped) =
    ## Rejects a string over the byte budget.
    if value.len > maxBytes:
      raise newException(ValueError, fieldLabel & " is too large to encode within " & $maxBytes & " bytes.")
  check(model.nameJA, "Model.nameJA")
  check(model.nameEN, "Model.nameEN")
  check(model.commentsJA, "Model.commentsJA")
  check(model.commentsEN, "Model.commentsEN")
  for i, texture in model.textures:
    check(texture.path, fmt"Texture[{i}].path")
  for i, material in model.materials:
    check(material.nameJA, fmt"Material[{i}].nameJA")
    check(material.nameEN, fmt"Material[{i}].nameEN")
    check(material.comment, fmt"Material[{i}].comment")
  for i, bone in model.bones:
    check(bone.nameJA, fmt"Bone[{i}].nameJA")
    check(bone.nameEN, fmt"Bone[{i}].nameEN")
  for i, morph in model.morphs:
    check(morph.nameJA, fmt"Morph[{i}].nameJA")
    check(morph.nameEN, fmt"Morph[{i}].nameEN")
  for i, slot in model.displayFrames:
    check(slot.nameJA, fmt"DisplaySlot[{i}].nameJA")
    check(slot.nameEN, fmt"DisplaySlot[{i}].nameEN")
  for i, body in model.rigidBodies:
    check(body.nameJA, fmt"RigidBody[{i}].nameJA")
    check(body.nameEN, fmt"RigidBody[{i}].nameEN")
  for i, joint in model.joints:
    check(joint.nameJA, fmt"Joint[{i}].nameJA")
    check(joint.nameEN, fmt"Joint[{i}].nameEN")
  for i, softBody in model.softBodies:
    check(softBody.nameJA, fmt"SoftBody[{i}].nameJA")
    check(softBody.nameEN, fmt"SoftBody[{i}].nameEN")

proc validateWritePreparation*(model: PmxModel, maxStringBytes = MaxStringBytes) {.raises: [ValueError].} =
  ## Checks everything a writer needs before it copies or repairs the model. Defects
  ## that `repair` normalizes are allowed here.
  if model == nil:
    raise newException(ValueError, "PmxModel is nil.")
  if maxStringBytes < 0 or int64(maxStringBytes) > int64(MaxPmxStringBytes):
    raise newException(
      ValueError, fmt"String byte limit {maxStringBytes} is outside [0, {MaxPmxStringBytes}].")
  validateElementCounts(model)
  validateNoNilRefs(model)
  if int(model.textEncoding) in int(teUTF16LE)..int(teUTF8):
    validateTexts(model, maxStringBytes)
  else:
    validateRawTextStorage(model, maxStringBytes)

proc validateElementValues(model: PmxModel) {.raises: [ValueError].} =
  ## Validates scalar ranges and vector components for every element.
  if model.additionalUvCount < 0 or model.additionalUvCount > 4:
    raise newException(ValueError, "Additional UV count must be in [0, 4].")

  for i, vertex in model.vertices:
    template ctx: string = "Vertex[" & $i & "]"
    if vertex.additionalUv.len > 4:
      raise newException(
        ValueError, fmt"{ctx} has {vertex.additionalUv.len} additional UV sets; the PMX maximum is 4.")
    checkFinite(vertex.position, ctx & ".position")
    checkFinite(vertex.normal, ctx & ".normal")
    checkFinite(vertex.uv, ctx & ".uv")
    for j, uv in vertex.additionalUv:
      checkFinite(uv, fmt"{ctx}.additionalUv[{j}]")
    checkNonNegativeFinite(vertex.edgeScale, ctx & ".edgeScale")
    validateDeform(vertex.weightDeform)

  for i, mat in model.materials:
    template ctx: string = "Material[" & $i & "]" & contextName(mat.nameJA)
    checkFinite(mat.diffuseColor, ctx & ".diffuseColor")
    checkUnitRange(mat.alpha, ctx & ".alpha")
    checkFinite(mat.specularColor, ctx & ".specularColor")
    checkNonNegativeFinite(mat.specularStrength, ctx & ".specularStrength")
    checkFinite(mat.ambientColor, ctx & ".ambientColor")
    checkFinite(mat.edgeColor, ctx & ".edgeColor")
    checkNonNegativeFinite(mat.edgeScale, ctx & ".edgeScale")
    if mat.internalToon and (mat.toonTextureIndex < 0 or mat.toonTextureIndex > 9):
      raise newException(ValueError, fmt"{ctx}.toonTextureIndex must be in [0, 9].")

  for i, bone in model.bones:
    template ctx: string = "Bone[" & $i & "]" & contextName(bone.nameJA)
    if bone.layer < 0:
      raise newException(ValueError, fmt"{ctx}.layer must be non-negative.")
    checkFinite(bone.position, ctx & ".position")
    if not bone.flags.connection:
      checkFinite(bone.tailPosition, ctx & ".tailPosition")
    if bone.flags.inheritRotation or bone.flags.inheritTranslation:
      checkFinite(bone.inheritParentInfluence, ctx & ".inheritParentInfluence")
    if bone.flags.fixedAxis:
      checkFinite(bone.fixedAxisDirection, ctx & ".fixedAxisDirection")
    if bone.flags.localCoordinate:
      checkFinite(bone.localXVector, ctx & ".localXVector")
      checkFinite(bone.localZVector, ctx & ".localZVector")
    if bone.flags.ik:
      if bone.ik.loopCount <= 0:
        raise newException(ValueError, fmt"{ctx}.ik.loopCount must be greater than zero.")
      checkNonNegativeFinite(bone.ik.limitAngle, ctx & ".ik.limitAngle")
      for j, link in bone.ik.links:
        if link.hasLimits:
          checkFinite(link.limitMin, fmt"{ctx}.ik.links[{j}].limitMin")
          checkFinite(link.limitMax, fmt"{ctx}.ik.links[{j}].limitMax")
          if link.limitMin.x > link.limitMax.x or link.limitMin.y > link.limitMax.y or
              link.limitMin.z > link.limitMax.z:
            raise newException(ValueError, fmt"{ctx}.ik.links[{j}] minimum must be <= maximum.")

  for i, morph in model.morphs:
    template ctx: string = "Morph[" & $i & "]" & contextName(morph.nameJA)
    for j, offset in morph.offsetData:
      case offset.kind
      of moGroup:
        checkFinite(offset.group.influence, fmt"{ctx}.offset[{j}].influence")
      of moVertex:
        checkFinite(offset.vertex.translation, fmt"{ctx}.offset[{j}].translation")
      of moBone:
        checkFinite(offset.bone.translation, fmt"{ctx}.offset[{j}].translation")
        checkFinite(offset.bone.rotation, fmt"{ctx}.offset[{j}].rotation")
      of moUV:
        checkFinite(offset.uv.floats, fmt"{ctx}.offset[{j}].floats")
      of moMaterial:
        checkFinite(offset.material.diffuseColor, fmt"{ctx}.offset[{j}].diffuseColor")
        checkFinite(offset.material.specularColor, fmt"{ctx}.offset[{j}].specularColor")
        checkFinite(offset.material.specularStrength, fmt"{ctx}.offset[{j}].specularStrength")
        checkFinite(offset.material.ambientColor, fmt"{ctx}.offset[{j}].ambientColor")
        checkFinite(offset.material.edgeColor, fmt"{ctx}.offset[{j}].edgeColor")
        checkFinite(offset.material.edgeScale, fmt"{ctx}.offset[{j}].edgeScale")
        checkFinite(offset.material.textureTint, fmt"{ctx}.offset[{j}].textureTint")
        checkFinite(offset.material.sphereTint, fmt"{ctx}.offset[{j}].sphereTint")
        checkFinite(offset.material.toonTint, fmt"{ctx}.offset[{j}].toonTint")
      of moFlip:
        checkFinite(offset.flip.influence, fmt"{ctx}.offset[{j}].influence")
      of moImpulse:
        checkFinite(offset.impulse.movementSpeed, fmt"{ctx}.offset[{j}].movementSpeed")
        checkFinite(offset.impulse.rotationTorque, fmt"{ctx}.offset[{j}].rotationTorque")

  for i, body in model.rigidBodies:
    template ctx: string = "RigidBody[" & $i & "]" & contextName(body.nameJA)
    if body.groupId < 1 or body.groupId > 16:
      raise newException(ValueError, fmt"{ctx}.groupId must be in [1, 16].")
    checkFinite(body.shapeSize, ctx & ".shapeSize")
    if body.shapeSize.x < 0 or body.shapeSize.y < 0 or body.shapeSize.z < 0:
      raise newException(ValueError, fmt"{ctx}.shapeSize must be non-negative.")
    checkFinite(body.shapePosition, ctx & ".shapePosition")
    checkFinite(body.shapeRotation, ctx & ".shapeRotation")
    checkNonNegativeFinite(body.mass, ctx & ".mass")
    checkNonNegativeFinite(body.moveAttenuation, ctx & ".moveAttenuation")
    checkNonNegativeFinite(body.rotationDamping, ctx & ".rotationDamping")
    checkNonNegativeFinite(body.repulsion, ctx & ".repulsion")
    checkNonNegativeFinite(body.frictionForce, ctx & ".frictionForce")

  for i, sb in model.softBodies:
    template ctx: string = "SoftBody[" & $i & "]" & contextName(sb.nameJA)
    if sb.groupId < 1 or sb.groupId > 16:
      raise newException(ValueError, fmt"{ctx}.groupId must be in [1, 16].")
    if sb.bLinkCreateDistance < 0:
      raise newException(ValueError, fmt"{ctx}.bLinkCreateDistance must be non-negative.")
    if sb.numberOfClusters < 0:
      raise newException(ValueError, fmt"{ctx}.numberOfClusters must be non-negative.")
    for field in
      [
        ("iteration.vIt", sb.iteration.vIt),
        ("iteration.pIt", sb.iteration.pIt),
        ("iteration.dIt", sb.iteration.dIt),
        ("iteration.cIt", sb.iteration.cIt)
      ]:
      if field[1] < 0:
        raise newException(ValueError, fmt"{ctx}.{field[0]} must be non-negative.")
    checkNonNegativeFinite(sb.totalMass, ctx & ".totalMass")
    checkNonNegativeFinite(sb.collisionMargin, ctx & ".collisionMargin")
    for field in
      [
        ("config.vcf", sb.config.vcf),
        ("config.dp", sb.config.dp),
        ("config.dg", sb.config.dg),
        ("config.lf", sb.config.lf),
        ("config.pr", sb.config.pr),
        ("config.vc", sb.config.vc),
        ("config.df", sb.config.df),
        ("config.mt", sb.config.mt),
        ("config.chr", sb.config.chr),
        ("config.khr", sb.config.khr),
        ("config.shr", sb.config.`shr`),
        ("config.ahr", sb.config.ahr),
        ("cluster.srhrCl", sb.cluster.srhrCl),
        ("cluster.skhrCl", sb.cluster.skhrCl),
        ("cluster.sshrCl", sb.cluster.sshrCl),
        ("cluster.srSpltCl", sb.cluster.srSpltCl),
        ("cluster.skSpltCl", sb.cluster.skSpltCl),
        ("cluster.ssSpltCl", sb.cluster.ssSpltCl)
      ]:
      checkFinite(field[1], fmt"{ctx}.{field[0]}")
    checkNonNegativeFinite(sb.material.lst, ctx & ".material.lst")
    checkNonNegativeFinite(sb.material.ast, ctx & ".material.ast")
    checkNonNegativeFinite(sb.material.vst, ctx & ".material.vst")

  for i, joint in model.joints:
    template ctx: string = "Joint[" & $i & "]" & contextName(joint.nameJA)
    checkFinite(joint.position, ctx & ".position")
    checkFinite(joint.rotation, ctx & ".rotation")
    checkFinite(joint.positionMinimum, ctx & ".positionMinimum")
    checkFinite(joint.positionMaximum, ctx & ".positionMaximum")
    checkFinite(joint.rotationMinimum, ctx & ".rotationMinimum")
    checkFinite(joint.rotationMaximum, ctx & ".rotationMaximum")
    checkFinite(joint.positionSpring, ctx & ".positionSpring")
    checkFinite(joint.rotationSpring, ctx & ".rotationSpring")
    if not joint.limitOrderIsValid:
      raise newException(
        ValueError,
        fmt"{ctx}: minimum must be <= maximum on the limit components that {joint.jointType} uses.")

proc validateMaterialFaceCounts(model: PmxModel) {.raises: [ValueError].} =
  ## Checks that material face ranges cover the model's faces exactly.
  let hasMaterials = model.materials.len > 0
  let hasFaces = model.faces.len > 0
  let hasVertices = model.vertices.len > 0

  if hasFaces and (not hasMaterials or not hasVertices):
    raise newException(ValueError, "Model has faces but is missing materials or vertices.")

  if hasMaterials:
    var totalMaterialFaces = 0'i64
    for mat in model.materials:
      if mat.faceCount < 0:
        raise newException(ValueError, fmt"Material '{mat.nameJA}'. faceCount is negative ({mat.faceCount}).")
      totalMaterialFaces += int64(mat.faceCount)
      if totalMaterialFaces > int64(high(int32)):
        raise newException(ValueError, "Material faceCount sum exceeds int32 range.")
    if totalMaterialFaces != int64(model.faces.len):
      raise newException(
        ValueError,
        fmt"Material faceCount sum {totalMaterialFaces} does not match total faces {model.faces.len}.")

func isPmx21Only*(model: PmxModel): bool =
  ## Returns true if the model uses any PMX 2.1-only feature.
  if model == nil:
    return false
  if model.softBodies.len > 0:
    return true
  for vertex in model.vertices:
    if vertex != nil and vertex.weightDeform.isPmx21Only:
      return true
  for morph in model.morphs:
    if morph != nil and morph.isPmx21Only:
      return true
  for material in model.materials:
    if material != nil and
        (material.flags.vertexColor or material.flags.pointDraw or material.flags.lineDraw):
      return true
  for joint in model.joints:
    if joint != nil and joint.isPmx21Only:
      return true
  false

proc validateVersionCompatibility(model: PmxModel) {.raises: [ValueError].} =
  ## Checks that a PMX 2.0 target does not contain PMX 2.1-only features.
  if model.version != pmx20:
    return
  if model.softBodies.len > 0:
    raise newException(ValueError, "PMX 2.0 does not support soft bodies.")
  for vertex in model.vertices:
    if vertex.weightDeform.kind == dkQDEF:
      raise newException(ValueError, "PMX 2.0 does not support QDEF deform data.")
  for morph in model.morphs:
    if morph.morphType in {mtFlip, mtImpulse}:
      raise newException(ValueError, fmt"PMX 2.0 does not support {morph.morphType} morphs.")
  for material in model.materials:
    if (material.flags.vertexColor or material.flags.pointDraw or material.flags.lineDraw):
      raise newException(ValueError, "PMX 2.0 does not support vertex-color, point, or line material flags.")
  for joint in model.joints:
    if joint.jointType != jtSpring6DOF:
      raise newException(ValueError, fmt"PMX 2.0 does not support joint type {joint.jointType}.")

proc validateVertexDeformRefs(vertex: Vertex, boneCount: int32, vertexIndex: int) {.raises: [ValueError].} =
  ## Checks that a vertex deform references an existing bone. The label is a template so
  ## the per-vertex formatting only happens when a check fails.
  template label: string = "Vertex[" & $vertexIndex & "].weightDeform"
  case vertex.weightDeform.kind
  of dkBDEF1:
    checkIndex(vertex.weightDeform.bdef1.boneIndex1, boneCount, label & ".bdef1.boneIndex1")
  of dkBDEF2:
    checkIndex(vertex.weightDeform.bdef2.boneIndex1, boneCount, label & ".bdef2.boneIndex1")
    checkIndex(vertex.weightDeform.bdef2.boneIndex2, boneCount, label & ".bdef2.boneIndex2")
  of dkBDEF4:
    checkIndex(vertex.weightDeform.bdef4.boneIndex1, boneCount, label & ".bdef4.boneIndex1")
    checkIndex(vertex.weightDeform.bdef4.boneIndex2, boneCount, label & ".bdef4.boneIndex2")
    checkIndex(vertex.weightDeform.bdef4.boneIndex3, boneCount, label & ".bdef4.boneIndex3")
    checkIndex(vertex.weightDeform.bdef4.boneIndex4, boneCount, label & ".bdef4.boneIndex4")
  of dkSDEF:
    checkIndex(vertex.weightDeform.sdef.boneIndex1, boneCount, label & ".sdef.boneIndex1")
    checkIndex(vertex.weightDeform.sdef.boneIndex2, boneCount, label & ".sdef.boneIndex2")
  of dkQDEF:
    checkIndex(vertex.weightDeform.qdef.boneIndex1, boneCount, label & ".qdef.boneIndex1")
    checkIndex(vertex.weightDeform.qdef.boneIndex2, boneCount, label & ".qdef.boneIndex2")
    checkIndex(vertex.weightDeform.qdef.boneIndex3, boneCount, label & ".qdef.boneIndex3")
    checkIndex(vertex.weightDeform.qdef.boneIndex4, boneCount, label & ".qdef.boneIndex4")

proc detectBoneCycle(model: PmxModel, inheritance: bool): int =
  ## Returns the index of a bone caught in a parent or inheritance cycle, or -1.
  let n = model.bones.len
  if n == 0:
    return -1
  var state = newSeq[int8](n)
  template parentOf(index: int): int =
    ## Returns the parent or inheritance target of the bone at `index`.
    (if inheritance:
      (if model.bones[index].flags.inheritRotation or
          model.bones[index].flags.inheritTranslation:
        int(model.bones[index].inheritParentIndex)
      else: -1)
    else: int(model.bones[index].parentBoneIndex))
  for i in 0 ..< n:
    if state[i] != 0:
      continue
    var cur = i
    while cur >= 0 and cur < n:
      if state[cur] == 1:
        return cur
      if state[cur] == 2:
        break
      state[cur] = 1
      cur = parentOf(cur)
    cur = i
    while cur >= 0 and cur < n:
      if state[cur] == 2:
        break
      state[cur] = 2
      cur = parentOf(cur)
  return -1

proc detectMorphGraphCycle(model: PmxModel): int =
  ## Returns the index of the first morph caught in a cycle, or -1.
  let n = model.morphs.len
  const white = 0'i8
  const gray = 1'i8
  const black = 2'i8
  var color = newSeq[int8](n)
  for start in 0 ..< n:
    if color[start] != white:
      continue
    var stack: seq[tuple[node: int32, nextEdge: int]] = @[(int32(start), 0)]
    color[start] = gray
    while stack.len > 0:
      let top = stack[^1]
      let morph = model.morphs[top.node]
      let edgeCount = if morph.morphType == mtGroup: morph.offsetData.len else: 0
      if top.nextEdge < edgeCount:
        let offset = morph.offsetData[top.nextEdge]
        let next = offset.group.morphIndex
        stack[^1].nextEdge = top.nextEdge + 1
        if next < 0 or next >= n:
          continue
        if color[next] == white:
          color[next] = gray
          stack.add (next, 0)
        elif color[next] == gray:
          return int(next)
      else:
        color[top.node] = black
        discard stack.pop()
  -1

proc validateCrossRefs(model: PmxModel) {.raises: [ValueError].} =
  ## Raises ValueError for the first reference outside the model.
  let vLen = int32(model.vertices.len)
  let tLen = int32(model.textures.len)
  let bLen = int32(model.bones.len)
  let mLen = int32(model.morphs.len)
  let matLen = int32(model.materials.len)
  let rbLen = int32(model.rigidBodies.len)

  for i, vertex in model.vertices:
    if int32(vertex.additionalUv.len) != model.additionalUvCount:
      raise newException(
        ValueError,
        fmt"Vertex[{i}] has {vertex.additionalUv.len} additional UV sets; model.additionalUvCount requires exactly {model.additionalUvCount}."
      )
    validateVertexDeformRefs(vertex, bLen, i)

  for i, face in model.faces:
    checkVertexIndex(face.vertexIndex1, vLen, fmt"Face[{i}].vertexIndex1")
    checkVertexIndex(face.vertexIndex2, vLen, fmt"Face[{i}].vertexIndex2")
    checkVertexIndex(face.vertexIndex3, vLen, fmt"Face[{i}].vertexIndex3")

  for i, mat in model.materials:
    template ctx: string = "Material[" & $i & "]" & contextName(mat.nameJA)
    checkIndex(mat.textureIndex, tLen, fmt"{ctx}: textureIndex")
    checkIndex(mat.sphereTextureIndex, tLen, fmt"{ctx}: sphereTextureIndex")
    if not mat.internalToon:
      checkIndex(mat.toonTextureIndex, tLen, fmt"{ctx}: toonTextureIndex (shared)")
    if mat.flags.vertexColor and model.additionalUvCount < 1:
      raise newException(
        ValueError, fmt"{ctx}: vertex-color rendering requires at least one additional UV channel.")
    if mat.sphereBlendMode == sbmSubTexture and model.additionalUvCount < 1:
      raise newException(
        ValueError, fmt"{ctx}: sub-texture sphere mapping requires at least one additional UV channel.")

  for i, bone in model.bones:
    template ctx: string = "Bone[" & $i & "]" & contextName(bone.nameJA)
    checkIndex(bone.parentBoneIndex, bLen, fmt"{ctx}: parentBoneIndex")
    if bone.flags.connection:
      checkIndex(bone.tailIndex, bLen, fmt"{ctx}: tailIndex")
    if bone.flags.inheritRotation or bone.flags.inheritTranslation:
      checkIndex(bone.inheritParentIndex, bLen, fmt"{ctx}: inheritParentIndex")
    if bone.flags.ik:
      checkIndex(bone.ik.targetIndex, bLen, fmt"{ctx}: IK targetIndex")
      for j, link in bone.ik.links:
        checkIndex(link.boneIndex, bLen, fmt"{ctx}: IK link[{j}] boneIndex")

  if bLen > 0:
    let parentCycleNode = detectBoneCycle(model, false)
    if parentCycleNode >= 0:
      raise newException(
        ValueError,
        fmt"Bone[{parentCycleNode}] '{model.bones[parentCycleNode].nameJA}' participates in a parent bone cycle."
      )

    let inheritCycleNode = detectBoneCycle(model, true)
    if inheritCycleNode >= 0:
      raise newException(
        ValueError,
        fmt"Bone[{inheritCycleNode}] '{model.bones[inheritCycleNode].nameJA}' participates in an inheritance cycle."
      )

  for i, morph in model.morphs:
    template ctx: string = "Morph[" & $i & "]" & contextName(morph.nameJA)
    let requiredAdditionalUv =
      case morph.morphType
      of mtUVExt1:
        1'i32
      of mtUVExt2:
        2'i32
      of mtUVExt3:
        3'i32
      of mtUVExt4:
        4'i32
      else:
        0'i32
    if requiredAdditionalUv > model.additionalUvCount:
      raise newException(
        ValueError,
        fmt"{ctx}: {morph.morphType} requires {requiredAdditionalUv} additional UV channels, but the model declares {model.additionalUvCount}."
      )
    let expectedKind = getExpectedMorphOffsetKind(morph.morphType)
    for j, o in morph.offsetData:
      if o.kind != expectedKind:
        raise newException(
          ValueError, fmt"{ctx}: offset[{j}] has kind '{o.kind}', expected '{expectedKind}'.")

    case morph.morphType
    of mtVertex:
      for j, o in morph.offsetData:
        checkVertexIndex(o.vertex.vertexIndex, vLen, fmt"{ctx}: vertexOffset[{j}]")
    of mtUV, mtUVExt1, mtUVExt2, mtUVExt3, mtUVExt4:
      for j, o in morph.offsetData:
        checkVertexIndex(o.uv.vertexIndex, vLen, fmt"{ctx}: uvOffset[{j}]")
    of mtBone:
      for j, o in morph.offsetData:
        checkIndex(o.bone.boneIndex, bLen, fmt"{ctx}: boneOffset[{j}].boneIndex")
    of mtMaterial:
      for j, o in morph.offsetData:
        if o.material.materialIndex != -1:
          checkIndex(o.material.materialIndex, matLen, fmt"{ctx}: materialOffset[{j}].materialIndex")
    of mtGroup:
      for j, o in morph.offsetData:
        checkIndex(o.group.morphIndex, mLen, fmt"{ctx}: groupOffset[{j}].morphIndex")
        if o.group.morphIndex == int32(i):
          raise newException(ValueError, fmt"{ctx}: groupOffset[{j}].morphIndex references itself.")
    of mtFlip:
      for j, o in morph.offsetData:
        checkIndex(o.flip.morphIndex, mLen, fmt"{ctx}: flipOffset[{j}].morphIndex")
    of mtImpulse:
      for j, o in morph.offsetData:
        checkIndex(o.impulse.rigidBodyIndex, rbLen, fmt"{ctx}: impulseOffset[{j}].rigidBodyIndex")

  if mLen > 0:
    let cycleNode = detectMorphGraphCycle(model)
    if cycleNode >= 0:
      raise newException(
        ValueError,
        fmt"Morph[{cycleNode}] '{model.morphs[cycleNode].nameJA}' participates in a group morph reference cycle."
      )

  for i, slot in model.displayFrames:
    template ctx: string = "DisplaySlot[" & $i & "]" & contextName(slot.nameJA)
    for j, frame in slot.frames:
      case frame.frameType
      of dftBone:
        checkIndex(frame.targetIndex, bLen, fmt"{ctx}: frame[{j}] bone targetIndex")
      of dftMorph:
        checkIndex(frame.targetIndex, mLen, fmt"{ctx}: frame[{j}] morph targetIndex")

  for i, joint in model.joints:
    template ctx: string = "Joint[" & $i & "]" & contextName(joint.nameJA)
    checkIndex(joint.rigidBodyIndexA, rbLen, fmt"{ctx}: rigidBodyIndexA")
    checkIndex(joint.rigidBodyIndexB, rbLen, fmt"{ctx}: rigidBodyIndexB")

  for i, body in model.rigidBodies:
    template ctx: string = "RigidBody[" & $i & "]" & contextName(body.nameJA)
    checkIndex(body.relatedBoneIndex, bLen, fmt"{ctx}: relatedBoneIndex")

  for i, sb in model.softBodies:
    template ctx: string = "SoftBody[" & $i & "]" & contextName(sb.nameJA)
    checkIndex(sb.materialIndex, matLen, fmt"{ctx}: materialIndex")
    for j, anchor in sb.anchorRigidBodies:
      checkIndex(anchor.rigidBodyIndex, rbLen, fmt"{ctx}: anchorRigidBodies[{j}].rigidBodyIndex")
      checkVertexIndex(anchor.vertexIndex, vLen, fmt"{ctx}: anchorRigidBodies[{j}].vertexIndex")
    for j, pin in sb.vertexPins:
      checkVertexIndex(pin, vLen, fmt"{ctx}: vertexPins[{j}]")

proc validate*(model: PmxModel, maxStringBytes = MaxStringBytes) {.raises: [ValueError].} =
  ## Validates `model` against the strict PMX rules: enums, texts, ranges,
  ## references, and cycles. It raises ValueError on the first problem found.
  if model == nil:
    raise newException(ValueError, "PmxModel is nil.")
  validateElementCounts(model)
  validateNoNilRefs(model)
  validateEnumFields(model)
  validateTexts(model, maxStringBytes)
  let deformHigh = int(ord(high(DeformKind)))
  for i, vertex in model.vertices:
    if int(vertex.weightDeform.kind) < 0 or int(vertex.weightDeform.kind) > deformHigh:
      raise newException(
        ValueError, "Vertex[" & $i & "].weightDeform.kind is not a supported PMX value.")
  validateElementValues(model)
  validateVersionCompatibility(model)
  validateMaterialFaceCounts(model)
  validateCrossRefs(model)

proc repairWithReport*(
  obj: PmxModel,
  maxStringBytes = MaxStringBytes
): seq[string] {.raises: [ValueError].} =
  ## Repairs `obj` in place and returns the strict violations that remain. An empty
  ## sequence means the model now passes `validate`.
  if obj == nil:
    raise newException(ValueError, "PmxModel is nil.")
  if maxStringBytes < 0 or int64(maxStringBytes) > int64(MaxPmxStringBytes):
    raise newException(
      ValueError, fmt"String byte limit {maxStringBytes} is outside [0, {MaxPmxStringBytes}].")
  obj.repair()
  try:
    validate(obj, maxStringBytes)
  except ValueError as exc:
    result.add exc.msg
    if obj.version == pmx20 and obj.isPmx21Only:
      result.add(
        "The model keeps PMX 2.0 but contains PMX 2.1-only data; " &
          "writePmx can promote it with autoUpgradeVersion = true.")

template checkWireIndex(idx: int32, label: untyped) =
  ## Checks that a signed reference is not below -1, the null sentinel.
  if idx < -1:
    raise newException(ValueError, label & " index " & $idx & " is below the PMX null sentinel -1.")

template checkWireVertexIndex(idx: int32, label: untyped) =
  ## Checks that an unsigned vertex index is not negative.
  if idx < 0:
    raise newException(ValueError, label & " vertex index " & $idx & " is negative.")

proc validateWireDeform(deform: DeformData, label: string) {.raises: [ValueError].} =
  ## Checks deformation bone indices and weights against the wire rules.
  requireValidEnum(deform.kind, label & ".kind")
  case deform.kind
  of dkBDEF1:
    checkWireIndex(deform.bdef1.boneIndex1, label & ".bdef1.boneIndex1")
  of dkBDEF2:
    checkWireIndex(deform.bdef2.boneIndex1, label & ".bdef2.boneIndex1")
    checkWireIndex(deform.bdef2.boneIndex2, label & ".bdef2.boneIndex2")
    checkFinite(deform.bdef2.boneWeight1, label & ".bdef2.boneWeight1")
  of dkBDEF4:
    for i, index in
      [deform.bdef4.boneIndex1, deform.bdef4.boneIndex2, deform.bdef4.boneIndex3, deform.bdef4.boneIndex4]:
      checkWireIndex(index, fmt"{label}.bdef4.boneIndex[{i}]")
    for i, weight in
      [
        deform.bdef4.boneWeight1,
        deform.bdef4.boneWeight2,
        deform.bdef4.boneWeight3,
        deform.bdef4.boneWeight4
      ]:
      checkFinite(weight, fmt"{label}.bdef4.weight[{i}]")
  of dkSDEF:
    checkWireIndex(deform.sdef.boneIndex1, label & ".sdef.boneIndex1")
    checkWireIndex(deform.sdef.boneIndex2, label & ".sdef.boneIndex2")
    checkFinite(deform.sdef.boneWeight1, label & ".sdef.boneWeight1")
    checkFinite(deform.sdef.c, label & ".sdef.c")
    checkFinite(deform.sdef.r0, label & ".sdef.r0")
    checkFinite(deform.sdef.r1, label & ".sdef.r1")
  of dkQDEF:
    for i, index in
      [deform.qdef.boneIndex1, deform.qdef.boneIndex2, deform.qdef.boneIndex3, deform.qdef.boneIndex4]:
      checkWireIndex(index, fmt"{label}.qdef.boneIndex[{i}]")
    for i, weight in
      [deform.qdef.boneWeight1, deform.qdef.boneWeight2, deform.qdef.boneWeight3, deform.qdef.boneWeight4]:
      checkFinite(weight, fmt"{label}.qdef.weight[{i}]")

proc validateWireValues(model: PmxModel) {.raises: [ValueError].} =
  ## Checks that every element field is finite and can be encoded.
  for i, vertex in model.vertices:
    template ctx: string = "Vertex[" & $i & "]"
    checkFinite(vertex.position, ctx & ".position")
    checkFinite(vertex.normal, ctx & ".normal")
    checkFinite(vertex.uv, ctx & ".uv")
    if vertex.additionalUv.len > 4 or int32(vertex.additionalUv.len) != model.additionalUvCount:
      raise newException(
        ValueError,
        fmt"{ctx} additional UV count {vertex.additionalUv.len} does not match model declaration {model.additionalUvCount}."
      )
    for j, uv in vertex.additionalUv:
      checkFinite(uv, fmt"{ctx}.additionalUv[{j}]")
    validateWireDeform(vertex.weightDeform, ctx & ".weightDeform")
    checkFinite(vertex.edgeScale, ctx & ".edgeScale")

  for i, face in model.faces:
    checkWireVertexIndex(face.vertexIndex1, fmt"Face[{i}].vertexIndex1")
    checkWireVertexIndex(face.vertexIndex2, fmt"Face[{i}].vertexIndex2")
    checkWireVertexIndex(face.vertexIndex3, fmt"Face[{i}].vertexIndex3")

  for i, material in model.materials:
    template ctx: string = "Material[" & $i & "]"
    let flags = toMask(material.flags)
    if flags < 0 or flags > 0xFF:
      raise newException(ValueError, fmt"{ctx}.flags {flags} do not fit the PMX byte field.")
    checkFinite(material.diffuseColor, ctx & ".diffuseColor")
    checkFinite(material.alpha, ctx & ".alpha")
    checkFinite(material.specularColor, ctx & ".specularColor")
    checkFinite(material.specularStrength, ctx & ".specularStrength")
    checkFinite(material.ambientColor, ctx & ".ambientColor")
    checkFinite(material.edgeColor, ctx & ".edgeColor")
    checkFinite(material.edgeScale, ctx & ".edgeScale")
    checkWireIndex(material.textureIndex, ctx & ".textureIndex")
    checkWireIndex(material.sphereTextureIndex, ctx & ".sphereTextureIndex")
    if material.internalToon:
      if material.toonTextureIndex < -128 or material.toonTextureIndex > 127:
        raise newException(ValueError, fmt"{ctx}.toonTextureIndex does not fit the PMX byte field.")
    else:
      checkWireIndex(material.toonTextureIndex, ctx & ".toonTextureIndex")
    if material.faceCount < 0 or material.faceCount > high(int32) div 3:
      raise newException(ValueError, fmt"{ctx}.faceCount {material.faceCount} cannot be encoded.")

  for i, bone in model.bones:
    template ctx: string = "Bone[" & $i & "]"
    let flags = toMask(bone.flags)
    if flags < 0 or flags > 0xFFFF:
      raise newException(ValueError, fmt"{ctx}.flags do not fit the PMX uint16 field.")
    checkFinite(bone.position, ctx & ".position")
    checkWireIndex(bone.parentBoneIndex, ctx & ".parentBoneIndex")
    if bone.flags.connection:
      checkWireIndex(bone.tailIndex, ctx & ".tailIndex")
    else:
      checkFinite(bone.tailPosition, ctx & ".tailPosition")
    if bone.flags.inheritRotation or bone.flags.inheritTranslation:
      checkWireIndex(bone.inheritParentIndex, ctx & ".inheritParentIndex")
      checkFinite(bone.inheritParentInfluence, ctx & ".inheritParentInfluence")
    if bone.flags.fixedAxis:
      checkFinite(bone.fixedAxisDirection, ctx & ".fixedAxisDirection")
    if bone.flags.localCoordinate:
      checkFinite(bone.localXVector, ctx & ".localXVector")
      checkFinite(bone.localZVector, ctx & ".localZVector")
    if bone.flags.ik:
      checkWireIndex(bone.ik.targetIndex, ctx & ".ik.targetIndex")
      checkFinite(bone.ik.limitAngle, ctx & ".ik.limitAngle")
      for j, link in bone.ik.links:
        checkWireIndex(link.boneIndex, fmt"{ctx}.ik.links[{j}].boneIndex")
        if link.hasLimits:
          checkFinite(link.limitMin, fmt"{ctx}.ik.links[{j}].limitMin")
          checkFinite(link.limitMax, fmt"{ctx}.ik.links[{j}].limitMax")

  for i, morph in model.morphs:
    template ctx: string = "Morph[" & $i & "]"
    let expectedKind = getExpectedMorphOffsetKind(morph.morphType)
    for j, offset in morph.offsetData:
      if offset.kind != expectedKind:
        raise newException(ValueError, fmt"{ctx}.offsetData[{j}] has an incompatible kind.")
      case offset.kind
      of moGroup:
        checkWireIndex(offset.group.morphIndex, fmt"{ctx}.offset[{j}].morphIndex")
        checkFinite(offset.group.influence, fmt"{ctx}.offset[{j}].influence")
      of moVertex:
        checkWireVertexIndex(offset.vertex.vertexIndex, fmt"{ctx}.offset[{j}].vertexIndex")
        checkFinite(offset.vertex.translation, fmt"{ctx}.offset[{j}].translation")
      of moBone:
        checkWireIndex(offset.bone.boneIndex, fmt"{ctx}.offset[{j}].boneIndex")
        checkFinite(offset.bone.translation, fmt"{ctx}.offset[{j}].translation")
        checkFinite(offset.bone.rotation, fmt"{ctx}.offset[{j}].rotation")
      of moUV:
        checkWireVertexIndex(offset.uv.vertexIndex, fmt"{ctx}.offset[{j}].vertexIndex")
        checkFinite(offset.uv.floats, fmt"{ctx}.offset[{j}].floats")
      of moMaterial:
        checkWireIndex(offset.material.materialIndex, fmt"{ctx}.offset[{j}].materialIndex")
        checkFinite(offset.material.diffuseColor, fmt"{ctx}.offset[{j}].diffuseColor")
        checkFinite(offset.material.specularColor, fmt"{ctx}.offset[{j}].specularColor")
        checkFinite(offset.material.specularStrength, fmt"{ctx}.offset[{j}].specularStrength")
        checkFinite(offset.material.ambientColor, fmt"{ctx}.offset[{j}].ambientColor")
        checkFinite(offset.material.edgeColor, fmt"{ctx}.offset[{j}].edgeColor")
        checkFinite(offset.material.edgeScale, fmt"{ctx}.offset[{j}].edgeScale")
        checkFinite(offset.material.textureTint, fmt"{ctx}.offset[{j}].textureTint")
        checkFinite(offset.material.sphereTint, fmt"{ctx}.offset[{j}].sphereTint")
        checkFinite(offset.material.toonTint, fmt"{ctx}.offset[{j}].toonTint")
      of moFlip:
        checkWireIndex(offset.flip.morphIndex, fmt"{ctx}.offset[{j}].morphIndex")
        checkFinite(offset.flip.influence, fmt"{ctx}.offset[{j}].influence")
      of moImpulse:
        checkWireIndex(offset.impulse.rigidBodyIndex, fmt"{ctx}.offset[{j}].rigidBodyIndex")
        checkFinite(offset.impulse.movementSpeed, fmt"{ctx}.offset[{j}].movementSpeed")
        checkFinite(offset.impulse.rotationTorque, fmt"{ctx}.offset[{j}].rotationTorque")

  for i, slot in model.displayFrames:
    for j, frame in slot.frames:
      checkWireIndex(frame.targetIndex, fmt"DisplaySlot[{i}].frames[{j}].targetIndex")

  for i, body in model.rigidBodies:
    template ctx: string = "RigidBody[" & $i & "]"
    let nonCollisionMask = toMask(body.nonCollisionMask)
    if body.groupId notin 1'i32..16'i32:
      raise newException(
        ValueError, fmt"{ctx}.groupId must be in [1, 16], even for wire-safe output. Group IDs are " &
        "physics inputs, not nullable references.")
    if nonCollisionMask < 0 or nonCollisionMask > 0xFFFF:
      raise newException(ValueError, fmt"{ctx}.nonCollisionMask cannot be encoded.")
    checkWireIndex(body.relatedBoneIndex, ctx & ".relatedBoneIndex")
    checkFinite(body.shapeSize, ctx & ".shapeSize")
    checkFinite(body.shapePosition, ctx & ".shapePosition")
    checkFinite(body.shapeRotation, ctx & ".shapeRotation")
    checkFinite(body.mass, ctx & ".mass")
    checkFinite(body.moveAttenuation, ctx & ".moveAttenuation")
    checkFinite(body.rotationDamping, ctx & ".rotationDamping")
    checkFinite(body.repulsion, ctx & ".repulsion")
    checkFinite(body.frictionForce, ctx & ".frictionForce")

  for i, joint in model.joints:
    checkWireIndex(joint.rigidBodyIndexA, fmt"Joint[{i}].rigidBodyIndexA")
    checkWireIndex(joint.rigidBodyIndexB, fmt"Joint[{i}].rigidBodyIndexB")
    checkFinite(joint.position, fmt"Joint[{i}].position")
    checkFinite(joint.rotation, fmt"Joint[{i}].rotation")
    checkFinite(joint.positionMinimum, fmt"Joint[{i}].positionMinimum")
    checkFinite(joint.positionMaximum, fmt"Joint[{i}].positionMaximum")
    checkFinite(joint.rotationMinimum, fmt"Joint[{i}].rotationMinimum")
    checkFinite(joint.rotationMaximum, fmt"Joint[{i}].rotationMaximum")
    checkFinite(joint.positionSpring, fmt"Joint[{i}].positionSpring")
    checkFinite(joint.rotationSpring, fmt"Joint[{i}].rotationSpring")

  for i, body in model.softBodies:
    template ctx: string = "SoftBody[" & $i & "]"
    let nonCollisionMask = toMask(body.nonCollisionMask)
    let flags = toMask(body.flags)
    if body.groupId notin 1'i32..16'i32:
      raise newException(
        ValueError, fmt"{ctx}.groupId must be in [1, 16], even for wire-safe output. Group IDs are " &
        "physics inputs, not nullable references.")
    if nonCollisionMask < 0 or nonCollisionMask > 0xFFFF or flags < 0 or flags > 0xFF:
      raise newException(ValueError, fmt"{ctx} mask/flags cannot be encoded.")
    checkWireIndex(body.materialIndex, ctx & ".materialIndex")
    for j, anchor in body.anchorRigidBodies:
      checkWireIndex(anchor.rigidBodyIndex, fmt"{ctx}.anchorRigidBodies[{j}].rigidBodyIndex")
      checkWireVertexIndex(anchor.vertexIndex, fmt"{ctx}.anchorRigidBodies[{j}].vertexIndex")
    for j, pin in body.vertexPins:
      checkWireVertexIndex(pin, fmt"{ctx}.vertexPins[{j}]")
    for value in
      [
        body.totalMass,
        body.collisionMargin,
        body.config.vcf,
        body.config.dp,
        body.config.dg,
        body.config.lf,
        body.config.pr,
        body.config.vc,
        body.config.df,
        body.config.mt,
        body.config.chr,
        body.config.khr,
        body.config.`shr`,
        body.config.ahr,
        body.cluster.srhrCl,
        body.cluster.skhrCl,
        body.cluster.sshrCl,
        body.cluster.srSpltCl,
        body.cluster.skSpltCl,
        body.cluster.ssSpltCl,
        body.material.lst,
        body.material.ast,
        body.material.vst
      ]:
      checkFinite(value, ctx & ".physicsValue")

proc validateWireSafe*(model: PmxModel, maxStringBytes = MaxStringBytes) {.raises: [ValueError].} =
  ## Checks that `model` can be written in lenient mode. Only what would corrupt the
  ## wire is rejected, so the semantic rules are skipped.
  if model == nil:
    raise newException(ValueError, "PmxModel is nil.")
  if model.additionalUvCount < 0 or model.additionalUvCount > 4:
    raise newException(ValueError, "Additional UV count must be in [0, 4].")
  validateElementCounts(model)
  validateNoNilRefs(model)
  validateEnumFields(model)
  validateTexts(model, maxStringBytes)
  validateWireValues(model)

proc isValid*(model: PmxModel, strict = true, maxStringBytes = MaxStringBytes): bool =
  ## Returns true when `model` passes `validate`, or the wire-safe rule with `strict = false`.
  ## Semantic problems come back as `false`; the call does not raise.
  try:
    if strict:
      validate(model, maxStringBytes)
    else:
      validateWireSafe(model, maxStringBytes)
    true
  except ValueError:
    false
