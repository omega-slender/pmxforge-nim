## Mirror a static mesh.
##
## Appends a copy of the geometry across the X axis, which is the workflow of modeling one half of a
## prop. Rigging is not duplicated: bones, morphs, display slots, and physics would all need their
## indices remapped, so this example refuses a rigged model instead of producing one that validates but
## deforms wrongly.

import pmxforge

when isMainModule:
  import std/[os, strformat]

proc mirroredVertex*(source: Vertex): Vertex =
  ## Returns a copy of a vertex reflected across the X axis, keeping every attribute the wire carries.
  ##
  ## Copying the source instead of rebuilding it preserves `edgeScale` and the additional UV channels,
  ## which `newVertex` defaults would silently reset.
  result = source.copy()
  result.position.x = -result.position.x
  result.normal.x = -result.normal.x
  result.uv.x = 1.0'f32 - result.uv.x
  if result.weightDeform.kind == dkSDEF:
    result.weightDeform.sdef.c.x = -result.weightDeform.sdef.c.x
    result.weightDeform.sdef.r0.x = -result.weightDeform.sdef.r0.x
    result.weightDeform.sdef.r1.x = -result.weightDeform.sdef.r1.x

proc mirrorMesh*(model: PmxModel) =
  ## Appends the geometry reflected across the X axis and refuses a rigged model.
  if model.bones.len > 0 or model.morphs.len > 0 or model.displayFrames.len > 0 or
      model.rigidBodies.len > 0 or model.joints.len > 0 or model.softBodies.len > 0:
    raise newException(
      ValueError,
      "mirror_mesh only supports static meshes; this model has bones, morphs, display slots, or " &
        "physics. Duplicate and remap the rig before mirroring the mesh.")

  let originalVertices = model.vertices.len
  let originalFaces = model.faces.len
  for index in 0 ..< originalVertices:
    model.vertices.add mirroredVertex(model.vertices[index])

  var cursor = 0
  var mirroredMaterials: seq[Material] = @[]
  for material in model.materials:
    let last = min(cursor + int(material.faceCount), originalFaces)
    var added = 0
    while cursor < last:
      let face = model.faces[cursor]
      model.faces.add newFace(
        face.vertexIndex3 + int32(originalVertices), face.vertexIndex2 + int32(originalVertices),
        face.vertexIndex1 + int32(originalVertices))
      inc cursor
      inc added
    mirroredMaterials.add material.copy()
    mirroredMaterials[^1].faceCount = int32(added)
  for material in mirroredMaterials:
    model.materials.add material

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: mirror_mesh <static-model.pmx> [model-mirrored.pmx]\n" &
        "The input must be a static mesh: no bones, morphs, display slots, or physics.",
      1)
  let input = paramStr(1)
  if not fileExists(input):
    quit(fmt"No such file: {input}", 1)
  let (directory, name, _) = splitFile(input)
  let output =
    if paramCount() >= 2:
      paramStr(2)
    else:
      directory / (name & "-mirrored.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let verticesBefore = model.vertices.len
  let materialsBefore = model.materials.len

  try:
    mirrorMesh(model)
  except ValueError as exc:
    quit(exc.msg, 1)

  validate(model)
  writePmx(model, output)

  echo fmt"vertices {verticesBefore} to {model.vertices.len}, " &
    fmt"materials {materialsBefore} to {model.materials.len}"
  echo fmt"wrote {output} (static mesh mirrored across X; the rig is not duplicated)"
