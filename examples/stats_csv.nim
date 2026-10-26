## Model statistics as CSV.
##
## Walks a directory of PMX files and writes one row per model, which is what a
## catalog or a model review needs.

import std/[os, strformat, strutils]
import pmxforge

const
  Header* = "file,version,encoding,vertices,triangles,materials,bones,morphs," &
            "rigid_bodies,joints,soft_bodies,valid" ## Column names of the table.

proc versionName(model: PmxModel): string =
  ## Returns the format version as a short word.
  if model.version == pmx21: "2.1" else: "2.0"

proc encodingName(model: PmxModel): string =
  ## Returns the text encoding as a short word.
  if model.textEncoding == teUTF8: "utf8" else: "utf16le"

proc quote(text: string): string =
  ## Returns a field that survives commas and quotes in a name.
  result = '"' & text.replace("\"", "\"\"") & '"'

proc row*(model: PmxModel, path: string): string =
  ## Returns one CSV line for a model.
  result =
    fmt"{quote(extractFilename(path))},{versionName(model)}," &
    fmt"{encodingName(model)},{model.vertices.len},{model.faces.len}," &
    fmt"{model.materials.len},{model.bones.len},{model.morphs.len}," &
    fmt"{model.rigidBodies.len},{model.joints.len},{model.softBodies.len}," & fmt"{model.isValid()}"

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: stats_csv <input-dir> [models.csv]\n" &
        "Generate a sample first: nim c -r examples/make_sample.nim",
      1)
  let inputDirectory = paramStr(1)
  if not dirExists(inputDirectory):
    quit(fmt"No such directory: {inputDirectory}", 1)
  let output =
    if paramCount() >= 2:
      paramStr(2)
    else:
      inputDirectory / "models.csv"

  var lines: seq[string] = @[Header]
  var failed = 0
  for kind, path in walkDir(inputDirectory):
    if kind != pcFile or not path.toLowerAscii.endsWith(".pmx"):
      continue
    try:
      let model = readPmx(path, SafePmxReadLimits)
      lines.add row(model, path)
    except ValueError, IOError, OSError:
      inc failed
      lines.add fmt"{quote(extractFilename(path))},,,,,,,,,,,unreadable"

  writeFile(output, lines.join("\n") & "\n")

  echo fmt"wrote {output} with {lines.len - 1} models ({failed} unreadable)"
  echo lines[0]
  for index in 1 ..< min(lines.len, 4):
    echo lines[index]
