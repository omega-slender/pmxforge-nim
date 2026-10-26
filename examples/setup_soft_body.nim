## Set up a soft body.
##
## Replaces the soft body section with one built from the current geometry: the chosen row is pinned, and the
## first rigid body anchors the mesh.

import pmxforge

when isMainModule:
  import std/[os, strformat, strutils]

proc rowVertices*(model: PmxModel, row, columns: int): seq[int32] =
  ## Returns the vertex indices of one row of a grid.
  for column in 0 .. columns:
    let index = row * (columns + 1) + column
    if index < model.vertices.len:
      result.add int32(index)

proc buildSoftBody*(model: PmxModel, pins: seq[int32]): SoftBody =
  ## Returns a soft body that covers the mesh and uses the first body as anchor.
  var anchors: seq[AnchorRigidBody] = @[]
  if model.rigidBodies.len > 0:
    for index in pins:
      anchors.add AnchorRigidBody(rigidBodyIndex: 0'i32, vertexIndex: index)
  result = newSoftBody(
    nameJA = "soft",
    nameEN = "",
    materialIndex = (if model.materials.len > 0: 0'i32 else: -1'i32),
    shape = sbshTriMesh,
    groupId = 1'i32,
    flags = SoftBodyFlags(bLink: true, cluster: true),
    bLinkCreateDistance = 1'i32,
    numberOfClusters = max(1'i32, int32(pins.len div 2)),
    totalMass = 1.0'f32,
    collisionMargin = 0.01'f32,
    anchorRigidBodies = anchors,
    vertexPins = pins
  )

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: setup_soft_body <model.pmx> [model-soft.pmx] [row]\n" &
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
      directory / (name & "-softbody.pmx")
  var row = 0
  if paramCount() >= 3:
    try:
      row = parseInt(paramStr(3))
    except ValueError:
      quit(fmt"Not a number: {paramStr(3)}", 1)

  let model = readPmx(input, DesktopPmxReadLimits)
  if model.vertices.len == 0:
    quit("This model has no vertices to simulate.", 1)

  var columns = 1
  while (columns + 1) * (columns + 1) <= model.vertices.len:
    inc columns
  let pins = rowVertices(model, row, columns)
  if pins.len == 0:
    quit(fmt"Row {row} is past the end of a {columns + 1} wide grid.", 1)

  model.softBodies = @[]
  model.softBodies.add buildSoftBody(model, pins)

  validate(model)
  writePmx(model, output)

  echo fmt"soft body over {model.vertices.len} vertices with {pins.len} pins and " &
    fmt"{model.softBodies[0].anchorRigidBodies.len} anchors"
  echo fmt"wrote {output}"
