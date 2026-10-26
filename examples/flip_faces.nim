## Flip face winding.
##
## Reverses every triangle, which is what a model with inside-out faces needs. MMD draws a face according to
## the order of its corners, not its normal.

import pmxforge

when isMainModule:
  import std/[os, strformat]

proc flipFaces*(model: PmxModel): int =
  ## Swaps the first and third corner of every triangle.
  for face in model.faces:
    let first = face.vertexIndex1
    face.vertexIndex1 = face.vertexIndex3
    face.vertexIndex3 = first
    inc result

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: flip_faces <model.pmx> [model-flipped.pmx]\n" &
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
      directory / (name & "-flipped.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let flipped = flipFaces(model)

  validate(model)
  writePmx(model, output)

  echo fmt"reversed {flipped} triangles"
  echo fmt"wrote {output}"
