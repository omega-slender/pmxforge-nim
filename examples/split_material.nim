## Split a material.
##
## Divides one material range in two so that half the faces can use another texture, and moves every material
## reference that has to shift with it.

import pmxforge

when isMainModule:
  import std/[os, strformat, strutils]

proc shiftMaterialReferences(model: PmxModel, insertedAt: int) =
  ## Bumps every reference to a material at or after the insertion point.
  for morph in model.morphs:
    for index in 0 ..< morph.offsetData.len:
      if morph.offsetData[index].kind != moMaterial:
        continue
      let target = morph.offsetData[index].material.materialIndex
      if target >= int32(insertedAt):
        morph.offsetData[index].material.materialIndex = target + 1
  for body in model.softBodies:
    if body.materialIndex >= int32(insertedAt):
      body.materialIndex = body.materialIndex + 1

proc splitMaterial*(model: PmxModel, index: int, textureIndex: int32): Material =
  ## Halves a material range and inserts the second half right after it.
  let source = model.materials[index]
  let triangles = int(source.faceCount)
  let firstHalf = triangles div 2
  source.faceCount = int32(firstHalf)

  result = source.copy()
  result.nameJA = source.nameJA & "_b"
  result.nameEN = ""
  result.textureIndex = textureIndex
  result.faceCount = int32(triangles - firstHalf)

  model.materials.insert(result, index + 1)
  shiftMaterialReferences(model, index + 1)

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: split_material <model.pmx> [model-split.pmx] [material] [texture]\n" &
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
      directory / (name & "-split.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.materials.len == 0:
    quit("This model has no materials to split.", 1)

  var materialIndex = 0
  if paramCount() >= 3:
    try:
      materialIndex = parseInt(paramStr(3))
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)
  if materialIndex < 0 or materialIndex >= model.materials.len:
    quit(fmt"Material {materialIndex} does not exist.", 1)
  if model.materials[materialIndex].faceCount < 2:
    quit(fmt"Material {materialIndex} owns too few triangles to split.", 1)

  var textureIndex = model.materials[materialIndex].textureIndex
  if paramCount() >= 4:
    try:
      textureIndex = parseInt(paramStr(4)).int32
    except ValueError:
      quit(fmt"Not a number: {paramStr(4)}", 1)

  let inserted = splitMaterial(model, materialIndex, textureIndex)

  validate(model)
  writePmx(model, output)

  echo fmt"material {materialIndex} keeps " & fmt"{model.materials[materialIndex].faceCount} triangles"
  echo fmt"material {materialIndex + 1} gets {inserted.faceCount} triangles " & fmt"with texture {textureIndex}"
  echo fmt"wrote {output} ({model.materials.len} materials)"
