## Add a bone chain.
##
## Appends a chain of bones to a model and registers it in the first display slot, which is what a prop, a
## tail, or a hair strand needs before it can be animated.

import std/strformat
import pmxforge

when isMainModule:
  import std/[os, strutils]

proc topOf(model: PmxModel): float32 =
  ## Returns the highest vertex, where an accessory chain usually starts.
  result = 0.0'f32
  for vertex in model.vertices:
    result = max(result, vertex.position.y)

proc addChain*(model: PmxModel, count: int, segment: float32): seq[int32] =
  ## Adds `count` bones stacked upwards and returns their indices.
  let parent = if model.bones.len > 0: 0'i32 else: -1'i32
  var height = topOf(model)
  var previous = parent
  for index in 0 ..< count:
    height = height + segment
    let bone = newBone(
      nameJA = fmt"chain{index}",
      nameEN = fmt"chain{index}",
      position = Vector3(x: 0.0'f32, y: height, z: 0.0'f32),
      parentBoneIndex = previous,
      layer = 1'i32
    )
    model.bones.add bone
    previous = int32(model.bones.len - 1)
    result.add previous
  if model.displayFrames.len > 0:
    for index in result:
      model.displayFrames[0].frames.add newBoneDisplayFrame(index)

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: add_bone_chain <model.pmx> [model-chain.pmx] [bones]\n" &
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
      directory / (name & "-chain.pmx")
  var count = 3
  if paramCount() >= 3:
    try:
      count = parseInt(paramStr(3))
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)
  if count < 1 or count > 64:
    quit("The bone count must be between 1 and 64.", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  let added = addChain(model, count, 0.1'f32)

  validate(model)
  writePmx(model, output)

  echo fmt"added {added.len} bones: {added[0]} to {added[^1]}"
  echo fmt"wrote {output} ({model.bones.len} bones, {model.displayFrames.len} display slots)"
