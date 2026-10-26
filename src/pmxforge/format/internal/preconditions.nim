## Internal validation helpers.
##
## Provides the finite and range checks used by constructors, and the repair fallbacks that
## replace non-finite values.

import std/[math]
import ../../core/vectors
import ../../core/colors

proc requireValidEnum*[E: enum](value: E, label: string) {.raises: [ValueError].} =
  ## Ensures `value` is a defined enum ordinal.
  for candidate in E:
    if value == candidate:
      return
  raise newException(ValueError, label & " is not a supported PMX value.")

when defined(js):
  proc jsFround(value: float32): float32 {.importjs: "Math.fround(#)".}
    ## Rounds a JavaScript number to `float32` precision.

proc isFiniteFloat32*(value: float32): bool {.inline.} =
  ## Returns true when `value` is finite. On JavaScript the value also has to survive
  ## the conversion to a 32-bit float, which the native backends do on their own.
  when defined(js):
    if classify(value) in {fcNan, fcInf, fcNegInf}:
      return false
    classify(jsFround(value)) notin {fcNan, fcInf, fcNegInf}
  else:
    classify(value) notin {fcNan, fcInf, fcNegInf}

template checkFinite*(value: float32, label: untyped) =
  ## Raises ValueError when `value` is NaN, infinite, or too large for a `float32`.
  if not isFiniteFloat32(value):
    raise newException(ValueError, label & " must be a finite float32.")

template checkFinite*(value: Vector2, label: untyped) =
  ## Raises ValueError if any component is NaN or infinite.
  checkFinite(value.x, label & ".x")
  checkFinite(value.y, label & ".y")

template checkFinite*(value: Vector3, label: untyped) =
  ## Raises ValueError if any component is NaN or infinite.
  checkFinite(value.x, label & ".x")
  checkFinite(value.y, label & ".y")
  checkFinite(value.z, label & ".z")

template checkFinite*(value: Vector4, label: untyped) =
  ## Raises ValueError if any component is NaN or infinite.
  checkFinite(value.x, label & ".x")
  checkFinite(value.y, label & ".y")
  checkFinite(value.z, label & ".z")
  checkFinite(value.w, label & ".w")

template checkFinite*(value: Quaternion, label: untyped) =
  ## Raises ValueError if any component is NaN or infinite.
  checkFinite(value.x, label & ".x")
  checkFinite(value.y, label & ".y")
  checkFinite(value.z, label & ".z")
  checkFinite(value.w, label & ".w")

template checkFinite*(value: RGB, label: untyped) =
  ## Raises ValueError if any channel is NaN or infinite.
  checkFinite(value.r, label & ".r")
  checkFinite(value.g, label & ".g")
  checkFinite(value.b, label & ".b")

template checkFinite*(value: RGBA, label: untyped) =
  ## Raises ValueError if any channel is NaN or infinite.
  checkFinite(value.r, label & ".r")
  checkFinite(value.g, label & ".g")
  checkFinite(value.b, label & ".b")
  checkFinite(value.a, label & ".a")

template checkNonNegativeFinite*(value: float32, label: untyped) =
  ## Raises ValueError if `value` is negative, NaN, or infinite.
  checkFinite(value, label)
  if value < 0.0'f32:
    raise newException(ValueError, label & " must be non-negative.")

template checkUnitRange*(value: float32, label: untyped) =
  ## Raises ValueError when `value` is outside 0.0-1.0.
  checkFinite(value, label)
  if value < 0.0'f32 or value > 1.0'f32:
    raise newException(ValueError, label & " must be in [0, 1].")

func isValidOptionalCount*(value: int32): bool {.inline.} =
  ## Returns true if `value` is -1 (unspecified) or non-negative.
  value == -1 or value >= 0

proc requireValidOptionalCount*(value: int32, label: string) {.raises: [ValueError].} =
  ## Raises ValueError if `value` is less than -1.
  if not isValidOptionalCount(value):
    raise newException(ValueError, label & " must be -1 (unknown) or a non-negative count.")

proc repairFinite*(value: float32, fallback = 0.0'f32): float32 {.inline.} =
  ## Returns `fallback` when `value` is NaN, infinite, or too large for a `float32`.
  if not isFiniteFloat32(value): fallback else: value

proc repairNonNegative*(value: float32, fallback = 0.0'f32): float32 {.inline.} =
  ## Clamps to zero and replaces non-finite values with `fallback`.
  max(0.0'f32, repairFinite(value, fallback))

proc repairFinite*(value: Vector2): Vector2 {.inline.} =
  ## Replaces non-finite components with zero.
  Vector2(x: repairFinite(value.x), y: repairFinite(value.y))

proc repairFinite*(value: Vector3): Vector3 {.inline.} =
  ## Replaces non-finite components with zero.
  Vector3(x: repairFinite(value.x), y: repairFinite(value.y), z: repairFinite(value.z))

proc repairFinite*(value: Vector4): Vector4 {.inline.} =
  ## Replaces non-finite components with zero.
  Vector4(
    x: repairFinite(value.x),
    y: repairFinite(value.y),
    z: repairFinite(value.z),
    w: repairFinite(value.w)
  )

proc repairFinite*(value: Quaternion): Quaternion {.inline.} =
  ## Replaces non-finite components with zero.
  Quaternion(
    x: repairFinite(value.x),
    y: repairFinite(value.y),
    z: repairFinite(value.z),
    w: repairFinite(value.w)
  )

proc repairFinite*(value: RGB): RGB {.inline.} =
  ## Replaces non-finite channels with zero.
  RGB(r: repairFinite(value.r), g: repairFinite(value.g), b: repairFinite(value.b))

proc repairFinite*(value: RGBA): RGBA {.inline.} =
  ## Replaces non-finite channels with zero.
  RGBA(r: repairFinite(value.r), g: repairFinite(value.g), b: repairFinite(value.b), a: repairFinite(value.a))
