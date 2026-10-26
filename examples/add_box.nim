## Append a box.
##
## Adds a cube to an existing model and registers the material that draws it, so a prop or a marker can be
## dropped into a finished model.

import pmxforge

when isMainModule:
  import std/[os, strformat]

type
  BoxFace = object ## One side of the cube, as two basis vectors.
    normal: Vector3 ## Outward normal.
    u, v: Vector3 ## In-plane axes, chosen so that `u x v` equals the normal.

const
  BoxSides = [ ## The six sides of a unit cube.
    BoxFace(
      normal: Vector3(x: 0.0'f32, y: 0.0'f32, z: 1.0'f32),
      u: Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      v: Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32)
    ),
    BoxFace(
      normal: Vector3(x: 0.0'f32, y: 0.0'f32, z: -1.0'f32),
      u: Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.0'f32),
      v: Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32)
    ),
    BoxFace(
      normal: Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      u: Vector3(x: 0.0'f32, y: 0.0'f32, z: -1.0'f32),
      v: Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32)
    ),
    BoxFace(
      normal: Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.0'f32),
      u: Vector3(x: 0.0'f32, y: 0.0'f32, z: 1.0'f32),
      v: Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32)
    ),
    BoxFace(
      normal: Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32),
      u: Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      v: Vector3(x: 0.0'f32, y: 0.0'f32, z: -1.0'f32)
    ),
    BoxFace(
      normal: Vector3(x: 0.0'f32, y: -1.0'f32, z: 0.0'f32),
      u: Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      v: Vector3(x: 0.0'f32, y: 0.0'f32, z: 1.0'f32)
    )
  ]

const
  CornerU = [-0.5'f32, 0.5'f32, 0.5'f32, -0.5'f32] ## U offset of each corner.
  CornerV = [-0.5'f32, -0.5'f32, 0.5'f32, 0.5'f32] ## V offset of each corner.

proc cornerOffset(face: BoxFace, corner: int): Vector3 =
  ## Returns where a corner sits inside its side, in half-size units.
  result = Vector3(
    x: face.normal.x + CornerU[corner] * face.u.x + CornerV[corner] * face.v.x,
    y: face.normal.y + CornerU[corner] * face.u.y + CornerV[corner] * face.v.y,
    z: face.normal.z + CornerU[corner] * face.u.z + CornerV[corner] * face.v.z
  )

proc boxCorner(face: BoxFace, center: Vector3, size: float32, corner: int): Vector3 =
  ## Returns one corner of a side, in the order the winding expects.
  result = center + cornerOffset(face, corner) * (size * 0.5'f32)

proc meshCenter*(model: PmxModel): Vector3 =
  ## Returns the center of the bounding box around every vertex.
  if model.vertices.len == 0:
    return Vector3.zero
  var low = model.vertices[0].position
  var high = low
  for vertex in model.vertices:
    low.x = min(low.x, vertex.position.x)
    low.y = min(low.y, vertex.position.y)
    low.z = min(low.z, vertex.position.z)
    high.x = max(high.x, vertex.position.x)
    high.y = max(high.y, vertex.position.y)
    high.z = max(high.z, vertex.position.z)
  result = Vector3(
    x: (low.x + high.x) / 2.0'f32,
    y: (low.y + high.y) / 2.0'f32,
    z: (low.z + high.z) / 2.0'f32
  )

proc appendBox*(model: PmxModel, center: Vector3, size: float32, textureIndex: int32): int =
  ## Adds the cube, its faces, and its material. Returns the material index.
  let boneIndex = if model.bones.len > 0: 0'i32 else: -1'i32
  for side in BoxSides:
    let first = int32(model.vertices.len)
    for corner in 0 .. 3:
      model.vertices.add newVertex(
        position = boxCorner(side, center, size, corner),
        normal = side.normal,
        uv = Vector2(x: CornerU[corner] + 0.5'f32, y: CornerV[corner] + 0.5'f32),
        weightDeform = newBDEF1(boneIndex)
      )
    model.faces.add newFace(first, first + 1, first + 2)
    model.faces.add newFace(first, first + 2, first + 3)
  result = model.materials.len
  model.materials.add newMaterial(
    nameJA = "box",
    nameEN = "box",
    textureIndex = textureIndex,
    flags = MaterialFlags(edge: true, groundShadow: true),
    faceCount = 12'i32
  )

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: add_box <model.pmx> [model-boxed.pmx]\n" &
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
      directory / (name & "-boxed.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let center = meshCenter(model)
  let size = 0.25'f32
  let texture = if model.textures.len > 0: 0'i32 else: -1'i32
  let materialIndex = appendBox(model, center, size, texture)

  validate(model)
  writePmx(model, output)

  echo fmt"added a {size:.2f} box at the mesh center as material {materialIndex}"
  echo fmt"wrote {output}: {model.vertices.len} vertices, {model.faces.len} triangles"
