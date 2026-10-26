## Display slots for the MMD UI.
##
## Provides `DisplaySlot` and `DisplayFrame`, the ordered bone and morph groups the model editor shows.

import ../internal/copy_helpers
import ../internal/preconditions

type
  DisplayFrameType* {.size: sizeof(int32).} = enum ## Target type in a display frame.
    dftBone = 0 ## Bone target.
    dftMorph = 1 ## Morph target.

  DisplayFrame* = object ## Target bone or morph entry in a display slot.
    frameType*: DisplayFrameType ## Target type (bone or morph).
    targetIndex*: int32 ## Index of the target bone or morph (-1 if unbound).

  DisplaySlot* = ref object ## Named UI category containing bones and morphs.
    nameJA*: string ## Japanese slot name.
    nameEN*: string ## English / universal slot name.
    specialFlag*: bool ## Marks a special system frame, such as Root.
    frames*: seq[DisplayFrame] ## List of bone and morph frame entries.

proc isValid*(slot: DisplaySlot, boneCount = -1'i32, morphCount = -1'i32): bool {.raises: [].}
  ## Returns true when frame types and targets are valid.

proc newDisplaySlot*(
  nameJA = "",
  specialFlag = false,
  nameEN = nameJA,
  frames: seq[DisplayFrame] = @[]
): DisplaySlot {.raises: [ValueError].} =
  ## Creates a display slot from its name and frames.
  result = DisplaySlot(nameJA: nameJA, nameEN: nameEN, specialFlag: specialFlag, frames: copySeq(frames))
  if not result.isValid():
    raise newException(ValueError, "Display slot contains invalid frames.")

proc newDisplayFrame*(frameType = dftBone, targetIndex = 0'i32): DisplayFrame {.raises: [ValueError].} =
  ## Creates a frame for a bone or morph; -1 means unbound.
  requireValidEnum(frameType, "Display frame type")
  if targetIndex < -1:
    raise newException(ValueError, "Display target index must be -1 or non-negative.")
  DisplayFrame(frameType: frameType, targetIndex: targetIndex)

proc newBoneDisplayFrame*(boneIndex = 0'i32): DisplayFrame {.raises: [ValueError].} =
  ## Creates a bone display frame.
  newDisplayFrame(dftBone, boneIndex)

proc newMorphDisplayFrame*(morphIndex = 0'i32): DisplayFrame {.raises: [ValueError].} =
  ## Creates a morph display frame.
  newDisplayFrame(dftMorph, morphIndex)

proc `==`*(a, b: DisplaySlot): bool =
  ## Compares two display slots for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.specialFlag == b.specialFlag and a.frames == b.frames

proc copy*(obj: DisplaySlot): DisplaySlot =
  ## Returns a deep copy of the display slot.
  if isNil(obj):
    return nil
  DisplaySlot(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    specialFlag: obj.specialFlag,
    frames: copySeq(obj.frames)
  )

proc isValid*(slot: DisplaySlot, boneCount: int32, morphCount: int32): bool =
  if not isValidOptionalCount(boneCount) or not isValidOptionalCount(morphCount):
    return false
  if slot == nil:
    return false
  try:
    for frame in slot.frames:
      requireValidEnum(frame.frameType, "Display frame type")
      if frame.targetIndex < -1:
        return false
      if frame.frameType == dftBone and boneCount >= 0 and frame.targetIndex >= boneCount:
        return false
      if frame.frameType == dftMorph and morphCount >= 0 and frame.targetIndex >= morphCount:
        return false
    true
  except ValueError:
    false

proc repair*(slot: DisplaySlot, boneCount = -1'i32, morphCount = -1'i32) {.raises: [ValueError].} =
  ## Drops unknown frame types and resets bad targets to -1.
  requireValidOptionalCount(boneCount, "Display slot boneCount")
  requireValidOptionalCount(morphCount, "Display slot morphCount")
  if slot == nil:
    return
  var writeIndex = 0
  for readIndex in 0 ..< slot.frames.len:
    var frame = slot.frames[readIndex]
    if int(frame.frameType) < 0 or int(frame.frameType) > 1:
      continue
    let outOfRange =
      frame.targetIndex < -1 or
      (frame.frameType == dftBone and boneCount >= 0 and frame.targetIndex >= boneCount) or
      (frame.frameType == dftMorph and morphCount >= 0 and frame.targetIndex >= morphCount)
    if outOfRange:
      frame.targetIndex = -1
    slot.frames[writeIndex] = frame
    inc writeIndex
  slot.frames.setLen(writeIndex)
