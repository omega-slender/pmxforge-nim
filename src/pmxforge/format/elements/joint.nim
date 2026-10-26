## Physics joints.
##
## Provides `Joint`, the constraint linking two rigid bodies, with its limits, springs, and
## the joint types PMX 2.1 adds.

import ../../core/vectors
import ../internal/copy_helpers
import ../internal/preconditions

type
  JointType* {.size: sizeof(int32).} = enum ## Physics constraint type between two bodies.
    jtSpring6DOF = 0 ## 6-DOF spring constraint (standard PMX 2.0).
    jt6DOF = 1 ## 6-DOF constraint without springs (PMX 2.1).
    jtPointToPoint = 2 ## Point-to-point / ball socket (PMX 2.1).
    jtConeTwist = 3 ## Cone twist constraint (PMX 2.1).
    jtSlider = 4 ## Slider constraint (PMX 2.1).
    jtHinge = 5 ## Hinge constraint (PMX 2.1).

  Joint* = ref object ## Physics constraint record connecting two rigid bodies.
    nameJA*: string ## Japanese joint name.
    nameEN*: string ## English / universal joint name.
    jointType*: JointType ## Constraint type: 6DOF spring, slider, hinge, or cone twist.
    rigidBodyIndexA*: int32 ## First rigid body index (-1 if none).
    rigidBodyIndexB*: int32 ## Second rigid body index (-1 if none).
    position*: Vector3 ## Rest position in 3D space.
    rotation*: Vector3 ## Rest Euler rotation in radians.
    positionMinimum*: Vector3 ## Minimum position limit; some joint types store unrelated settings here.
    positionMaximum*: Vector3 ## Maximum position limit; some joint types store unrelated settings here.
    rotationMinimum*: Vector3 ## Minimum rotation limit; ConeTwist stores its three span angles here.
    rotationMaximum*: Vector3 ## Maximum rotation limit; unused by ConeTwist.
    positionSpring*: Vector3 ## Position spring constant stiffness.
    rotationSpring*: Vector3 ## Rotation spring constant stiffness.

func isPmx21Only*(jointType: JointType): bool {.inline.} =
  ## Returns true for every type except `jtSpring6DOF`, which PMX 2.0 already has.
  jointType != jtSpring6DOF

func orderedPositionLimitAxes*(jointType: JointType): set[0..2] =
  ## Returns the position axes that hold a real bound for `jointType`. Every joint
  ## shares the same twelve limit floats, but most types store something else there.
  case jointType
  of jtSpring6DOF, jt6DOF:
    {0, 1, 2}
  of jtSlider:
    {0}
  else:
    {}

func orderedRotationLimitAxes*(jointType: JointType): set[0..2] =
  ## Returns the rotation axes that hold a real bound for `jointType`. ConeTwist keeps
  ## span angles in the lower vector, and P2P has no rotation limits at all.
  case jointType
  of jtSpring6DOF, jt6DOF:
    {0, 1, 2}
  of jtSlider, jtHinge:
    {0}
  else:
    {}

func limitOrderIsValid*(joint: Joint): bool =
  ## Returns true when the limits this type uses are ordered.
  if joint == nil:
    return false
  let positionAxes = orderedPositionLimitAxes(joint.jointType)
  if 0 in positionAxes and joint.positionMinimum.x > joint.positionMaximum.x:
    return false
  if 1 in positionAxes and joint.positionMinimum.y > joint.positionMaximum.y:
    return false
  if 2 in positionAxes and joint.positionMinimum.z > joint.positionMaximum.z:
    return false
  let rotationAxes = orderedRotationLimitAxes(joint.jointType)
  if 0 in rotationAxes and joint.rotationMinimum.x > joint.rotationMaximum.x:
    return false
  if 1 in rotationAxes and joint.rotationMinimum.y > joint.rotationMaximum.y:
    return false
  if 2 in rotationAxes and joint.rotationMinimum.z > joint.rotationMaximum.z:
    return false
  true

proc repairLimitOrder*(joint: Joint) =
  ## Clamps the limit pairs this joint type uses and leaves the repurposed components
  ## untouched.
  if joint == nil:
    return
  let positionAxes = orderedPositionLimitAxes(joint.jointType)
  if 0 in positionAxes:
    joint.positionMinimum.x = min(joint.positionMinimum.x, joint.positionMaximum.x)
  if 1 in positionAxes:
    joint.positionMinimum.y = min(joint.positionMinimum.y, joint.positionMaximum.y)
  if 2 in positionAxes:
    joint.positionMinimum.z = min(joint.positionMinimum.z, joint.positionMaximum.z)
  let rotationAxes = orderedRotationLimitAxes(joint.jointType)
  if 0 in rotationAxes:
    joint.rotationMinimum.x = min(joint.rotationMinimum.x, joint.rotationMaximum.x)
  if 1 in rotationAxes:
    joint.rotationMinimum.y = min(joint.rotationMinimum.y, joint.rotationMaximum.y)
  if 2 in rotationAxes:
    joint.rotationMinimum.z = min(joint.rotationMinimum.z, joint.rotationMaximum.z)

