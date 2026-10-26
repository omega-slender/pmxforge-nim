## Strip physics.
##
## Removes the rigid bodies, the joints, and the soft bodies, which is what a static export or a model that a
## game engine drives itself needs.

import std/strformat
import pmxforge

when isMainModule:
  import std/os

proc plural(count: int, singular, many: string): string =
  ## Returns "1 joint" or "3 joints".
  if count == 1: fmt"{count} {singular}" else: fmt"{count} {many}"

proc stripPhysics*(model: PmxModel): tuple[bodies, joints, softBodies: int] =
  ## Clears rigid bodies, joints, and soft bodies. Returns the counts that were removed.
  result = (bodies: model.rigidBodies.len, joints: model.joints.len, softBodies: model.softBodies.len)
  model.rigidBodies = @[]
  model.joints = @[]
  model.softBodies = @[]

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: strip_physics <model.pmx> [model-static.pmx]\n" &
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
      directory / (name & "-static.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let needed21 = isPmx21Only(model)
  let removed = stripPhysics(model)

  validate(model)
  writePmx(model, output)

  echo &"removed {plural(removed.bodies, \"rigid body\", \"rigid bodies\")}, " &
    &"{plural(removed.joints, \"joint\", \"joints\")}, " &
    &"{plural(removed.softBodies, \"soft body\", \"soft bodies\")}"
  if needed21 and not isPmx21Only(model):
    echo "the model fits PMX 2.0 now, so downgrade_20 can finish the job"
  echo fmt"wrote {output}"
