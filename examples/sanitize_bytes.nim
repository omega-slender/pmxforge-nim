## Sanitize model bytes.
##
## Takes a model that arrived as bytes, checks it, repairs what it can, and returns clean bytes. Nothing here
## touches the filesystem, so this is the shape a web service or a browser build uses.

import pmxforge

when isMainModule:
  import std/strformat

proc damagedBytes*(): seq[byte] =
  ## Returns a model with references that point outside their lists.
  let model = newPmxModel(
    nameJA = "upload",
    nameEN = "upload",
    vertices = @[newVertex(), newVertex(position = Vector3.up)],
    bones = @[newBone(nameJA = "root"), newBone(nameJA = "child", parentBoneIndex = 0'i32)]
  )
  model.vertices[0].weightDeform = newBDEF1(7'i32)
  model.bones[0].parentBoneIndex = 99'i32
  result = writePmx(model, mode = pwmLenient)

proc sanitize*(data: seq[byte]): tuple[clean: seq[byte], problem: string] =
  ## Parses with the conservative limits, repairs, and returns strict bytes.
  var model: PmxModel
  try:
    model = readPmx(data, SafePmxReadLimits)
  except ValueError, IOError, OSError:
    return (@[], getCurrentExceptionMsg())
  if not model.isValid():
    result.problem = "the model failed validation and was repaired"
    model.repair()
  if not model.isValid():
    return (@[], "the model is still invalid after repair")
  try:
    result.clean = writePmx(model)
  except ValueError:
    result.problem = getCurrentExceptionMsg()

when isMainModule:
  let received = damagedBytes()
  echo fmt"received {received.len} bytes, valid: {isValid(readPmx(received))}"

  let result = sanitize(received)
  if result.clean.len == 0:
    quit(fmt"rejected the upload: {result.problem}", 1)

  let returned = readPmx(result.clean)
  echo fmt"returned {result.clean.len} bytes, valid: {returned.isValid()}"
  echo fmt"bones {returned.bones.len}, vertices {returned.vertices.len}, " & fmt"text {returned.nameJA}"
  if result.problem.len > 0:
    echo fmt"note: {result.problem}"
