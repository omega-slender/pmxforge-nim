## Scale a model.
##
## Multiplies every length in the file by a factor, which is what a unit conversion needs: MMD models are
## about 20 units tall for a 1.6 m character.

import std/math
import pmxforge

when isMainModule:
  import std/[os, strformat, strutils]

proc scaleVertices*(model: PmxModel, factor: float32) =
  ## Scales positions and the SDEF correction vectors, which are spatial offsets too.
  ##
  ## A unit conversion needs a finite positive factor; a negative one would silently mirror the model.
  ## UVs stay where they are.
  if classify(factor) in {fcNan, fcInf, fcNegInf} or factor <= 0.0'f32:
    raise newException(ValueError, "Scale factor must be a finite positive number.")
  for vertex in model.vertices:
    vertex.position = vertex.position * factor
    if vertex.weightDeform.kind == dkSDEF:
      vertex.weightDeform.sdef.c = vertex.weightDeform.sdef.c * factor
      vertex.weightDeform.sdef.r0 = vertex.weightDeform.sdef.r0 * factor
      vertex.weightDeform.sdef.r1 = vertex.weightDeform.sdef.r1 * factor

proc scaleBones(model: PmxModel, factor: float32) =
  ## Scales rest positions and tail offsets. Angles and axes stay untouched.
  for bone in model.bones:
    bone.position = bone.position * factor
    bone.tailPosition = bone.tailPosition * factor

proc scalePhysics*(model: PmxModel, factor: float32) =
  ## Scales the distances physics uses, but not the ones measured in radians.
  ##
  ## A joint shares one limit block across all types. Only the components that hold a length for that
  ## type are scaled: ConeTwist keeps damping and span angles there, and Hinge keeps none.
  for body in model.rigidBodies:
    body.shapeSize = body.shapeSize * factor
    body.shapePosition = body.shapePosition * factor
  for joint in model.joints:
    joint.position = joint.position * factor
    let axes = orderedPositionLimitAxes(joint.jointType)
    if 0 in axes:
      joint.positionMinimum.x = joint.positionMinimum.x * factor
      joint.positionMaximum.x = joint.positionMaximum.x * factor
    if 1 in axes:
      joint.positionMinimum.y = joint.positionMinimum.y * factor
      joint.positionMaximum.y = joint.positionMaximum.y * factor
    if 2 in axes:
      joint.positionMinimum.z = joint.positionMinimum.z * factor
      joint.positionMaximum.z = joint.positionMaximum.z * factor
  for body in model.softBodies:
    body.collisionMargin = body.collisionMargin * factor

proc scaleMorphs(model: PmxModel, factor: float32) =
  ## Scales the offsets that carry a translation, leaving rotations alone.
  ##
  ## Offsets are plain values inside a sequence, so they are edited by index.
  for morph in model.morphs:
    for index in 0 ..< morph.offsetData.len:
      case morph.offsetData[index].kind
      of moVertex:
        morph.offsetData[index].vertex.translation = morph.offsetData[index].vertex.translation * factor
      of moBone:
        morph.offsetData[index].bone.translation = morph.offsetData[index].bone.translation * factor
      of moImpulse:
        morph.offsetData[index].impulse.movementSpeed = morph.offsetData[index].impulse.movementSpeed * factor
      else:
        discard

proc heightOf(model: PmxModel): float32 =
  ## Returns the height of the bounding box, for the report.
  if model.vertices.len == 0:
    return 0.0'f32
  var low = model.vertices[0].position.y
  var high = low
  for vertex in model.vertices:
    low = min(low, vertex.position.y)
    high = max(high, vertex.position.y)
  result = high - low

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: transform_vertices <model.pmx> [model-scaled.pmx] [factor]\n" &
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
      directory / (name & "-scaled.pmx")
  var factor = 0.08'f32
  if paramCount() >= 3:
    try:
      factor = parseFloat(paramStr(3)).float32
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)
  if classify(factor) in {fcNan, fcInf, fcNegInf} or factor <= 0.0'f32:
    quit("factor must be a finite positive number", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  let before = heightOf(model)

  scaleVertices(model, factor)
  scaleBones(model, factor)
  scalePhysics(model, factor)
  scaleMorphs(model, factor)

  validate(model)
  writePmx(model, output)

  echo fmt"scaled by {factor:.4f}: height {before:.3f} to {heightOf(model):.3f}"
  echo fmt"wrote {output} ({model.vertices.len} vertices, {model.bones.len} bones, " &
    fmt"{model.rigidBodies.len} rigid bodies)"
