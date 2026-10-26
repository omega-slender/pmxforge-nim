## Rigid body records.
##
## Provides `RigidBody` with its collision shape, mass, damping, collision group, and simulation mode.

import ../../core/vectors
import ../flags
import ../internal/preconditions
import ../internal/copy_helpers

type
  RigidBodyShape* {.size: sizeof(int32).} = enum ## Collision primitive shape.
    rbsSphere = 0 ## Sphere (radius = shapeSize.x).
    rbsBox = 1 ## Box (half-extents = shapeSize).
    rbsCapsule = 2 ## Capsule (radius = shapeSize.x, height = shapeSize.y).

  PhysicsMode* {.size: sizeof(int32).} = enum ## Simulation mode for the rigid body.
    pmFollowBone = 0 ## Static (kinematic, follows bone animation).
    pmPhysics = 1 ## Dynamic (driven by physics simulation).
    pmPhysicsAndBone = 2 ## Alignment (physics with bone positioning).

  RigidBody* = ref object ## Physics rigid body record.
    nameJA*: string ## Japanese body name.
    nameEN*: string ## English / universal body name.
    relatedBoneIndex*: int32 ## Target bone index (-1 if none).
    groupId*: int32 ## Collision group ID (1 to 16).
    nonCollisionMask*: CollisionMask ## Mask disabling collisions with other groups.
    shape*: RigidBodyShape ## Collision primitive shape (sphere, box, capsule).
    shapeSize*: Vector3 ## Primitive dimensions.
    shapePosition*: Vector3 ## Position offset relative to bone.
    shapeRotation*: Vector3 ## Euler rotation in radians.
    mass*: float32 ## Body mass in kilograms.
    moveAttenuation*: float32 ## Linear velocity damping.
    rotationDamping*: float32 ## Angular velocity damping.
    repulsion*: float32 ## Restitution / bounce factor.
    frictionForce*: float32 ## Surface friction coefficient.
    physicsMode*: PhysicsMode ## Physics simulation mode.

