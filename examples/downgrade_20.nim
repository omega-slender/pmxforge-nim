## PMX 2.1 to 2.0 downgrade.
##
## Rewrites a model so that a PMX 2.0 reader can load it, and reports every 2.1 feature
## it had to drop or replace.

import std/[strformat, strutils]
import pmxforge

type
  Change* = object ## One conversion applied to the model.
    kind: string ## Element kind that changed.
    detail: string ## What was done to it.

proc remap(mapping: seq[int32], index: int32): int32 =
  ## Returns the new morph index, or -1 when that morph is gone.
  if index < 0 or int(index) >= mapping.len: -1'i32 else: mapping[int(index)]

proc convertVertices*(model: PmxModel, changes: var seq[Change]) =
  ## Replaces dual-quaternion skinning with the four-bone form PMX 2.0 has.
  var converted = 0
  for vertex in model.vertices:
    if vertex.weightDeform.kind == dkQDEF:
      let qdef = vertex.weightDeform.qdef
      vertex.weightDeform = newBDEF4(
        qdef.boneIndex1, qdef.boneIndex2, qdef.boneIndex3, qdef.boneIndex4, qdef.boneWeight1,
        qdef.boneWeight2, qdef.boneWeight3, qdef.boneWeight4)
      inc converted
  if converted > 0:
    changes.add Change(kind: "vertices", detail: fmt"{converted} QDEF to BDEF4")

proc convertMorphs*(model: PmxModel, changes: var seq[Change]) =
  ## Drops flip and impulse morphs, then rewrites the indices that pointed at them.
  var mapping = newSeq[int32](model.morphs.len)
  var kept: seq[Morph] = @[]
  var dropped: seq[string] = @[]
  for index, morph in model.morphs:
    if morph.isPmx21Only:
      mapping[index] = -1
      dropped.add morph.nameJA
    else:
      mapping[index] = int32(kept.len)
      kept.add morph
  if dropped.len == 0:
    return
  model.morphs = kept

  for morph in model.morphs:
    var offsets: seq[MorphOffset] = @[]
    for offset in morph.offsetData:
      if offset.kind == moGroup:
        let target = remap(mapping, offset.group.morphIndex)
        if target < 0:
          continue
        offsets.add MorphOffset(
          kind: moGroup,
          group: GroupMorphOffset(morphIndex: target, influence: offset.group.influence)
        )
      else:
        offsets.add offset
    morph.offsetData = offsets
  for slot in model.displayFrames:
    var frames: seq[DisplayFrame] = @[]
    for frame in slot.frames:
      if frame.frameType != dftMorph:
        frames.add frame
      else:
        let target = remap(mapping, frame.targetIndex)
        if target >= 0:
          frames.add newDisplayFrame(dftMorph, target)
    slot.frames = frames
  changes.add Change(kind: "morphs", detail: &"dropped {dropped.join(\", \")}")

proc convertJoints*(
  model: PmxModel,
  changes: var seq[Change],
  dropUnsupported: bool
): seq[string] =
  ## PMX 2.0 defines only the spring 6DOF joint. The newer types reuse the same twelve
  ## limit floats as spans, anchor points, or a single axis, so retagging them is not a
  ## lossless conversion. They are dropped only when asked for, and otherwise reported.
  var dropped: seq[string] = @[]
  if dropUnsupported:
    var kept: seq[Joint] = @[]
    for index, joint in model.joints:
      if joint.jointType == jtSpring6DOF:
        kept.add joint
      else:
        dropped.add fmt"Joint[{index}] '{joint.nameJA}' ({joint.jointType})"
    model.joints = kept
    if dropped.len > 0:
      changes.add Change(kind: "joints", detail: &"dropped {dropped.join(\", \")}")
    return @[]

  var blocked: seq[string] = @[]
  for index, joint in model.joints:
    if joint.jointType != jtSpring6DOF:
      blocked.add fmt"Joint[{index}] '{joint.nameJA}' ({joint.jointType})"
  blocked

proc convertMaterials*(model: PmxModel, changes: var seq[Change]) =
  ## Clears the render flags that PMX 2.0 does not define. Sphere blending, including
  ## sub-texture mapping, is part of 2.0 and is left alone.
  var cleared: seq[string] = @[]
  for material in model.materials:
    if material.flags.vertexColor or material.flags.pointDraw or material.flags.lineDraw:
      material.flags.vertexColor = false
      material.flags.pointDraw = false
      material.flags.lineDraw = false
      cleared.add material.nameJA
  if cleared.len > 0:
    changes.add Change(kind: "materials", detail: &"{cleared.join(\", \")} without 2.1 flags")

proc dropSoftBodies*(model: PmxModel, changes: var seq[Change]) =
  ## Removes the soft body section, which PMX 2.0 does not have.
  if model.softBodies.len == 0:
    return
  changes.add Change(kind: "soft bodies", detail: fmt"dropped {model.softBodies.len}")
  model.softBodies = @[]

const Usage = "usage: downgrade_20 [--drop-joints] <model.pmx> [model-20.pmx]\n" &
  "Generate a sample first: nim c -r examples/make_sample.nim"

when isMainModule:
  import std/os

  var dropJoints = false
  var positional: seq[string] = @[]
  for i in 1 .. paramCount():
    let argument = paramStr(i)
    case argument
    of "--drop-joints":
      dropJoints = true
    of "--help", "-h":
      echo Usage
      quit(0)
    else:
      positional.add argument
  if positional.len < 1:
    quit(Usage, 1)
  let input = positional[0]
  if not fileExists(input):
    quit(fmt"No such file: {input}", 1)
  let (directory, name, _) = splitFile(input)
  let output =
    if positional.len >= 2:
      positional[1]
    else:
      directory / (name & "-20.pmx")

  let model = readPmx(input, DesktopPmxReadLimits)

  if model.version == pmx20 and not isPmx21Only(model):
    echo "This model already fits PMX 2.0, so there was nothing to change."
    quit(0)

  var changes: seq[Change] = @[]
  convertVertices(model, changes)
  convertMorphs(model, changes)
  let blocked = convertJoints(model, changes, dropJoints)
  convertMaterials(model, changes)
  dropSoftBodies(model, changes)

  if blocked.len > 0:
    quit(
      "cannot downgrade: these joints have no lossless PMX 2.0 equivalent: " &
        blocked.join(", ") & ". Re-run with --drop-joints to remove them.",
      1)

  model.version = pmx20

  for change in changes:
    echo fmt"{change.kind}: {change.detail}"

  try:
    validate(model)
    writePmx(model, output, autoUpgradeVersion = false)
  except CatchableError as error:
    quit(fmt"cannot write PMX 2.0 output: {error.msg}", 1)

  echo fmt"wrote {output}, still needs PMX 2.1: {isPmx21Only(model)}"
