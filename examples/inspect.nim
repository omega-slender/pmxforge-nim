## Model inspector.
##
## Opens a PMX file and prints what is inside it: bounds, materials, the bone tree, the morphs, the physics,
## and the validator verdict.

import std/[os, strformat, strutils]
import pmxforge

proc isInsideDirectory(root, candidate: string): bool =
  ## Returns true when `candidate` is `root` or a file under it after canonicalization.
  let base = normalizedPath(absolutePath(root)).strip(chars = {DirSep}, leading = false)
  let target = normalizedPath(absolutePath(candidate))
  if target == base:
    return true
  result = target.startsWith(base & $DirSep)

proc resolveTexture*(model: PmxModel, path: string): string =
  ## Returns a texture path under the model directory, or "" when the string would
  ## walk out of it (`..`, an absolute path, or a drive-relative path).
  if model.directory.len == 0 or path.len == 0 or '\0' in path:
    return ""
  var relative = path.replace('\\', '/')
  if isAbsolute(relative) or relative.startsWith('/') or relative.startsWith('\\'):
    return ""
  if relative.len >= 2 and relative[1] == ':':
    return ""
  for part in relative.split('/'):
    if part == "..":
      return ""
  let joined = model.directory / relative.replace('/', DirSep)
  if not isInsideDirectory(model.directory, joined):
    return ""
  result = joined

proc bounds(model: PmxModel): tuple[low, high: Vector3] =
  ## Returns the axis-aligned box that contains every vertex.
  if model.vertices.len == 0:
    return (Vector3.zero, Vector3.zero)
  result = (low: model.vertices[0].position, high: model.vertices[0].position)
  for vertex in model.vertices:
    result.low.x = min(result.low.x, vertex.position.x)
    result.low.y = min(result.low.y, vertex.position.y)
    result.low.z = min(result.low.z, vertex.position.z)
    result.high.x = max(result.high.x, vertex.position.x)
    result.high.y = max(result.high.y, vertex.position.y)
    result.high.z = max(result.high.z, vertex.position.z)

proc countLabel(count: int, singular, many: string): string =
  ## Returns "1 bone" or "4 bones", so the report reads like English.
  if count == 1: fmt"{count} {singular}" else: fmt"{count} {many}"

proc printHeader(model: PmxModel, path: string) =
  ## Prints the file level fields and the geometry size.
  let box = bounds(model)
  let encoding = if model.textEncoding == teUTF8: "UTF-8" else: "UTF-16LE"
  echo fmt"file        {path}"
  echo fmt"version     PMX {toFileVersion(model.version)}, {encoding}"
  echo fmt"names       {model.nameJA} / {model.nameEN}"
  echo fmt"comments    {model.commentsJA.len} / {model.commentsEN.len} bytes"
  echo fmt"extra UVs   {model.additionalUvCount}"
  echo fmt"bounds      x {box.low.x:.3f} to {box.high.x:.3f}, " &
    fmt"y {box.low.y:.3f} to {box.high.y:.3f}, z {box.low.z:.3f} to {box.high.z:.3f}"
  echo &"sections    {countLabel(model.vertices.len, \"vertex\", \"vertices\")}, " &
    &"{countLabel(model.faces.len, \"triangle\", \"triangles\")}, " &
    &"{countLabel(model.materials.len, \"material\", \"materials\")}"
  echo &"            {countLabel(model.bones.len, \"bone\", \"bones\")}, " &
    &"{countLabel(model.morphs.len, \"morph\", \"morphs\")}, " &
    &"{countLabel(model.displayFrames.len, \"display slot\", \"display slots\")}"
  echo &"            {countLabel(model.rigidBodies.len, \"rigid body\", \"rigid bodies\")}, " &
    &"{countLabel(model.joints.len, \"joint\", \"joints\")}, " &
    &"{countLabel(model.softBodies.len, \"soft body\", \"soft bodies\")}"

proc printTextures(model: PmxModel) =
  ## Lists every texture and whether the file is next to the model.
  if model.textures.len == 0:
    echo "textures    none"
    return
  echo fmt"textures    {model.textures.len}"
  for index, texture in model.textures:
    let resolved = resolveTexture(model, texture.path)
    let state =
      if resolved.len == 0: "blocked"
      elif fileExists(resolved): "found"
      else: "missing"
    echo fmt"  [{index}] {state}  {texture.path}"

