## Add morphs.
##
## Adds a vertex morph and a material morph, then registers both in a display slot, which is what a new facial
## expression needs to show up in MMD.

import std/strutils
import pmxforge

when isMainModule:
  import std/[os, strformat]

proc blinkMorph*(upper, lower: int32, drop: float32): Morph =
  ## Pulls two vertices down, the shape of a closing eyelid.
  result = newMorph(
    nameJA = "blink",
    nameEN = "Blink",
    morphType = mtVertex,
    panelType = mptEye,
    offsetData = @[
      MorphOffset(
        kind: moVertex,
        vertex: VertexMorphOffset(
          vertexIndex: upper,
          translation: Vector3(x: 0.0'f32, y: -drop, z: 0.0'f32)
        )
      ),
      MorphOffset(
        kind: moVertex,
        vertex: VertexMorphOffset(
          vertexIndex: lower,
          translation: Vector3(x: 0.0'f32, y: -drop, z: 0.0'f32)
        )
      )
    ]
  )

proc tintMorph*(materialIndex: int32): Morph =
  ## Gives the selected material a subtle blue tint.
  result = newMorph(
    nameJA = "tint",
    nameEN = "Tint",
    morphType = mtMaterial,
    panelType = mptOther,
    offsetData = @[
      MorphOffset(
        kind: moMaterial,
        material: MaterialMorphOffset(
          materialIndex: materialIndex,
          blendMode: mmbMultiply,
          diffuseColor: RGBA(r: 0.6'f32, g: 0.8'f32, b: 1.0'f32, a: 1.0'f32)
        )
      )
    ]
  )

proc register*(model: PmxModel, first, count: int) =
  ## Adds morph frames to the slot named Expressions, or to the first slot.
  var slot = -1
  for index, display in model.displayFrames:
    if display.nameJA.toLowerAscii == "expressions":
      slot = index
      break
  if slot < 0 and model.displayFrames.len > 0:
    slot = 0
  if slot < 0:
    model.displayFrames.add newDisplaySlot(nameJA = "Expressions", nameEN = "")
    slot = model.displayFrames.len - 1
  for index in first ..< first + count:
    model.displayFrames[slot].frames.add newMorphDisplayFrame(int32(index))

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: add_morphs <model.pmx> [model-morphs.pmx]\n" &
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
      directory / (name & "-morphs.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.vertices.len < 2:
    quit("A model with at least two vertices is required.", 1)

  var upper, lower: int32 = 0
  var best = low(float32)
  var runnerUp = low(float32)
  for index, vertex in model.vertices:
    if vertex.position.y > best:
      runnerUp = best
      best = vertex.position.y
      lower = upper
      upper = int32(index)
    elif vertex.position.y > runnerUp:
      runnerUp = vertex.position.y
      lower = int32(index)

  let first = model.morphs.len
  model.morphs.add blinkMorph(upper, lower, 0.05'f32)
  model.morphs.add tintMorph(if model.materials.len > 0: 0'i32 else: -1'i32)
  register(model, first, 2)

  validate(model)
  writePmx(model, output)

  echo fmt"added blink on vertices {upper} and {lower}, plus a material tint"
  echo fmt"wrote {output} ({model.morphs.len} morphs, {model.displayFrames.len} display slots)"
