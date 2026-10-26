## Batch repair.
##
## Walks a directory of PMX files, validates each one, and writes a repaired copy of
## every model that needs it.

import std/[os, strformat]
import pmxforge

when isMainModule:
  import std/strutils

type
  Outcome* = enum ## What happened to one file.
    outcomeValid ## Already valid, so nothing was written.
    outcomeRepaired ## Repaired and written to the output directory.
    outcomeUnreadable ## The bytes could not be parsed at all.
    outcomeStuck ## Repair ran but the model is still invalid.

  Report* = object ## Result for one file.
    name*: string ## File name without its directory.
    outcome*: Outcome ## What happened to it.
    message*: string ## Detail for the log line.

proc repairOne*(input, outputDirectory: string): Report =
  ## Reads one file, repairs it when needed, and writes the result.
  result.name = extractFilename(input)
  var model: PmxModel
  try:
    model = readPmx(input, DesktopPmxReadLimits)
  except ValueError, IOError, OSError:
    result.outcome = outcomeUnreadable
    result.message = getCurrentExceptionMsg()
    return
  if model.isValid():
    result.outcome = outcomeValid
    return
  try:
    model.repair()
  except ValueError:
    result.outcome = outcomeStuck
    result.message = getCurrentExceptionMsg()
    return
  if not model.isValid():
    result.outcome = outcomeStuck
    result.message = "still invalid after repair"
    return
  result.message = outputDirectory / result.name
  try:
    writePmx(model, result.message)
    result.outcome = outcomeRepaired
  except ValueError, IOError, OSError:
    result.outcome = outcomeStuck
    result.message = getCurrentExceptionMsg()

proc label(report: Report): string =
  ## Returns the log line that describes one file.
  case report.outcome
  of outcomeValid:
    fmt"{report.name}: already valid"
  of outcomeRepaired:
    fmt"{report.name}: repaired into {report.message}"
  of outcomeUnreadable:
    fmt"{report.name}: cannot read ({report.message})"
  of outcomeStuck:
    fmt"{report.name}: cannot repair ({report.message})"

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: batch_repair <input-dir> [output-dir]\n" &
        "Generate a sample first: nim c -r examples/make_sample.nim",
      1)

  let inputDirectory = paramStr(1)
  if not dirExists(inputDirectory):
    quit(fmt"No such directory: {inputDirectory}", 1)
  let outputDirectory =
    if paramCount() >= 2:
      paramStr(2)
    else:
      inputDirectory / "repaired"
  if not dirExists(outputDirectory):
    createDir(outputDirectory)

  var counts: array[Outcome, int]
  for kind, path in walkDir(inputDirectory):
    if kind != pcFile or not path.toLowerAscii.endsWith(".pmx"):
      continue
    let report = repairOne(path, outputDirectory)
    echo label(report)
    inc counts[report.outcome]

  echo ""
  echo fmt"{counts[outcomeValid]} already valid"
  echo fmt"{counts[outcomeRepaired]} repaired"
  echo fmt"{counts[outcomeUnreadable]} unreadable"
  echo fmt"{counts[outcomeStuck]} beyond repair"
