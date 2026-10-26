## Retint materials.
##
## Multiplies every color in the file and rewrites the outline settings, which is how a recolor or a
## brightness pass is done without touching the textures.

import std/[os, strformat, strutils]
import pmxforge

proc retint*(model: PmxModel, factor: float32, alpha: float32, edgeScale: float32): int =
  ## Scales diffuse, ambient, and specular colors, and sets the outline.
  for material in model.materials:
    material.diffuseColor = RGB(
      r: material.diffuseColor.r * factor,
      g: material.diffuseColor.g * factor,
      b: material.diffuseColor.b * factor
    ).clamp01()
    material.ambientColor = RGB(
      r: material.ambientColor.r * factor,
      g: material.ambientColor.g * factor,
      b: material.ambientColor.b * factor
    ).clamp01()
    material.specularColor = RGB(
      r: material.specularColor.r * factor,
      g: material.specularColor.g * factor,
      b: material.specularColor.b * factor
    ).clamp01()
    material.alpha = alpha
    material.edgeScale = edgeScale
    material.flags.edge = edgeScale > 0.0'f32
    inc result

proc numberAt(position: int, fallback: float32): float32 =
  ## Returns an argument as a float, or the fallback when it is absent.
  if paramCount() < position:
    return fallback
  try:
    result = parseFloat(paramStr(position)).float32
  except ValueError:
    quit(fmt"Not a number: {paramStr(position)}", 1)

proc plural(count: int, singular, many: string): string =
  ## Returns "1 material" or "3 materials".
  if count == 1: fmt"{count} {singular}" else: fmt"{count} {many}"

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: retint_materials <model.pmx> [model-tinted.pmx] " & "[factor] [alpha] [edge]\n" &
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
      directory / (name & "-tinted.pmx")

  let factor = numberAt(3, 0.8'f32)
  let alpha = numberAt(4, 1.0'f32)
  let edgeScale = numberAt(5, 1.5'f32)

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.materials.len == 0:
    quit("This model has no materials to retint.", 1)
  let touched = retint(model, factor, alpha, edgeScale)

  validate(model)
  writePmx(model, output)

  echo &"retinted {plural(touched, \"material\", \"materials\")} by {factor:.2f}, " &
    fmt"alpha {alpha:.2f}, edge {edgeScale:.2f}"
  echo fmt"wrote {output}"
