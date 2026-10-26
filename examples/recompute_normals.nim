## Recompute normals.
##
## Builds smooth vertex normals from the triangles, which is the fix for the flat or inverted
## shading that damaged models show.

import pmxforge

when isMainModule:
  import std/[os, strformat]

proc faceNormal(model: PmxModel, face: Face): Vector3 =
  ## Returns the geometric normal of one triangle, or zero when it is degenerate.
  let corners = face.getIndices()
  for index in corners:
    if index < 0 or int(index) >= model.vertices.len:
      return Vector3.zero
  let a = model.vertices[corners[0]].position
  let b = model.vertices[corners[1]].position
  let c = model.vertices[corners[2]].position
  result = cross(b - a, c - a)
  if result.length() < Epsilon:
    return Vector3.zero
  result = result.normalize()

proc recompute*(model: PmxModel): tuple[changed: int, worst: float32] =
  ## Accumulates face normals per vertex and reports how far they moved.
  var accumulated = newSeq[Vector3](model.vertices.len)
  for face in model.faces:
    let normal = faceNormal(model, face)
    for index in face.getIndices():
      if index >= 0 and int(index) < accumulated.len:
        accumulated[index] = accumulated[index] + normal
  result = (changed: 0, worst: 0.0'f32)
  for index, vertex in model.vertices:
    var smooth = accumulated[index]
    if smooth.length() < Epsilon:
      continue
    smooth = smooth.normalize()
    let moved = (smooth - vertex.normal).length()
    if moved > 0.0001'f32:
      inc result.changed
    result.worst = max(result.worst, moved)
    vertex.normal = smooth

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: recompute_normals <model.pmx> [model-normals.pmx]\n" &
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
      directory / (name & "-normals.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let summary = recompute(model)

  validate(model)
  writePmx(model, output)

  echo fmt"updated {summary.changed} of {model.vertices.len} normals, " &
    fmt"largest change {summary.worst:.4f}"
  echo fmt"wrote {output}"
