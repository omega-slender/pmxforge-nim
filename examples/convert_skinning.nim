## Convert skinning types.
##
## Rewrites the vertex skinning into the form a target tool understands. SDEF has the same two bones and the
## same weight as BDEF2, so it converts cleanly.

import pmxforge

when isMainModule:
  import std/[algorithm, os, strformat, tables]

proc kindName(kind: DeformKind): string =
  ## Returns the name of a skinning kind for the report.
  case kind
  of dkBDEF1: "BDEF1"
  of dkBDEF2: "BDEF2"
  of dkBDEF4: "BDEF4"
  of dkSDEF: "SDEF"
  of dkQDEF: "QDEF"

proc convertSdef*(model: PmxModel): int =
  ## Replaces spherical deformation with the two-bone linear form.
  for vertex in model.vertices:
    if vertex.weightDeform.kind != dkSDEF:
      continue
    let source = vertex.weightDeform.sdef
    vertex.weightDeform = newBDEF2(source.boneIndex1, source.boneIndex2, source.boneWeight1)
    inc result

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: convert_skinning <model.pmx> [model-bdef.pmx]\n" &
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
      directory / (name & "-bdef.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)

  var counts = initCountTable[string]()
  for vertex in model.vertices:
    counts.inc kindName(vertex.weightDeform.kind)
  let converted = convertSdef(model)

  validate(model)
  writePmx(model, output)

  var kinds: seq[string] = @[]
  for kind in counts.keys:
    kinds.add kind
  kinds.sort()
  for kind in kinds:
    echo fmt"  {counts[kind]} {kind}"
  echo fmt"converted {converted} SDEF vertices to BDEF2"
  echo fmt"wrote {output}"
