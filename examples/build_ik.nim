## Build an IK chain.
##
## Turns the last bones of a model into an inverse kinematics chain: one bone drives the chain, one is the
## effector, and the bones in between get limits.

import std/[strformat, strutils]
import pmxforge

when isMainModule:
  import std/os

proc plural(count: int, singular, many: string): string =
  ## Returns "1 link" or "3 links".
  if count == 1: fmt"{count} {singular}" else: fmt"{count} {many}"

proc buildIk*(model: PmxModel, rootIndex, targetIndex: int32, limit: float32, iterations: int32) =
  ## Marks the driver bone as an IK controller and links the bones between it and the effector.
  var links: seq[IKLink] = @[]
  var index = rootIndex + 1
  while index < targetIndex:
    links.add newLimitedIKLink(
      index, Vector3(x: -limit, y: -limit, z: -limit), Vector3(x: limit, y: limit, z: limit))
    inc index
  var flags = model.bones[rootIndex].flags
  flags.ik = true
  model.bones[rootIndex].flags = flags
  model.bones[rootIndex].ik = newBoneIK(
    targetIndex = targetIndex,
    loopCount = iterations,
    limitAngle = 2.0'f32,
    links = links
  )

proc favouriteSlot(model: PmxModel): int =
  ## Returns the slot the new chain should appear in, or -1 when there is none.
  for index, slot in model.displayFrames:
    if slot.nameJA.toLowerAscii == "root":
      return index
  if model.displayFrames.len > 0:
    return 0
  result = -1

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: build_ik <model.pmx> [model-ik.pmx] [iterations]\n" &
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
      directory / (name & "-ik.pmx")
  var iterations = 40'i32
  if paramCount() >= 3:
    try:
      iterations = parseInt(paramStr(3)).int32
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.bones.len < 3:
    quit("This model needs at least three bones for an IK chain.", 1)

  let rootIndex = int32(model.bones.len - 3)
  let targetIndex = int32(model.bones.len - 1)
  buildIk(model, rootIndex, targetIndex, 0.5'f32, iterations)

  let slot = favouriteSlot(model)
  if slot >= 0:
    model.displayFrames[slot].frames.add newBoneDisplayFrame(rootIndex)

  validate(model)
  writePmx(model, output)

  echo fmt"bone {rootIndex} now drives bone {targetIndex} with " &
    &"{plural(model.bones[rootIndex].ik.links.len, \"link\", \"links\")} " & fmt"and {iterations} iterations"
  echo fmt"wrote {output}"