proc isValid*(joint: Joint, rigidBodyCount = -1'i32): bool {.raises: [].}
  ## Returns true when limits, springs, and body indices are valid.

proc newJoint*(
  nameJA = "",
  rigidBodyIndexA = -1'i32,
  rigidBodyIndexB = -1'i32,
  jointType = jtSpring6DOF,
  position = Vector3.zero,
  rotation = Vector3.zero,
  positionMinimum = Vector3.zero,
  positionMaximum = Vector3.zero,
  rotationMinimum = Vector3.zero,
  rotationMaximum = Vector3.zero,
  positionSpring = Vector3.zero,
  rotationSpring = Vector3.zero,
  nameEN = nameJA
): Joint {.raises: [ValueError].} =
  ## Creates a joint; -1 means an unbound body index.
  if rigidBodyIndexA < -1 or rigidBodyIndexB < -1:
    raise newException(ValueError, "Rigid body indices must be -1 or non-negative.")
  requireValidEnum(jointType, "Joint type")
  result = Joint(
    nameJA: nameJA,
    nameEN: nameEN,
    jointType: jointType,
    rigidBodyIndexA: rigidBodyIndexA,
    rigidBodyIndexB: rigidBodyIndexB,
    position: position,
    rotation: rotation,
    positionMinimum: positionMinimum,
    positionMaximum: positionMaximum,
    rotationMinimum: rotationMinimum,
    rotationMaximum: rotationMaximum,
    positionSpring: positionSpring,
    rotationSpring: rotationSpring
  )
  if not result.isValid():
    raise newException(ValueError, "Joint contains invalid local values.")

func isPmx21Only*(joint: Joint): bool =
  ## Returns true if this joint instance requires PMX 2.1.
  joint != nil and joint.jointType.isPmx21Only

proc `==`*(a, b: Joint): bool =
  ## Compares two joints for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.jointType == b.jointType and
    a.rigidBodyIndexA == b.rigidBodyIndexA and a.rigidBodyIndexB == b.rigidBodyIndexB and
    a.position == b.position and a.rotation == b.rotation and a.positionMinimum == b.positionMinimum and
    a.positionMaximum == b.positionMaximum and a.rotationMinimum == b.rotationMinimum and
    a.rotationMaximum == b.rotationMaximum and a.positionSpring == b.positionSpring and
    a.rotationSpring == b.rotationSpring

proc copy*(obj: Joint): Joint =
  ## Returns a deep copy of the joint.
  if isNil(obj):
    return nil
  Joint(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    jointType: obj.jointType,
    rigidBodyIndexA: obj.rigidBodyIndexA,
    rigidBodyIndexB: obj.rigidBodyIndexB,
    position: obj.position,
    rotation: obj.rotation,
    positionMinimum: obj.positionMinimum,
    positionMaximum: obj.positionMaximum,
    rotationMinimum: obj.rotationMinimum,
    rotationMaximum: obj.rotationMaximum,
    positionSpring: obj.positionSpring,
    rotationSpring: obj.rotationSpring
  )

proc isValid*(joint: Joint, rigidBodyCount: int32): bool =
  if not isValidOptionalCount(rigidBodyCount):
    return false
  if joint == nil:
    return false
  try:
    requireValidEnum(joint.jointType, "Joint type")
    if joint.rigidBodyIndexA < -1 or joint.rigidBodyIndexB < -1:
      return false
    if rigidBodyCount >= 0 and
        (joint.rigidBodyIndexA >= rigidBodyCount or joint.rigidBodyIndexB >= rigidBodyCount):
      return false
    checkFinite(joint.position, "Joint position")
    checkFinite(joint.rotation, "Joint rotation")
    checkFinite(joint.positionMinimum, "Joint position minimum")
    checkFinite(joint.positionMaximum, "Joint position maximum")
    checkFinite(joint.rotationMinimum, "Joint rotation minimum")
    checkFinite(joint.rotationMaximum, "Joint rotation maximum")
    checkFinite(joint.positionSpring, "Joint position spring")
    checkFinite(joint.rotationSpring, "Joint rotation spring")
    joint.limitOrderIsValid()
  except ValueError:
    false

proc repair*(joint: Joint, rigidBodyCount = -1'i32) {.raises: [ValueError].} =
  ## Fixes vectors, orders the used limits, and bounds body indices.
  requireValidOptionalCount(rigidBodyCount, "Joint rigidBodyCount")
  if joint == nil:
    return
  if int(joint.jointType) < 0 or int(joint.jointType) > 5:
    joint.jointType = jtSpring6DOF
  if joint.rigidBodyIndexA < -1 or (rigidBodyCount >= 0 and joint.rigidBodyIndexA >= rigidBodyCount):
    joint.rigidBodyIndexA = -1
  if joint.rigidBodyIndexB < -1 or (rigidBodyCount >= 0 and joint.rigidBodyIndexB >= rigidBodyCount):
    joint.rigidBodyIndexB = -1
  joint.position = repairFinite(joint.position)
  joint.rotation = repairFinite(joint.rotation)
  joint.positionMinimum = repairFinite(joint.positionMinimum)
  joint.positionMaximum = repairFinite(joint.positionMaximum)
  joint.rotationMinimum = repairFinite(joint.rotationMinimum)
  joint.rotationMaximum = repairFinite(joint.rotationMaximum)
  joint.positionSpring = repairFinite(joint.positionSpring)
  joint.rotationSpring = repairFinite(joint.rotationSpring)
  joint.repairLimitOrder()
