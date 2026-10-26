## Bone and inverse kinematics records.
##
## Provides `Bone`, `BoneIK`, and `IKLink`, covering hierarchy, tail connection, transform inheritance, local
## axes, and IK limits in degrees.

import ../../core/vectors
import ../flags
import ../internal/preconditions
import ../internal/copy_helpers

type
  IKLink* = object ## Single bone link in an IK chain with optional rotation limits.
    boneIndex*: int32 ## Target bone index in the IK chain.
    hasLimits*: bool ## Enables Euler rotation limits.
    limitMin*: Vector3 ## Minimum rotation limits in degrees (wire radians converted; one ULP tolerance).
    limitMax*: Vector3 ## Maximum rotation limits in degrees (wire radians converted; one ULP tolerance).

  BoneIK* = object ## Inverse kinematics settings and link chain.
    targetIndex*: int32 ## IK target effector bone index.
    loopCount*: int32 ## Iterations per frame for the IK solver.
    limitAngle*: float32 ## Maximum rotation step per iteration in degrees. The wire stores radians; the conversion can change the last bit, so a read/write pair is accurate to one `float32` ULP.
    links*: seq[IKLink] ## Ordered chain of bones participating in the IK solve.

  Bone* = ref object ## PMX bone containing hierarchy, transforms, and IK data.
    nameJA*: string ## Japanese bone name.
    nameEN*: string ## English / universal bone name.
    position*: Vector3 ## Rest position in 3D space.
    parentBoneIndex*: int32 ## Parent bone index (-1 if none).
    layer*: int32 ## Transform hierarchy evaluation layer.
    flags*: BoneFlags ## Capabilities such as rotatable, translatable, and IK.
    tailIndex*: int32 ## Connected child bone index (-1 if offset used).
    tailPosition*: Vector3 ## Offset vector to tail if connection flag is false.
    inheritParentIndex*: int32 ## Target bone index to inherit transforms from (-1 if none).
    inheritParentInfluence*: float32 ## Weight factor for transform inheritance.
    fixedAxisDirection*: Vector3 ## Direction vector for fixed-axis rotation constraint.
    localXVector*: Vector3 ## Custom local X axis orientation vector.
    localZVector*: Vector3 ## Custom local Z axis orientation vector.
    externalParentKey*: int32 ## Key identifier for external parent bone linking.
    ik*: BoneIK ## Inverse kinematics settings.

