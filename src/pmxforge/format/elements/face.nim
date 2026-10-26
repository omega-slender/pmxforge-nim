## Triangle faces.
##
## Provides `Face`: three unsigned vertex indices.

import ../internal/preconditions

type
  Face* = ref object ## Triangle formed by three vertex indices.
    vertexIndex1*: int32 ## First vertex index of the triangle.
    vertexIndex2*: int32 ## Second vertex index of the triangle.
    vertexIndex3*: int32 ## Third vertex index of the triangle.

proc newFace*(
  vertexIndex1 = 0'i32,
  vertexIndex2 = 0'i32,
  vertexIndex3 = 0'i32
): Face {.raises: [ValueError].} =
  ## Creates a face from three vertex indices.
  if vertexIndex1 < 0 or vertexIndex2 < 0 or vertexIndex3 < 0:
    raise newException(ValueError, "Face vertex indices must be non-negative.")
  Face(vertexIndex1: vertexIndex1, vertexIndex2: vertexIndex2, vertexIndex3: vertexIndex3)

func getIndices*(face: Face): array[3, int32] {.raises: [ValueError].} =
  ## Returns the three vertex indices.
  if face == nil:
    raise newException(ValueError, "Face is nil.")
  [face.vertexIndex1, face.vertexIndex2, face.vertexIndex3]

func containsVertex*(face: Face, vertexIndex: int32): bool {.raises: [ValueError].} =
  ## Returns true when the triangle uses `vertexIndex`.
  if face == nil:
    raise newException(ValueError, "Face is nil.")
  vertexIndex == face.vertexIndex1 or vertexIndex == face.vertexIndex2 or vertexIndex == face.vertexIndex3

proc `==`*(a, b: Face): bool =
  ## Compares two faces for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.vertexIndex1 == b.vertexIndex1 and a.vertexIndex2 == b.vertexIndex2 and a.vertexIndex3 == b.vertexIndex3

proc copy*(obj: Face): Face =
  ## Returns a deep copy of the face.
  if isNil(obj):
    return nil
  Face(vertexIndex1: obj.vertexIndex1, vertexIndex2: obj.vertexIndex2, vertexIndex3: obj.vertexIndex3)

proc isValid*(face: Face, vertexCount = -1'i32): bool =
  ## Returns true when every index is in range.
  if not isValidOptionalCount(vertexCount):
    return false
  if face == nil or face.vertexIndex1 < 0 or face.vertexIndex2 < 0 or face.vertexIndex3 < 0:
    return false
  vertexCount < 0 or
    (face.vertexIndex1 < vertexCount and face.vertexIndex2 < vertexCount and face.vertexIndex3 < vertexCount)

proc repair*(face: Face, vertexCount = -1'i32) {.raises: [ValueError].} =
  ## Clamps negative vertex indices to 0; out-of-range corners are left to `PmxModel.repair`.
  requireValidOptionalCount(vertexCount, "Face vertexCount")
  if face == nil:
    return
  if face.vertexIndex1 < 0:
    face.vertexIndex1 = 0
  if face.vertexIndex2 < 0:
    face.vertexIndex2 = 0
  if face.vertexIndex3 < 0:
    face.vertexIndex3 = 0
