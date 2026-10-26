## Add physics.
##
## Gives every bone of a rig a rigid body that follows it and joints the bodies into a chain, which is what a
## model needs before MMD will simulate it.

import std/strformat
import pmxforge

when isMainModule:
  import std/[os, strutils]

proc plural(count: int, singular, many: string): string =
  ## Returns "1 body" or "3 bodies".
  if count == 1: fmt"{count} {singular}" else: fmt"{count} {many}"

proc makeBody(model: PmxModel, boneIndex: int32, shape: RigidBodyShape): RigidBody =
  ## Returns a body that follows one bone.
  let bone = model.bones[boneIndex]
  let size = max(0.02'f32, abs(bone.position.y) * 0.2'f32 + 0.02'f32)
  result = newRigidBody(
    nameJA = fmt"body{boneIndex}",
    nameEN = "",
    relatedBoneIndex = boneIndex,
    shape = shape,
    shapeSize = Vector3(x: size, y: size, z: size),
    shapePosition = bone.position,
    mass = 1.0'f32,
    moveAttenuation = 0.5'f32,
    rotationDamping = 0.5'f32,
    repulsion = 0.0'f32,
    frictionForce = 0.5'f32,
    physicsMode = pmFollowBone
  )

proc addPhysics*(model: PmxModel, fromBone: int32): tuple[bodies, joints: int] =
  ## Adds one body per bone from `fromBone` on, and a joint between neighbors.
  let firstBody = model.rigidBodies.len
  for index in int(fromBone) ..< model.bones.len:
    model.rigidBodies.add makeBody(model, int32(index), rbsCapsule)
    inc result.bodies
  var previous = -1
  for index in firstBody ..< model.rigidBodies.len:
    if previous >= 0:
      model.joints.add newJoint(
        nameJA = fmt"joint{index}",
        nameEN = "",
        rigidBodyIndexA = int32(previous),
        rigidBodyIndexB = int32(index)
      )
      inc result.joints
    previous = index

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: add_physics <model.pmx> [model-physics.pmx] [first-bone]\n" &
        "Generate a sample first: nim c -r examples/make_sample.nim",
      1)
  let input = paramStr(1)
  if not fileExists(input):
    quit(fmt"No such file: {input}", 1)
  let (directory, name, _) = splitFile(input)
  let output =
    if paramCount() >= 2:
      paramStr(2)
    else:
      directory / (name & "-physics.pmx")
  var firstBone = 0
  if paramCount() >= 3:
    try:
      firstBone = parseInt(paramStr(3))
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.bones.len == 0:
    quit("This model has no bones to build physics for.", 1)
  if firstBone < 0 or firstBone >= model.bones.len:
    quit(fmt"Bone {firstBone} does not exist.", 1)

  let added = addPhysics(model, int32(firstBone))

  validate(model)
  writePmx(model, output)

  echo &"added {plural(added.bodies, \"body\", \"bodies\")} and " &
    &"{plural(added.joints, \"joint\", \"joints\")} from bone {firstBone}"
  echo fmt"wrote {output} ({model.rigidBodies.len} rigid bodies, {model.joints.len} joints)"
