## Rename a model.
##
## Sets the model name and the comments, which is how an edited file is tagged without touching its geometry.

import std/strformat
import pmxforge

when isMainModule:
  import std/os

proc renameModel*(model: PmxModel, newName: string): string =
  ## Sets Japanese and English names. Returns the previous Japanese name.
  if newName.len == 0:
    raise newException(ValueError, "The new name must not be empty.")
  result = model.nameJA
  model.nameJA = newName
  model.nameEN = newName
  model.commentsEN = fmt"Renamed from '{result}' by the rename_model example."
  if model.commentsJA.len == 0:
    model.commentsJA = newName

when isMainModule:
  if paramCount() < 2:
    quit(
      "usage: rename_model <model.pmx> <new-name> [model-named.pmx]\n" &
        "Generate a sample first: nim c -r examples/make_sample.nim",
      1)
  let input = paramStr(1)
  if not fileExists(input):
    quit(fmt"No such file: {input}", 1)
  let newName = paramStr(2)
  if newName.len == 0:
    quit("The new name must not be empty.", 1)
  let (directory, name, _) = splitFile(input)
  let output =
    if paramCount() >= 3:
      paramStr(3)
    else:
      directory / (name & "-renamed.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let previous = renameModel(model, newName)

  validate(model, maxStringBytes = MaxStringBytes)
  writePmx(model, output)

  echo fmt"renamed '{previous}' to '{newName}'"
  echo fmt"wrote {output}"
