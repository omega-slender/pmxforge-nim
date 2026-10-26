## Fix texture paths.
##
## Normalizes the texture table the way a model needs before it moves to another operating system: forward
## slashes, no duplicates, no unused entries.

import std/[strutils, tables]
import pmxforge

proc normalize*(path: string): string =
  ## Returns the path with forward slashes and without a leading dot slash.
  result = path.replace('\\', '/')
  while result.startsWith("./"):
    result = result[2 .. ^1]

func remappedTexture(index: int32, oldToDeduped, dedupedToFinal: seq[int32]): int32 =
  ## Maps an old texture index through deduplication and pruning. References that were
  ## already out of range are returned unchanged, so `validate` still reports them.
  if index >= 0 and int(index) < oldToDeduped.len:
    dedupedToFinal[int(oldToDeduped[index])]
  else:
    index

proc fixPaths*(model: PmxModel): tuple[renamed, merged, removed: int] =
  ## Rewrites the texture table and remaps every material reference to it: paths are
  ## normalized, duplicates merged, and entries no material uses are removed.
  var seen = initTable[string, int32]()
  var oldToDeduped = newSeq[int32](model.textures.len)
  var deduped: seq[Texture] = @[]
  for index, texture in model.textures:
    let path = normalize(texture.path)
    if path != texture.path:
      inc result.renamed
    if seen.hasKey(path):
      oldToDeduped[index] = seen[path]
      inc result.merged
      continue
    oldToDeduped[index] = int32(deduped.len)
    seen[path] = oldToDeduped[index]
    deduped.add newTexture(path)

  var usedOld = newSeq[bool](model.textures.len)
  template mark(index: int32) =
    ## Records that a material references this old table slot.
    if index >= 0 and int(index) < usedOld.len:
      usedOld[int(index)] = true
  for material in model.materials:
    mark(material.textureIndex)
    mark(material.sphereTextureIndex)
    if not material.internalToon:
      mark(material.toonTextureIndex)
  var used = newSeq[bool](deduped.len)
  for index, referenced in usedOld:
    if referenced:
      used[int(oldToDeduped[index])] = true

  var dedupedToFinal = newSeq[int32](deduped.len)
  var kept: seq[Texture] = @[]
  for index, texture in deduped:
    if used[index]:
      dedupedToFinal[index] = int32(kept.len)
      kept.add texture
    else:
      dedupedToFinal[index] = -1
  result.removed = deduped.len - kept.len

  for material in model.materials:
    material.textureIndex = remappedTexture(material.textureIndex, oldToDeduped, dedupedToFinal)
    material.sphereTextureIndex =
      remappedTexture(material.sphereTextureIndex, oldToDeduped, dedupedToFinal)
    if not material.internalToon:
      material.toonTextureIndex =
        remappedTexture(material.toonTextureIndex, oldToDeduped, dedupedToFinal)
  model.textures = kept

when isMainModule:
  import std/[os, strformat]

  if paramCount() < 1:
    quit(
      "usage: fix_texture_paths <model.pmx> [model-paths.pmx]\n" &
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
      directory / (name & "-paths.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let before = model.textures.len
  let summary = fixPaths(model)

  try:
    validate(model)
    writePmx(model, output)
  except CatchableError as error:
    quit(fmt"cannot write '{output}': {error.msg}", 1)

  echo fmt"textures {before} to {model.textures.len}: " &
    fmt"{summary.renamed} renamed, {summary.merged} merged, {summary.removed} unused removed"
  for index, texture in model.textures:
    let state =
      if fileExists(model.directory / texture.path): "found"
      else: "missing"
    echo fmt"  [{index}] {state}  {texture.path}"
  echo fmt"wrote {output}"