proc isValid*(body: RigidBody, boneCount = -1'i32): bool {.raises: [].}
  ## Returns true when dimensions and physics values are valid.

proc newRigidBody*(
  nameJA = "",
  relatedBoneIndex = -1'i32,
  groupId = 1'i32,
  nonCollisionMask = CollisionMask(),
  shape = rbsSphere,
  shapeSize = Vector3.one,
  shapePosition = Vector3.zero,
  shapeRotation = Vector3.zero,
  mass = 1.0'f32,
  moveAttenuation = 0.5'f32,
  rotationDamping = 0.5'f32,
  repulsion = 0.0'f32,
  frictionForce = 0.5'f32,
  physicsMode = pmFollowBone,
  nameEN = nameJA
): RigidBody {.raises: [ValueError].} =
  ## Creates a rigid body with its shape, mass, and collision settings.
  if relatedBoneIndex < -1:
    raise newException(ValueError, "Bone index must be -1 or non-negative.")
  requireValidEnum(shape, "Rigid body shape")
  requireValidEnum(physicsMode, "Physics mode")
  result = RigidBody(
    nameJA: nameJA,
    nameEN: nameEN,
    relatedBoneIndex: relatedBoneIndex,
    groupId: groupId,
    nonCollisionMask: nonCollisionMask,
    shape: shape,
    shapeSize: shapeSize,
    shapePosition: shapePosition,
    shapeRotation: shapeRotation,
    mass: mass,
    moveAttenuation: moveAttenuation,
    rotationDamping: rotationDamping,
    repulsion: repulsion,
    frictionForce: frictionForce,
    physicsMode: physicsMode
  )
  if not result.isValid():
    raise newException(ValueError, "Rigid body contains invalid local values.")

proc `==`*(a, b: RigidBody): bool =
  ## Compares two rigid bodies for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.relatedBoneIndex == b.relatedBoneIndex and
    a.groupId == b.groupId and a.nonCollisionMask == b.nonCollisionMask and a.shape == b.shape and
    a.shapeSize == b.shapeSize and a.shapePosition == b.shapePosition and
    a.shapeRotation == b.shapeRotation and a.mass == b.mass and a.moveAttenuation == b.moveAttenuation and
    a.rotationDamping == b.rotationDamping and a.repulsion == b.repulsion and
    a.frictionForce == b.frictionForce and a.physicsMode == b.physicsMode

proc copy*(obj: RigidBody): RigidBody =
  ## Returns a deep copy of the rigid body.
  if isNil(obj):
    return nil
  RigidBody(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    relatedBoneIndex: obj.relatedBoneIndex,
    groupId: obj.groupId,
    nonCollisionMask: obj.nonCollisionMask,
    shape: obj.shape,
    shapeSize: obj.shapeSize,
    shapePosition: obj.shapePosition,
    shapeRotation: obj.shapeRotation,
    mass: obj.mass,
    moveAttenuation: obj.moveAttenuation,
    rotationDamping: obj.rotationDamping,
    repulsion: obj.repulsion,
    frictionForce: obj.frictionForce,
    physicsMode: obj.physicsMode
  )

proc isValid*(body: RigidBody, boneCount: int32): bool =
  if not isValidOptionalCount(boneCount):
    return false
  if body == nil:
    return false
  try:
    requireValidEnum(body.shape, "Rigid-body shape")
    requireValidEnum(body.physicsMode, "Physics mode")
    if body.groupId < 1 or body.groupId > 16:
      return false
    if body.relatedBoneIndex < -1 or (boneCount >= 0 and body.relatedBoneIndex >= boneCount):
      return false
    checkFinite(body.shapeSize, "Rigid-body shape size")
    checkFinite(body.shapePosition, "Rigid-body shape position")
    checkFinite(body.shapeRotation, "Rigid-body shape rotation")
    if body.shapeSize.x < 0 or body.shapeSize.y < 0 or body.shapeSize.z < 0:
      return false
    checkNonNegativeFinite(body.mass, "Rigid-body mass")
    checkNonNegativeFinite(body.moveAttenuation, "Rigid-body move attenuation")
    checkNonNegativeFinite(body.rotationDamping, "Rigid-body rotation damping")
    checkNonNegativeFinite(body.repulsion, "Rigid-body repulsion")
    checkNonNegativeFinite(body.frictionForce, "Rigid-body friction")
    true
  except ValueError:
    false

proc repair*(body: RigidBody, boneCount = -1'i32) {.raises: [ValueError].} =
  ## Clamps physics values and bounds the bone reference.
  requireValidOptionalCount(boneCount, "Rigid body boneCount")
  if body == nil:
    return
  if body.relatedBoneIndex < -1 or (boneCount >= 0 and body.relatedBoneIndex >= boneCount):
    body.relatedBoneIndex = -1
  body.groupId = min(16'i32, max(1'i32, body.groupId))
  if int(body.shape) < 0 or int(body.shape) > 2:
    body.shape = rbsSphere
  if int(body.physicsMode) < 0 or int(body.physicsMode) > 2:
    body.physicsMode = pmFollowBone
  body.shapeSize = repairFinite(body.shapeSize)
  body.shapeSize.x = max(0.0'f32, body.shapeSize.x)
  body.shapeSize.y = max(0.0'f32, body.shapeSize.y)
  body.shapeSize.z = max(0.0'f32, body.shapeSize.z)
  body.shapePosition = repairFinite(body.shapePosition)
  body.shapeRotation = repairFinite(body.shapeRotation)
  body.mass = repairNonNegative(body.mass, 1.0'f32)
  body.moveAttenuation = repairNonNegative(body.moveAttenuation, 0.5'f32)
  body.rotationDamping = repairNonNegative(body.rotationDamping, 0.5'f32)
  body.repulsion = repairNonNegative(body.repulsion)
  body.frictionForce = repairNonNegative(body.frictionForce, 0.5'f32)
