## English name filler.
##
## Copies every Japanese name into its English field when that field is empty, which is the first thing
## a non-Japanese tool reads.

import std/[strformat, tables]
import pmxforge

when isMainModule:
  import std/[algorithm, os]

proc fillIfEmpty(english: var string, japanese: string): bool =
  ## Copies the Japanese text into an empty English field.
  if english.len > 0 or japanese.len == 0:
    return false
  english = japanese
  result = true

proc fillNames*(model: PmxModel): CountTable[string] =
  ## Fills every empty English field and counts the changes by element kind.
  result = initCountTable[string]()
  if fillIfEmpty(model.nameEN, model.nameJA):
    result.inc "model name"
  if fillIfEmpty(model.commentsEN, model.commentsJA):
    result.inc "model comments"
  for material in model.materials:
    if fillIfEmpty(material.nameEN, material.nameJA):
      result.inc "material"
  for bone in model.bones:
    if fillIfEmpty(bone.nameEN, bone.nameJA):
      result.inc "bone"
  for morph in model.morphs:
    if fillIfEmpty(morph.nameEN, morph.nameJA):
      result.inc "morph"
  for slot in model.displayFrames:
    if fillIfEmpty(slot.nameEN, slot.nameJA):
      result.inc "display slot"
  for body in model.rigidBodies:
    if fillIfEmpty(body.nameEN, body.nameJA):
      result.inc "rigid body"
  for joint in model.joints:
    if fillIfEmpty(joint.nameEN, joint.nameJA):
      result.inc "joint"
  for body in model.softBodies:
    if fillIfEmpty(body.nameEN, body.nameJA):
      result.inc "soft body"

proc save(model: PmxModel, output: string) =
  ## Writes the model, repairing a private copy when strict writing refuses it.
  try:
    validate(model)
    writePmx(model, output)
    echo fmt"wrote {output}"
  except ValueError as error:
    echo fmt"strict writing refused the model: {error.msg}"
    writePmx(model, output, mode = pwmRepair)
    echo fmt"wrote {output} through the repair pass"

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: fill_names <model.pmx> [model-named.pmx]\n" &
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
      directory / (name & "-named.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)
  let changes = fillNames(model)

  if changes.len == 0:
    echo "Every English field already has a value."
  else:
    var kinds: seq[string] = @[]
    for kind in changes.keys:
      kinds.add kind
    kinds.sort()
    for kind in kinds:
      echo fmt"  {changes[kind]} {kind}"
    save(model, output)
    echo fmt"read back: {readPmx(output).nameEN}"