proc printMaterials(model: PmxModel) =
  ## Prints each material range, its textures, and the flags that matter.
  for index, material in model.materials:
    var flags: seq[string] = @[]
    if material.flags.bothFace:
      flags.add "both faces"
    if material.flags.edge:
      flags.add "outline"
    if material.flags.groundShadow:
      flags.add "shadow"
    if material.flags.vertexColor:
      flags.add "vertex color"
    echo fmt"  [{index}] {material.nameJA}, {material.faceCount} triangles, " &
      fmt"alpha {material.alpha:.2f}"
    echo fmt"      diffuse {material.textureIndex}, " &
      fmt"sphere {material.sphereTextureIndex} ({material.sphereBlendMode}), " &
      fmt"toon {material.toonTextureIndex}"
    if flags.len > 0:
      echo &"      flags {flags.join(\", \")}"

proc printBoneTree(model: PmxModel, index, depth: int) =
  ## Prints one bone and then everything that hangs below it.
  if index < 0 or index >= model.bones.len or depth > model.bones.len:
    return
  let bone = model.bones[index]
  var marks: seq[string] = @[]
  if bone.flags.ik:
    marks.add "ik"
  if bone.hasTailBone:
    marks.add fmt"tail {bone.tailIndex}"
  if bone.inheritParentIndex >= 0:
    marks.add fmt"inherit {bone.inheritParentIndex}"
  let suffix = if marks.len > 0: " " & marks.join(", ") else: ""
  echo fmt"{repeat(' ', 2 + depth * 2)}[{index}] {bone.nameJA}{suffix}"
  for childIndex in 0 ..< model.bones.len:
    if model.bones[childIndex].parentBoneIndex == int32(index):
      printBoneTree(model, childIndex, depth + 1)

proc printBones(model: PmxModel) =
  ## Walks the hierarchy from every root bone.
  echo fmt"bones       {model.bones.len}"
  for index in 0 ..< model.bones.len:
    if not model.bones[index].hasParent:
      printBoneTree(model, index, 0)

proc printMorphs(model: PmxModel) =
  ## Groups the morphs by the panel MMD shows them in.
  if model.morphs.len == 0:
    echo "morphs      none"
    return
  echo fmt"morphs      {model.morphs.len}"
  for panel in MorphPanelType:
    var names: seq[string] = @[]
    var count = 0
    for index, morph in model.morphs:
      if morph.panelType == panel:
        inc count
        if names.len < 8:
          names.add fmt"{index}:{morph.nameJA} ({morph.morphType})"
    if count > 0:
      echo fmt"  {panel}  {count}"
      echo &"      {names.join(\", \")}"

proc printPhysics(model: PmxModel) =
  ## Summarizes the rigid bodies, joints, and soft bodies.
  if model.rigidBodies.len + model.joints.len + model.softBodies.len == 0:
    echo "physics     none"
    return
  echo fmt"physics     " & &"{countLabel(model.rigidBodies.len, \"rigid body\", \"rigid bodies\")}, " &
    &"{countLabel(model.joints.len, \"joint\", \"joints\")}, " &
    &"{countLabel(model.softBodies.len, \"soft body\", \"soft bodies\")}"
  for index, body in model.rigidBodies:
    echo fmt"  body  [{index}] {body.nameJA}, {body.shape}, {body.physicsMode}, " &
      fmt"bone {body.relatedBoneIndex}, group {body.groupId}"
  for index, joint in model.joints:
    echo fmt"  joint [{index}] {joint.nameJA}, {joint.jointType}, " &
      fmt"body {joint.rigidBodyIndexA} to {joint.rigidBodyIndexB}"
  for index, body in model.softBodies:
    echo fmt"  soft  [{index}] {body.nameJA}, {body.numberOfClusters} clusters, " &
      fmt"{body.vertexPins.len} pins, " & &"{countLabel(body.anchorRigidBodies.len, \"anchor\", \"anchors\")}"

proc printValidation(model: PmxModel) =
  ## Runs the strict validator and reports the first problem it finds.
  try:
    validate(model)
    echo "validation  ok"
  except ValueError as error:
    echo fmt"validation  failed: {error.msg}"
    echo fmt"write safe  {isValid(model, strict = false)}"

when isMainModule:
  if paramCount() < 1:
    quit("usage: inspect <model.pmx>\n" & "Generate a sample first: nim c -r examples/make_sample.nim", 1)

  let path = paramStr(1)
  if not fileExists(path):
    quit(fmt"No such file: {path}", 1)

  let model = readPmx(path, DesktopPmxReadLimits)

  printHeader(model, path)
  printTextures(model)
  printMaterials(model)
  printBones(model)
  printMorphs(model)
  printPhysics(model)
  printValidation(model)
