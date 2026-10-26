## Soften rigid weights.
##
## Turns single-bone vertices into two-bone blends that take part of their weight from a second bone, which
## removes the hard seams a rigid rig leaves behind.

import pmxforge

when isMainModule:
  import std/[os, strformat, strutils]

proc soften*(model: PmxModel, blend: float32): int =
  ## Blends every BDEF1 vertex with a neighbor bone and returns how many moved.
  for vertex in model.vertices:
    if vertex.weightDeform.kind != dkBDEF1:
      continue
    let boneIndex = vertex.weightDeform.bdef1.boneIndex1
    if boneIndex < 0 or int(boneIndex) >= model.bones.len:
      continue
    var partner = model.bones[boneIndex].parentBoneIndex
    if partner < 0:
      partner =
        if int(boneIndex) + 1 < model.bones.len:
          boneIndex + 1
        else:
          -1
    if partner < 0:
      continue
    vertex.weightDeform = newBDEF2(boneIndex, partner, 1.0'f32 - blend)
    inc result

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: soften_weights <model.pmx> [model-soft.pmx] [blend]\n" &
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
      directory / (name & "-soft.pmx")
  var blend = 0.25'f32
  if paramCount() >= 3:
    try:
      blend = parseFloat(paramStr(3)).float32
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)
  if blend < 0.0'f32 or blend > 1.0'f32:
    quit("The blend factor must be between 0 and 1.", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  let converted = soften(model, blend)

  model.repair()
  validate(model)
  writePmx(model, output)

  echo fmt"blended {converted} rigid vertices with {blend:.2f} of the other bone"
  echo fmt"wrote {output}"