proc isValid*(bone: Bone, boneCount = -1'i32): bool {.raises: [].}
  ## Returns true when transforms, tail data, and references are valid.

proc newBone*(
  nameJA = "",
  position = Vector3.zero,
  parentBoneIndex = -1'i32,
  nameEN = nameJA,
  layer = 0'i32,
  flags = BoneFlags(rotatable: true, visible: true, manipulatable: true),
  tailIndex = -1'i32,
  tailPosition = Vector3.zero,
  inheritParentIndex = -1'i32,
  inheritParentInfluence = 0.0'f32,
  fixedAxisDirection = Vector3.zero,
  localXVector = Vector3.zero,
  localZVector = Vector3.zero,
  externalParentKey = -1'i32,
  ik = BoneIK()
): Bone {.raises: [ValueError].} =
  ## Creates a bone with the given transform, hierarchy, and flags.
  checkFinite(position, "Bone position")
  if parentBoneIndex < -1:
    raise newException(ValueError, "Parent index must be -1 or non-negative.")
  result = Bone(
    nameJA: nameJA,
    nameEN: nameEN,
    position: position,
    parentBoneIndex: parentBoneIndex,
    layer: layer,
    flags: flags,
    tailIndex: tailIndex,
    tailPosition: tailPosition,
    inheritParentIndex: inheritParentIndex,
    inheritParentInfluence: inheritParentInfluence,
    fixedAxisDirection: fixedAxisDirection,
    localXVector: localXVector,
    localZVector: localZVector,
    externalParentKey: externalParentKey,
    ik: ik
  )
  if not result.isValid():
    raise newException(ValueError, "Bone contains invalid local values.")

proc newBoneTail*(
  nameJA = "",
  tailIndex = 0'i32,
  position = Vector3.zero,
  parentBoneIndex = -1'i32
): Bone {.raises: [ValueError].} =
  ## Creates a bone connected to another bone (tail connection).
  if tailIndex < -1:
    raise newException(ValueError, "Tail bone index must be -1 or non-negative.")
  var flags = BoneFlags(rotatable: true, visible: true, manipulatable: true)
  flags.connection = true
  newBone(nameJA, position, parentBoneIndex, flags = flags, tailIndex = tailIndex)

proc newIKLink*(
  boneIndex = 0'i32,
  hasLimits = false,
  limitMin = Vector3.zero,
  limitMax = Vector3.zero
): IKLink {.raises: [ValueError].} =
  ## Creates an IK link for a target bone. Pass -1 for unbound.
  if boneIndex < -1:
    raise newException(ValueError, "IK link index must be -1 or non-negative.")
  checkFinite(limitMin, "IK minimum")
  checkFinite(limitMax, "IK maximum")
  if hasLimits and (limitMin.x > limitMax.x or limitMin.y > limitMax.y or limitMin.z > limitMax.z):
    raise newException(ValueError, "IK minimum must be <= maximum.")
  IKLink(boneIndex: boneIndex, hasLimits: hasLimits, limitMin: limitMin, limitMax: limitMax)

proc newLimitedIKLink*(
  boneIndex = 0'i32,
  limitMin = Vector3.zero,
  limitMax = Vector3.zero
): IKLink {.raises: [ValueError].} =
  ## Creates an IK link with angular rotation limits.
  if boneIndex < -1:
    raise newException(ValueError, "IK link index must be -1 or non-negative.")
  checkFinite(limitMin, "IK minimum")
  checkFinite(limitMax, "IK maximum")
  if limitMin.x > limitMax.x or limitMin.y > limitMax.y or limitMin.z > limitMax.z:
    raise newException(ValueError, "IK minimum must be <= maximum.")
  IKLink(boneIndex: boneIndex, hasLimits: true, limitMin: limitMin, limitMax: limitMax)

proc newBoneIK*(
  targetIndex = 0'i32,
  loopCount = 1'i32,
  limitAngle = 0.0'f32,
  links: seq[IKLink] = @[]
): BoneIK {.raises: [ValueError].} =
  ## Creates IK settings and link sequence for an IK root bone.
  if targetIndex < -1 or loopCount <= 0:
    raise newException(ValueError, "IK target must be -1 or non-negative and loopCount must be positive.")
  checkNonNegativeFinite(limitAngle, "IK limit angle")
  for link in links:
    if link.boneIndex < -1:
      raise newException(ValueError, "IK link index must be -1 or non-negative.")
    if link.hasLimits:
      checkFinite(link.limitMin, "IK minimum")
      checkFinite(link.limitMax, "IK maximum")
      if link.limitMin.x > link.limitMax.x or link.limitMin.y > link.limitMax.y or
          link.limitMin.z > link.limitMax.z:
        raise newException(ValueError, "IK minimum must be <= maximum.")
  BoneIK(targetIndex: targetIndex, loopCount: loopCount, limitAngle: limitAngle, links: copySeq(links))

func hasParent*(bone: Bone): bool =
  ## Returns true if the bone has a valid parent bone.
  bone != nil and bone.parentBoneIndex >= 0
func hasTailBone*(bone: Bone): bool =
  ## Returns true if the bone connects to another bone (tail connection).
  bone != nil and bone.flags.connection and bone.tailIndex >= 0
func hasIk*(bone: Bone): bool =
  ## Returns true if the bone is an IK controller.
  bone != nil and bone.flags.ik

proc `==`*(a, b: Bone): bool =
  ## Compares two bones for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.position == b.position and
    a.parentBoneIndex == b.parentBoneIndex and a.layer == b.layer and a.flags == b.flags and
    a.tailIndex == b.tailIndex and a.tailPosition == b.tailPosition and
    a.inheritParentIndex == b.inheritParentIndex and a.inheritParentInfluence == b.inheritParentInfluence and
    a.fixedAxisDirection == b.fixedAxisDirection and a.localXVector == b.localXVector and
    a.localZVector == b.localZVector and a.externalParentKey == b.externalParentKey and
    a.ik.targetIndex == b.ik.targetIndex and a.ik.loopCount == b.ik.loopCount and
    a.ik.limitAngle == b.ik.limitAngle and a.ik.links == b.ik.links

proc copy*(obj: Bone): Bone =
  ## Returns a deep copy of the bone and its IK links.
  if isNil(obj):
    return nil
  Bone(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    position: obj.position,
    parentBoneIndex: obj.parentBoneIndex,
    layer: obj.layer,
    flags: obj.flags,
    tailIndex: obj.tailIndex,
    tailPosition: obj.tailPosition,
    inheritParentIndex: obj.inheritParentIndex,
    inheritParentInfluence: obj.inheritParentInfluence,
    fixedAxisDirection: obj.fixedAxisDirection,
    localXVector: obj.localXVector,
    localZVector: obj.localZVector,
    externalParentKey: obj.externalParentKey,
    ik: BoneIK(
      targetIndex: obj.ik.targetIndex,
      loopCount: obj.ik.loopCount,
      limitAngle: obj.ik.limitAngle,
      links: copySeq(obj.ik.links)
    )
  )

proc isValid*(bone: Bone, boneCount: int32): bool =
  if not isValidOptionalCount(boneCount):
    return false
  if bone == nil:
    return false
  try:
    if bone.layer < 0:
      return false
    checkFinite(bone.position, "Bone position")
    if not bone.flags.connection:
      checkFinite(bone.tailPosition, "Bone tail position")
    if bone.flags.inheritRotation or bone.flags.inheritTranslation:
      checkFinite(bone.inheritParentInfluence, "Bone inherit influence")
    if bone.flags.fixedAxis:
      checkFinite(bone.fixedAxisDirection, "Bone fixed axis")
    if bone.flags.localCoordinate:
      checkFinite(bone.localXVector, "Bone local X")
      checkFinite(bone.localZVector, "Bone local Z")
    if bone.parentBoneIndex < -1 or (boneCount >= 0 and bone.parentBoneIndex >= boneCount):
      return false
    if bone.flags.connection and (bone.tailIndex < -1 or (boneCount >= 0 and bone.tailIndex >= boneCount)):
      return false
    if (bone.flags.inheritRotation or bone.flags.inheritTranslation) and
        (bone.inheritParentIndex < -1 or (boneCount >= 0 and bone.inheritParentIndex >= boneCount)):
      return false
    if bone.flags.ik:
      if bone.ik.targetIndex < -1 or (boneCount >= 0 and bone.ik.targetIndex >= boneCount) or
          bone.ik.loopCount <= 0:
        return false
      checkNonNegativeFinite(bone.ik.limitAngle, "Bone IK angle")
      for link in bone.ik.links:
        if link.boneIndex < -1 or (boneCount >= 0 and link.boneIndex >= boneCount):
          return false
        if link.hasLimits:
          checkFinite(link.limitMin, "Bone IK minimum")
          checkFinite(link.limitMax, "Bone IK maximum")
          if link.limitMin.x > link.limitMax.x or link.limitMin.y > link.limitMax.y or
              link.limitMin.z > link.limitMax.z:
            return false
    true
  except ValueError:
    false

proc repair*(bone: Bone, boneCount = -1'i32) {.raises: [ValueError].} =
  ## Fixes non-finite numbers, resets bad references to -1, and clears the IK link chain
  ## when the IK flag is off, because the writer does not encode links behind that flag.
  requireValidOptionalCount(boneCount, "Bone boneCount")
  if bone == nil:
    return
  bone.position = repairFinite(bone.position)
  bone.tailPosition = repairFinite(bone.tailPosition)
  bone.fixedAxisDirection = repairFinite(bone.fixedAxisDirection)
  bone.localXVector = repairFinite(bone.localXVector)
  bone.localZVector = repairFinite(bone.localZVector)
  bone.inheritParentInfluence = repairFinite(bone.inheritParentInfluence)
  bone.layer = max(0'i32, bone.layer)
  if bone.parentBoneIndex < -1 or (boneCount >= 0 and bone.parentBoneIndex >= boneCount):
    bone.parentBoneIndex = -1
  if bone.flags.connection:
    if bone.tailIndex < -1 or (boneCount >= 0 and bone.tailIndex >= boneCount):
      bone.tailIndex = -1
  else:
    bone.tailIndex = -1
  if bone.flags.inheritRotation or bone.flags.inheritTranslation:
    if bone.inheritParentIndex < -1 or (boneCount >= 0 and bone.inheritParentIndex >= boneCount):
      bone.inheritParentIndex = -1
  else:
    bone.inheritParentIndex = -1
  if bone.flags.ik:
    if bone.ik.targetIndex < -1 or (boneCount >= 0 and bone.ik.targetIndex >= boneCount):
      bone.ik.targetIndex = -1
    bone.ik.loopCount = max(1'i32, bone.ik.loopCount)
    bone.ik.limitAngle = repairNonNegative(bone.ik.limitAngle)
    for i in 0 ..< bone.ik.links.len:
      if bone.ik.links[i].boneIndex < -1 or (boneCount >= 0 and bone.ik.links[i].boneIndex >= boneCount):
        bone.ik.links[i].boneIndex = -1
    for i in 0 ..< bone.ik.links.len:
      bone.ik.links[i].limitMin = repairFinite(bone.ik.links[i].limitMin)
      bone.ik.links[i].limitMax = repairFinite(bone.ik.links[i].limitMax)
      if bone.ik.links[i].hasLimits:
        bone.ik.links[i].limitMin.x = min(bone.ik.links[i].limitMin.x, bone.ik.links[i].limitMax.x)
        bone.ik.links[i].limitMin.y = min(bone.ik.links[i].limitMin.y, bone.ik.links[i].limitMax.y)
        bone.ik.links[i].limitMin.z = min(bone.ik.links[i].limitMin.z, bone.ik.links[i].limitMax.z)
  else:
    bone.ik.links.setLen(0)
