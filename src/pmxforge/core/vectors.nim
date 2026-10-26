## Vector and quaternion math.
##
## Provides `Vector2`, `Vector3`, `Vector4`, and `Quaternion` in the PMX axis convention (+X right, +Y up, +Z
## forward), with radians for rotations.

import std/[hashes, math]

const
  Epsilon* = 1e-7'f32 ## Small threshold for zero-length and division checks.
  EpsilonSquared = Epsilon * Epsilon ## Squared threshold for distance checks.
  Deg2Rad* = PI / 180.0'f32 ## Degrees-to-radians factor.
  Rad2Deg* = 180.0'f32 / PI ## Radians-to-degrees factor.

type
  Vector2* = object ## 2D float32 vector.
    x*: float32 ## X coordinate.
    y*: float32 ## Y coordinate.

  Vector3* = object ## 3D float32 vector.
    x*: float32 ## X coordinate (points right).
    y*: float32 ## Y coordinate (points up).
    z*: float32 ## Z coordinate (points forward).

  Vector4* = object ## 4D float32 vector.
    x*: float32 ## X component.
    y*: float32 ## Y component.
    z*: float32 ## Z component.
    w*: float32 ## W component.

  Quaternion* = object ## Quaternion rotation (x, y, z, w).
    x*: float32 ## X imaginary component.
    y*: float32 ## Y imaginary component.
    z*: float32 ## Z imaginary component.
    w*: float32 ## W real component.

func canonicalFloatHash(value: float32): Hash {.inline.} =
  ## Canonicalizes signed zero before hashing.
  hash(if value == 0.0'f32: 0.0'f32 else: value)

func hash*(value: Vector2): Hash =
  ## Hashes vector components consistently with exact equality.
  result = !$(canonicalFloatHash(value.x) !& canonicalFloatHash(value.y))

func hash*(value: Vector3): Hash =
  ## Hashes vector components consistently with exact equality.
  result = !$(canonicalFloatHash(value.x) !& canonicalFloatHash(value.y) !& canonicalFloatHash(value.z))

func hash*(value: Vector4): Hash =
  ## Hashes vector components consistently with exact equality.
  result = !$(
    canonicalFloatHash(value.x) !& canonicalFloatHash(value.y) !& canonicalFloatHash(value.z) !&
      canonicalFloatHash(value.w))

func hash*(value: Quaternion): Hash =
  ## Hashes quaternion components consistently with exact equality.
  result = !$(
    canonicalFloatHash(value.x) !& canonicalFloatHash(value.y) !& canonicalFloatHash(value.z) !&
      canonicalFloatHash(value.w))

func zero*(T: type Vector2): Vector2 {.inline.} =
  ## Zero vector (0, 0).
  Vector2(x: 0, y: 0)

func one*(T: type Vector2): Vector2 {.inline.} =
  ## Vector with both components set to 1.
  Vector2(x: 1, y: 1)

func zero*(T: type Vector3): Vector3 {.inline.} =
  ## Zero vector (0, 0, 0).
  Vector3(x: 0, y: 0, z: 0)

func one*(T: type Vector3): Vector3 {.inline.} =
  ## Vector with all components set to 1.
  Vector3(x: 1, y: 1, z: 1)

func up*(T: type Vector3): Vector3 {.inline.} =
  ## World up direction (0, 1, 0).
  Vector3(x: 0, y: 1, z: 0)

func down*(T: type Vector3): Vector3 {.inline.} =
  ## World down direction (0, -1, 0).
  Vector3(x: 0, y: -1, z: 0)

func right*(T: type Vector3): Vector3 {.inline.} =
  ## World right direction (1, 0, 0).
  Vector3(x: 1, y: 0, z: 0)

func left*(T: type Vector3): Vector3 {.inline.} =
  ## World left direction (-1, 0, 0).
  Vector3(x: -1, y: 0, z: 0)

func forward*(T: type Vector3): Vector3 {.inline.} =
  ## World forward direction (0, 0, 1).
  Vector3(x: 0, y: 0, z: 1)

func back*(T: type Vector3): Vector3 {.inline.} =
  ## World back direction (0, 0, -1).
  Vector3(x: 0, y: 0, z: -1)

func zero*(T: type Vector4): Vector4 {.inline.} =
  ## Zero vector (0, 0, 0, 0).
  Vector4(x: 0, y: 0, z: 0, w: 0)

func one*(T: type Vector4): Vector4 {.inline.} =
  ## Vector with all components set to 1.
  Vector4(x: 1, y: 1, z: 1, w: 1)

func identity*(T: type Quaternion): Quaternion {.inline.} =
  ## Identity rotation (0, 0, 0, 1).
  Quaternion(x: 0, y: 0, z: 0, w: 1)

func `==`*(a, b: Vector2): bool {.inline.} =
  ## Checks exact component equality.
  a.x == b.x and a.y == b.y

func `+`*(a, b: Vector2): Vector2 {.inline.} =
  ## Adds corresponding components.
  Vector2(x: a.x + b.x, y: a.y + b.y)

func `-`*(a, b: Vector2): Vector2 {.inline.} =
  ## Subtracts corresponding components.
  Vector2(x: a.x - b.x, y: a.y - b.y)

func `-`*(a: Vector2): Vector2 {.inline.} =
  ## Negates every component.
  Vector2(x: -a.x, y: -a.y)

func `*`*(v: Vector2, s: float32): Vector2 {.inline.} =
  ## Multiplies every component by `s`.
  Vector2(x: v.x * s, y: v.y * s)

func `*`*(s: float32, v: Vector2): Vector2 {.inline.} =
  ## Multiplies every component by `s`.
  Vector2(x: v.x * s, y: v.y * s)

func `*`*(a, b: Vector2): Vector2 {.inline.} =
  ## Multiplies corresponding components.
  Vector2(x: a.x * b.x, y: a.y * b.y)

func `/`*(v: Vector2, s: float32): Vector2 {.inline.} =
  ## Divides every component by `s` directly: computing a reciprocal first would
  ## overflow for a subnormal divisor and turn `x / x` into an infinity.
  Vector2(x: v.x / s, y: v.y / s)

func `/`*(a, b: Vector2): Vector2 {.inline.} =
  ## Divides corresponding components.
  Vector2(x: a.x / b.x, y: a.y / b.y)

func `+=`*(a: var Vector2, b: Vector2) {.inline.} =
  ## Adds `b` to `a` in place.
  a.x += b.x
  a.y += b.y

func `-=`*(a: var Vector2, b: Vector2) {.inline.} =
  ## Subtracts `b` from `a` in place.
  a.x -= b.x
  a.y -= b.y

func `*=`*(a: var Vector2, s: float32) {.inline.} =
  ## Scales `a` in place by `s`.
  a.x *= s
  a.y *= s

func `/=`*(a: var Vector2, s: float32) {.inline.} =
  ## Divides `a` in place by `s`.
  a.x = a.x / s
  a.y = a.y / s

func dot*(a, b: Vector2): float32 {.inline.} =
  ## Returns the dot product.
  float32(float(a.x) * float(b.x) + float(a.y) * float(b.y))

func lengthSquared*(v: Vector2): float32 {.inline.} =
  ## Returns squared length; use it when only comparing distances.
  float32(float(v.x) * float(v.x) + float(v.y) * float(v.y))

func length*(v: Vector2): float32 {.inline.} =
  ## Returns Euclidean length.
  let scale = max(abs(v.x), abs(v.y))
  if scale == 0.0'f32:
    0.0'f32
  elif classify(scale) in {fcNan, fcInf, fcNegInf}:
    scale
  else:
    let sx = float(v.x) / float(scale)
    let sy = float(v.y) / float(scale)
    float32(float(scale) * sqrt(sx * sx + sy * sy))

func normalize*(v: Vector2): Vector2 {.inline.} =
  ## Returns a unit vector, or `v` when it is near zero.
  let scale = max(abs(v.x), abs(v.y))
  if scale == 0.0'f32:
    v
  else:
    let sx = v.x / scale
    let sy = v.y / scale
    let len = sqrt(sx * sx + sy * sy)
    if scale <= Epsilon / len:
      v
    else:
      Vector2(x: sx / len, y: sy / len)

func perpendicular*(v: Vector2): Vector2 {.inline.} =
  ## Rotates `v` 90 degrees counter-clockwise.
  Vector2(x: -v.y, y: v.x)

func distance*(a, b: Vector2): float32 {.inline.} =
  ## Returns Euclidean distance.
  (b - a).length

func distanceSquared*(a, b: Vector2): float32 {.inline.} =
  ## Returns squared distance without taking a square root.
  (b - a).lengthSquared

func lerp*(a, b: Vector2, t: float32): Vector2 {.inline.} =
  ## Linearly interpolates from `a` to `b`; `t = 0` returns `a`.
  Vector2(
    x: float32(float(a.x) + (float(b.x) - float(a.x)) * float(t)),
    y: float32(float(a.y) + (float(b.y) - float(a.y)) * float(t))
  )

func reflect*(v, normal: Vector2): Vector2 {.inline.} =
  ## Reflects `v` across a surface; `normal` must be unit length.
  let amount = 2.0 * (float(v.x) * float(normal.x) + float(v.y) * float(normal.y))
  Vector2(
    x: float32(float(v.x) - amount * float(normal.x)),
    y: float32(float(v.y) - amount * float(normal.y))
  )

func angle*(a, b: Vector2): float32 {.inline.} =
  ## Returns the angle between `a` and `b` in radians.
  let ax = float(a.x)
  let ay = float(a.y)
  let bx = float(b.x)
  let by = float(b.y)
  let aSquared = ax * ax + ay * ay
  let bSquared = bx * bx + by * by
  if aSquared < float(EpsilonSquared) or bSquared < float(EpsilonSquared):
    0.0'f32
  else:
    let denom = sqrt(aSquared * bSquared)
    float32(arccos(clamp((ax * bx + ay * by) / denom, -1.0, 1.0)))

func abs*(v: Vector2): Vector2 {.inline.} =
  ## Takes the absolute value of each component.
  Vector2(x: abs(v.x), y: abs(v.y))

func min*(a, b: Vector2): Vector2 {.inline.} =
  ## Takes the minimum of each component.
  Vector2(x: min(a.x, b.x), y: min(a.y, b.y))

func max*(a, b: Vector2): Vector2 {.inline.} =
  ## Takes the maximum of each component.
  Vector2(x: max(a.x, b.x), y: max(a.y, b.y))

func clamp*(v, lo, hi: Vector2): Vector2 {.inline.} =
  ## Clamps each component of `v` to the supplied bounds.
  Vector2(x: clamp(v.x, lo.x, hi.x), y: clamp(v.y, lo.y, hi.y))

func `==`*(a, b: Vector3): bool {.inline.} =
  ## Checks exact component equality.
  a.x == b.x and a.y == b.y and a.z == b.z

func `+`*(a, b: Vector3): Vector3 {.inline.} =
  ## Adds corresponding components.
  Vector3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z)

func `-`*(a, b: Vector3): Vector3 {.inline.} =
  ## Subtracts corresponding components.
  Vector3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z)

func `-`*(a: Vector3): Vector3 {.inline.} =
  ## Negates every component.
  Vector3(x: -a.x, y: -a.y, z: -a.z)

func `*`*(v: Vector3, s: float32): Vector3 {.inline.} =
  ## Multiplies every component by `s`.
  Vector3(x: v.x * s, y: v.y * s, z: v.z * s)

func `*`*(s: float32, v: Vector3): Vector3 {.inline.} =
  ## Multiplies every component by `s`.
  Vector3(x: v.x * s, y: v.y * s, z: v.z * s)

func `*`*(a, b: Vector3): Vector3 {.inline.} =
  ## Multiplies corresponding components.
  Vector3(x: a.x * b.x, y: a.y * b.y, z: a.z * b.z)

func `/`*(v: Vector3, s: float32): Vector3 {.inline.} =
  ## Divides every component by `s` directly: computing a reciprocal first would
  ## overflow for a subnormal divisor and turn `x / x` into an infinity.
  Vector3(x: v.x / s, y: v.y / s, z: v.z / s)

func `/`*(a, b: Vector3): Vector3 {.inline.} =
  ## Divides corresponding components.
  Vector3(x: a.x / b.x, y: a.y / b.y, z: a.z / b.z)

func `+=`*(a: var Vector3, b: Vector3) {.inline.} =
  ## Adds `b` to `a` in place.
  a.x += b.x
  a.y += b.y
  a.z += b.z

func `-=`*(a: var Vector3, b: Vector3) {.inline.} =
  ## Subtracts `b` from `a` in place.
  a.x -= b.x
  a.y -= b.y
  a.z -= b.z

func `*=`*(a: var Vector3, s: float32) {.inline.} =
  ## Scales `a` in place by `s`.
  a.x *= s
  a.y *= s
  a.z *= s

func `/=`*(a: var Vector3, s: float32) {.inline.} =
  ## Divides `a` in place by `s`.
  a.x = a.x / s
  a.y = a.y / s
  a.z = a.z / s

func dot*(a, b: Vector3): float32 {.inline.} =
  ## Returns the dot product.
  float32(float(a.x) * float(b.x) + float(a.y) * float(b.y) + float(a.z) * float(b.z))

func cross*(a, b: Vector3): Vector3 {.inline.} =
  ## Returns the cross product of `a` and `b`.
  Vector3(
    x: float32(float(a.y) * float(b.z) - float(a.z) * float(b.y)),
    y: float32(float(a.z) * float(b.x) - float(a.x) * float(b.z)),
    z: float32(float(a.x) * float(b.y) - float(a.y) * float(b.x))
  )

func lengthSquared*(v: Vector3): float32 {.inline.} =
  ## Returns squared length; use it when only comparing distances.
  float32(float(v.x) * float(v.x) + float(v.y) * float(v.y) + float(v.z) * float(v.z))

func length*(v: Vector3): float32 {.inline.} =
  ## Returns Euclidean length.
  let scale = max(abs(v.x), max(abs(v.y), abs(v.z)))
  if scale == 0.0'f32:
    0.0'f32
  elif classify(scale) in {fcNan, fcInf, fcNegInf}:
    scale
  else:
    let sx = float(v.x) / float(scale)
    let sy = float(v.y) / float(scale)
    let sz = float(v.z) / float(scale)
    float32(float(scale) * sqrt(sx * sx + sy * sy + sz * sz))

func normalize*(v: Vector3): Vector3 {.inline.} =
  ## Returns a unit vector, or `v` when it is near zero.
  let scale = max(abs(v.x), max(abs(v.y), abs(v.z)))
  if scale == 0.0'f32:
    v
  else:
    let sx = v.x / scale
    let sy = v.y / scale
    let sz = v.z / scale
    let len = sqrt(sx * sx + sy * sy + sz * sz)
    if scale <= Epsilon / len:
      v
    else:
      Vector3(x: sx / len, y: sy / len, z: sz / len)

func distance*(a, b: Vector3): float32 {.inline.} =
  ## Returns Euclidean distance.
  (b - a).length

func distanceSquared*(a, b: Vector3): float32 {.inline.} =
  ## Returns squared distance without taking a square root.
  (b - a).lengthSquared

func lerp*(a, b: Vector3, t: float32): Vector3 {.inline.} =
  ## Linearly interpolates from `a` to `b`; `t = 0` returns `a`.
  Vector3(
    x: float32(float(a.x) + (float(b.x) - float(a.x)) * float(t)),
    y: float32(float(a.y) + (float(b.y) - float(a.y)) * float(t)),
    z: float32(float(a.z) + (float(b.z) - float(a.z)) * float(t))
  )

func reflect*(v, normal: Vector3): Vector3 {.inline.} =
  ## Reflects `v` across a surface; `normal` must be unit length.
  let amount =
    2.0 * (float(v.x) * float(normal.x) + float(v.y) * float(normal.y) + float(v.z) * float(normal.z))
  Vector3(
    x: float32(float(v.x) - amount * float(normal.x)),
    y: float32(float(v.y) - amount * float(normal.y)),
    z: float32(float(v.z) - amount * float(normal.z))
  )

func project*(v, onNormal: Vector3): Vector3 {.inline.} =
  ## Projects `v` onto `onNormal`; a near-zero normal returns zero.
  let scale = max(abs(onNormal.x), max(abs(onNormal.y), abs(onNormal.z)))
  if scale == 0.0'f32:
    return Vector3.zero
  let sx = float(onNormal.x) / float(scale)
  let sy = float(onNormal.y) / float(scale)
  let sz = float(onNormal.z) / float(scale)
  let unitLength = sqrt(sx * sx + sy * sy + sz * sz)
  if float(scale) * unitLength < float(Epsilon):
    return Vector3.zero
  let nx = sx / unitLength
  let ny = sy / unitLength
  let nz = sz / unitLength
  let amount = float(v.x) * nx + float(v.y) * ny + float(v.z) * nz
  Vector3(x: float32(nx * amount), y: float32(ny * amount), z: float32(nz * amount))

func projectOnPlane*(v, planeNormal: Vector3): Vector3 {.inline.} =
  ## Removes the component of `v` along `planeNormal`.
  v - project(v, planeNormal)

func angle*(a, b: Vector3): float32 {.inline.} =
  ## Returns the angle between `a` and `b` in radians.
  let ax = float(a.x)
  let ay = float(a.y)
  let az = float(a.z)
  let bx = float(b.x)
  let by = float(b.y)
  let bz = float(b.z)
  let aSquared = ax * ax + ay * ay + az * az
  let bSquared = bx * bx + by * by + bz * bz
  if aSquared < float(EpsilonSquared) or bSquared < float(EpsilonSquared):
    0.0'f32
  else:
    let denom = sqrt(aSquared * bSquared)
    float32(arccos(clamp((ax * bx + ay * by + az * bz) / denom, -1.0, 1.0)))

func signedAngle*(a, b, axis: Vector3): float32 {.inline.} =
  ## Returns the signed angle in radians from `a` to `b` around `axis`.
  let unsigned = angle(a, b)
  let crossX = float(a.y) * float(b.z) - float(a.z) * float(b.y)
  let crossY = float(a.z) * float(b.x) - float(a.x) * float(b.z)
  let crossZ = float(a.x) * float(b.y) - float(a.y) * float(b.x)
  let orientation = crossX * float(axis.x) + crossY * float(axis.y) + crossZ * float(axis.z)
  if orientation < 0.0: -unsigned else: unsigned

func abs*(v: Vector3): Vector3 {.inline.} =
  ## Takes the absolute value of each component.
  Vector3(x: abs(v.x), y: abs(v.y), z: abs(v.z))

func min*(a, b: Vector3): Vector3 {.inline.} =
  ## Takes the minimum of each component.
  Vector3(x: min(a.x, b.x), y: min(a.y, b.y), z: min(a.z, b.z))

func max*(a, b: Vector3): Vector3 {.inline.} =
  ## Takes the maximum of each component.
  Vector3(x: max(a.x, b.x), y: max(a.y, b.y), z: max(a.z, b.z))

func clamp*(v, lo, hi: Vector3): Vector3 {.inline.} =
  ## Clamps each component of `v` to the supplied bounds.
  Vector3(x: clamp(v.x, lo.x, hi.x), y: clamp(v.y, lo.y, hi.y), z: clamp(v.z, lo.z, hi.z))

func moveTowards*(current, target: Vector3, maxDelta: float32): Vector3 {.inline.} =
  ## Moves `current` toward `target` by at most `maxDelta`.
  if maxDelta <= 0.0'f32:
    return current
  let dx = float(target.x) - float(current.x)
  let dy = float(target.y) - float(current.y)
  let dz = float(target.z) - float(current.z)
  let dist = sqrt(dx * dx + dy * dy + dz * dz)
  let maxStep = float(maxDelta)
  if dist <= maxStep or dist < float(Epsilon):
    target
  else:
    let factor = maxStep / dist
    Vector3(
      x: float32(float(current.x) + dx * factor),
      y: float32(float(current.y) + dy * factor),
      z: float32(float(current.z) + dz * factor)
    )

func `==`*(a, b: Vector4): bool {.inline.} =
  ## Checks exact component equality.
  a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w

func `+`*(a, b: Vector4): Vector4 {.inline.} =
  ## Adds corresponding components.
  Vector4(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z, w: a.w + b.w)

func `-`*(a, b: Vector4): Vector4 {.inline.} =
  ## Subtracts corresponding components.
  Vector4(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z, w: a.w - b.w)

func `-`*(a: Vector4): Vector4 {.inline.} =
  ## Negates every component.
  Vector4(x: -a.x, y: -a.y, z: -a.z, w: -a.w)

func `*`*(v: Vector4, s: float32): Vector4 {.inline.} =
  ## Multiplies every component by `s`.
  Vector4(x: v.x * s, y: v.y * s, z: v.z * s, w: v.w * s)

func `*`*(s: float32, v: Vector4): Vector4 {.inline.} =
  ## Multiplies every component by `s`.
  Vector4(x: v.x * s, y: v.y * s, z: v.z * s, w: v.w * s)

func `*`*(a, b: Vector4): Vector4 {.inline.} =
  ## Multiplies corresponding components.
  Vector4(x: a.x * b.x, y: a.y * b.y, z: a.z * b.z, w: a.w * b.w)

func `/`*(v: Vector4, s: float32): Vector4 {.inline.} =
  ## Divides every component by `s` directly: computing a reciprocal first would
  ## overflow for a subnormal divisor and turn `x / x` into an infinity.
  Vector4(x: v.x / s, y: v.y / s, z: v.z / s, w: v.w / s)

func `/`*(a, b: Vector4): Vector4 {.inline.} =
  ## Divides corresponding components.
  Vector4(x: a.x / b.x, y: a.y / b.y, z: a.z / b.z, w: a.w / b.w)

func `+=`*(a: var Vector4, b: Vector4) {.inline.} =
  ## Adds `b` to `a` in place.
  a.x += b.x
  a.y += b.y
  a.z += b.z
  a.w += b.w

func `-=`*(a: var Vector4, b: Vector4) {.inline.} =
  ## Subtracts `b` from `a` in place.
  a.x -= b.x
  a.y -= b.y
  a.z -= b.z
  a.w -= b.w

func `*=`*(a: var Vector4, s: float32) {.inline.} =
  ## Scales `a` in place by `s`.
  a.x *= s
  a.y *= s
  a.z *= s
  a.w *= s

func `/=`*(a: var Vector4, s: float32) {.inline.} =
  ## Divides `a` in place by `s`.
  a.x = a.x / s
  a.y = a.y / s
  a.z = a.z / s
  a.w = a.w / s

func dot*(a, b: Vector4): float32 {.inline.} =
  ## Returns the dot product.
  float32(
    float(a.x) * float(b.x) + float(a.y) * float(b.y) + float(a.z) * float(b.z) + float(a.w) * float(b.w)
  )

func lengthSquared*(v: Vector4): float32 {.inline.} =
  ## Returns squared length; use it when only comparing distances.
  float32(
    float(v.x) * float(v.x) + float(v.y) * float(v.y) + float(v.z) * float(v.z) + float(v.w) * float(v.w)
  )

func length*(v: Vector4): float32 {.inline.} =
  ## Returns Euclidean length.
  let scale = max(max(abs(v.x), abs(v.y)), max(abs(v.z), abs(v.w)))
  if scale == 0.0'f32:
    0.0'f32
  elif classify(scale) in {fcNan, fcInf, fcNegInf}:
    scale
  else:
    let sx = float(v.x) / float(scale)
    let sy = float(v.y) / float(scale)
    let sz = float(v.z) / float(scale)
    let sw = float(v.w) / float(scale)
    float32(float(scale) * sqrt(sx * sx + sy * sy + sz * sz + sw * sw))

func normalize*(v: Vector4): Vector4 {.inline.} =
  ## Returns a unit vector, or `v` when it is near zero.
  let scale = max(max(abs(v.x), abs(v.y)), max(abs(v.z), abs(v.w)))
  if scale == 0.0'f32:
    v
  else:
    let sx = v.x / scale
    let sy = v.y / scale
    let sz = v.z / scale
    let sw = v.w / scale
    let len = sqrt(sx * sx + sy * sy + sz * sz + sw * sw)
    if scale <= Epsilon / len:
      v
    else:
      Vector4(x: sx / len, y: sy / len, z: sz / len, w: sw / len)

func lerp*(a, b: Vector4, t: float32): Vector4 {.inline.} =
  ## Linearly interpolates from `a` to `b`; `t = 0` returns `a`.
  Vector4(
    x: float32(float(a.x) + (float(b.x) - float(a.x)) * float(t)),
    y: float32(float(a.y) + (float(b.y) - float(a.y)) * float(t)),
    z: float32(float(a.z) + (float(b.z) - float(a.z)) * float(t)),
    w: float32(float(a.w) + (float(b.w) - float(a.w)) * float(t))
  )

func distance*(a, b: Vector4): float32 {.inline.} =
  ## Returns Euclidean distance.
  (b - a).length

func abs*(v: Vector4): Vector4 {.inline.} =
  ## Takes the absolute value of each component.
  Vector4(x: abs(v.x), y: abs(v.y), z: abs(v.z), w: abs(v.w))

func `==`*(a, b: Quaternion): bool {.inline.} =
  ## Checks exact component equality.
  a.x == b.x and a.y == b.y and a.z == b.z and a.w == b.w

func `+`*(a, b: Quaternion): Quaternion {.inline.} =
  ## Adds corresponding quaternion components; the result is not normalized.
  Quaternion(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z, w: a.w + b.w)

func `-`*(a, b: Quaternion): Quaternion {.inline.} =
  ## Subtracts corresponding quaternion components.
  Quaternion(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z, w: a.w - b.w)

func `-`*(q: Quaternion): Quaternion {.inline.} =
  ## Negates all components; `q` and `-q` are the same rotation.
  Quaternion(x: -q.x, y: -q.y, z: -q.z, w: -q.w)

func `*`*(a, b: Quaternion): Quaternion {.inline.} =
  ## Hamilton product (applies rotation `b` then `a`).
  Quaternion(
    x: float32(
      float(a.w) * float(b.x) + float(a.x) * float(b.w) + float(a.y) * float(b.z) - float(a.z) * float(b.y)),
    y: float32(
      float(a.w) * float(b.y) - float(a.x) * float(b.z) + float(a.y) * float(b.w) + float(a.z) * float(b.x)),
    z: float32(
      float(a.w) * float(b.z) + float(a.x) * float(b.y) - float(a.y) * float(b.x) + float(a.z) * float(b.w)),
    w: float32(
      float(a.w) * float(b.w) - float(a.x) * float(b.x) - float(a.y) * float(b.y) - float(a.z) * float(b.z))
  )

func `*`*(q: Quaternion, s: float32): Quaternion {.inline.} =
  ## Multiplies every quaternion component by `s`.
  Quaternion(x: q.x * s, y: q.y * s, z: q.z * s, w: q.w * s)

func `*`*(s: float32, q: Quaternion): Quaternion {.inline.} =
  ## Multiplies every quaternion component by `s`.
  Quaternion(x: q.x * s, y: q.y * s, z: q.z * s, w: q.w * s)

func `/`*(q: Quaternion, s: float32): Quaternion {.inline.} =
  ## Divides every quaternion component by `s` directly, so a subnormal divisor
  ## cannot turn equal components into infinities.
  Quaternion(x: q.x / s, y: q.y / s, z: q.z / s, w: q.w / s)

func dot*(a, b: Quaternion): float32 {.inline.} =
  ## Returns the quaternion dot product.
  float32(
    float(a.x) * float(b.x) + float(a.y) * float(b.y) + float(a.z) * float(b.z) + float(a.w) * float(b.w)
  )

func lengthSquared*(q: Quaternion): float32 {.inline.} =
  ## Returns squared quaternion length.
  float32(
    float(q.x) * float(q.x) + float(q.y) * float(q.y) + float(q.z) * float(q.z) + float(q.w) * float(q.w)
  )

func length*(q: Quaternion): float32 {.inline.} =
  ## Returns quaternion length; valid rotations normally have length `1.0`.
  let scale = max(max(abs(q.x), abs(q.y)), max(abs(q.z), abs(q.w)))
  if scale == 0.0'f32:
    0.0'f32
  elif classify(scale) in {fcNan, fcInf, fcNegInf}:
    scale
  else:
    let sx = float(q.x) / float(scale)
    let sy = float(q.y) / float(scale)
    let sz = float(q.z) / float(scale)
    let sw = float(q.w) / float(scale)
    float32(float(scale) * sqrt(sx * sx + sy * sy + sz * sz + sw * sw))

func normalize*(q: Quaternion): Quaternion {.inline.} =
  ## Returns a unit quaternion, or identity for a near-zero input.
  let scale = max(max(abs(q.x), abs(q.y)), max(abs(q.z), abs(q.w)))
  if scale == 0.0'f32:
    Quaternion.identity
  else:
    let sx = q.x / scale
    let sy = q.y / scale
    let sz = q.z / scale
    let sw = q.w / scale
    let len = sqrt(sx * sx + sy * sy + sz * sz + sw * sw)
    if scale <= Epsilon / len:
      Quaternion.identity
    else:
      Quaternion(x: sx / len, y: sy / len, z: sz / len, w: sw / len)

func conjugate*(q: Quaternion): Quaternion {.inline.} =
  ## Negates the vector part; for a unit quaternion this is its inverse.
  Quaternion(x: -q.x, y: -q.y, z: -q.z, w: q.w)

func inverse*(q: Quaternion): Quaternion {.inline.} =
  ## Returns the inverse; `conjugate` is enough for unit quaternions.
  let scale = max(max(abs(q.x), abs(q.y)), max(abs(q.z), abs(q.w)))
  if scale == 0.0'f32:
    Quaternion.identity
  else:
    let sx = q.x / scale
    let sy = q.y / scale
    let sz = q.z / scale
    let sw = q.w / scale
    let scaledLengthSquared = sx * sx + sy * sy + sz * sz + sw * sw
    let scaledLength = sqrt(scaledLengthSquared)
    if scale <= Epsilon / scaledLength:
      Quaternion.identity
    else:
      let factor = (1.0'f32 / scale) / scaledLengthSquared
      Quaternion(x: -sx * factor, y: -sy * factor, z: -sz * factor, w: sw * factor)

func `*`*(q: Quaternion, v: Vector3): Vector3 {.inline.} =
  ## Rotates `v` by the unit quaternion `q`.
  let
    tx = 2.0 * (float(q.y) * float(v.z) - float(q.z) * float(v.y))
    ty = 2.0 * (float(q.z) * float(v.x) - float(q.x) * float(v.z))
    tz = 2.0 * (float(q.x) * float(v.y) - float(q.y) * float(v.x))
  Vector3(
    x: float32(float(v.x) + float(q.w) * tx + float(q.y) * tz - float(q.z) * ty),
    y: float32(float(v.y) + float(q.w) * ty + float(q.z) * tx - float(q.x) * tz),
    z: float32(float(v.z) + float(q.w) * tz + float(q.x) * ty - float(q.y) * tx)
  )

func fromAxisAngle*(axis: Vector3, angle: float32): Quaternion {.inline.} =
  ## Builds a rotation of `angle` radians around `axis`. An axis at or below `Epsilon`
  ## yields identity, matching `normalize`, which returns such vectors unchanged.
  let n = axis.normalize
  if n.lengthSquared <= EpsilonSquared:
    return Quaternion.identity
  let half = angle * 0.5'f32
  let sinHalf = sin(half)
  Quaternion(x: n.x * sinHalf, y: n.y * sinHalf, z: n.z * sinHalf, w: cos(half))

func toAxisAngle*(q: Quaternion): tuple[axis: Vector3, angle: float32] {.inline.} =
  ## Splits a rotation into an axis and an angle in radians.
  var nq = q.normalize
  if nq.w < 0:
    nq = -nq
  let angle = 2.0'f32 * arccos(clamp(nq.w, -1.0'f32, 1.0'f32))
  let s = sqrt(max(0.0'f32, 1.0'f32 - nq.w * nq.w))
  let axis =
    if s < Epsilon:
      Vector3(x: 1, y: 0, z: 0)
    else:
      Vector3(x: nq.x / s, y: nq.y / s, z: nq.z / s)
  (axis, angle)

func fromEuler*(x, y, z: float32): Quaternion {.inline.} =
  ## Creates a quaternion from Euler angles in radians (order: Z, Y, X).
  let
    cx = cos(x * 0.5'f32)
    sx = sin(x * 0.5'f32)
    cy = cos(y * 0.5'f32)
    sy = sin(y * 0.5'f32)
    cz = cos(z * 0.5'f32)
    sz = sin(z * 0.5'f32)
  Quaternion(
    x: sx * cy * cz + cx * sy * sz,
    y: cx * sy * cz - sx * cy * sz,
    z: cx * cy * sz + sx * sy * cz,
    w: cx * cy * cz - sx * sy * sz
  )

func fromEuler*(euler: Vector3): Quaternion {.inline.} =
  ## Builds a quaternion from a `Vector3` of radian angles.
  fromEuler(euler.x, euler.y, euler.z)

func toEuler*(q: Quaternion): Vector3 {.inline.} =
  ## Extracts Euler angles in radians from a quaternion (order: Z, Y, X).
  let nq = q.normalize
  let sinY = 2.0'f32 * (nq.x * nq.z + nq.w * nq.y)
  if sinY >= 0.99999'f32:
    Vector3(
      x: arctan2(2.0'f32 * (nq.x * nq.y + nq.w * nq.z), 1.0'f32 - 2.0'f32 * (nq.x * nq.x + nq.z * nq.z)),
      y: PI / 2.0'f32,
      z: 0.0'f32
    )
  elif sinY <= -0.99999'f32:
    Vector3(
      x: arctan2(-2.0'f32 * (nq.x * nq.y + nq.w * nq.z), 1.0'f32 - 2.0'f32 * (nq.x * nq.x + nq.z * nq.z)),
      y: -PI / 2.0'f32,
      z: 0.0'f32
    )
  else:
    let sinX = 2.0'f32 * (nq.w * nq.x - nq.y * nq.z)
    let cosX = 1.0'f32 - 2.0'f32 * (nq.x * nq.x + nq.y * nq.y)
    let sinZ = 2.0'f32 * (nq.w * nq.z - nq.x * nq.y)
    let cosZ = 1.0'f32 - 2.0'f32 * (nq.y * nq.y + nq.z * nq.z)
    Vector3(x: arctan2(sinX, cosX), y: arcsin(clamp(sinY, -1.0'f32, 1.0'f32)), z: arctan2(sinZ, cosZ))

func fromToRotation*(fromDir, toDir: Vector3): Quaternion {.inline.} =
  ## Computes the shortest rotation between two direction vectors.
  let f = fromDir.normalize
  let t = toDir.normalize
  let d = dot(f, t)
  if d >= 1.0'f32 - Epsilon:
    Quaternion.identity
  elif d <= -1.0'f32 + Epsilon:
    var perp = cross(Vector3.right, f)
    if perp.lengthSquared < EpsilonSquared:
      perp = cross(Vector3.up, f)
    fromAxisAngle(perp.normalize, PI)
  else:
    let c = cross(f, t)
    normalize(Quaternion(x: c.x, y: c.y, z: c.z, w: 1.0'f32 + d))

func lookRotation*(forward: Vector3, up: Vector3 = Vector3.up): Quaternion {.inline.} =
  ## Creates a rotation looking towards `forward` with the given `up` vector.
  let f = forward.normalize
  if f.lengthSquared <= EpsilonSquared:
    return Quaternion.identity

  var upNorm = up.normalize
  if upNorm.lengthSquared <= EpsilonSquared:
    upNorm = Vector3.up

  var r = cross(upNorm, f)
  if r.lengthSquared < EpsilonSquared:
    let fallbackUp =
      if abs(f.y) < 0.999'f32: Vector3.up else: Vector3.right
    r = cross(fallbackUp, f)
  r = r.normalize

  let u = cross(f, r).normalize
  let trace = r.x + u.y + f.z
  if trace > 0.0'f32:
    let s = 0.5'f32 / sqrt(trace + 1.0'f32)
    result = Quaternion(x: (u.z - f.y) * s, y: (f.x - r.z) * s, z: (r.y - u.x) * s, w: 0.25'f32 / s)
  elif r.x > u.y and r.x > f.z:
    let s = 2.0'f32 * sqrt(max(0.0'f32, 1.0'f32 + r.x - u.y - f.z))
    if s < Epsilon:
      result = Quaternion.identity
    else:
      result = Quaternion(x: 0.25'f32 * s, y: (r.y + u.x) / s, z: (f.x + r.z) / s, w: (u.z - f.y) / s)
  elif u.y > f.z:
    let s = 2.0'f32 * sqrt(max(0.0'f32, 1.0'f32 + u.y - r.x - f.z))
    if s < Epsilon:
      result = Quaternion.identity
    else:
      result = Quaternion(x: (r.y + u.x) / s, y: 0.25'f32 * s, z: (u.z + f.y) / s, w: (f.x - r.z) / s)
  else:
    let s = 2.0'f32 * sqrt(max(0.0'f32, 1.0'f32 + f.z - r.x - u.y))
    if s < Epsilon:
      result = Quaternion.identity
    else:
      result = Quaternion(x: (f.x + r.z) / s, y: (u.z + f.y) / s, z: 0.25'f32 * s, w: (r.y - u.x) / s)
  result = result.normalize

func lerp*(a, b: Quaternion, t: float32): Quaternion {.inline.} =
  ## Interpolates the components; use `nlerp` for rotations.
  Quaternion(
    x: float32(float(a.x) + (float(b.x) - float(a.x)) * float(t)),
    y: float32(float(a.y) + (float(b.y) - float(a.y)) * float(t)),
    z: float32(float(a.z) + (float(b.z) - float(a.z)) * float(t)),
    w: float32(float(a.w) + (float(b.w) - float(a.w)) * float(t))
  )

func nlerp*(a, b: Quaternion, t: float32): Quaternion {.inline.} =
  ## Fast normalized linear interpolation along the shortest arc.
  let aNorm = a.normalize
  let bNorm = b.normalize
  let bAdj = if dot(aNorm, bNorm) < 0.0'f32: -bNorm else: bNorm
  normalize(lerp(aNorm, bAdj, t))

func slerp*(a, b: Quaternion, t: float32): Quaternion {.inline.} =
  ## Spherical linear interpolation with constant angular velocity.
  let aNorm = a.normalize
  let bNorm = b.normalize
  var cosTheta = clamp(dot(aNorm, bNorm), -1.0'f32, 1.0'f32)
  var bAdj = bNorm
  if cosTheta < 0.0'f32:
    cosTheta = -cosTheta
    bAdj = -bNorm
  if cosTheta > 1.0'f32 - Epsilon:
    return nlerp(aNorm, bAdj, t)
  let theta = arccos(cosTheta)
  let sinTheta = sin(theta)
  let wa = sin((1.0'f32 - t) * theta) / sinTheta
  let wb = sin(t * theta) / sinTheta
  normalize(aNorm * wa + bAdj * wb)

func angle*(a, b: Quaternion): float32 {.inline.} =
  ## Returns the angle between two rotations, in `[0, PI]`.
  let d = clamp(abs(dot(a.normalize, b.normalize)), 0.0'f32, 1.0'f32)
  arccos(d) * 2.0'f32

func rotateTowards*(current, target: Quaternion, maxRadiansDelta: float32): Quaternion {.inline.} =
  ## Rotates `current` toward `target` by at most `maxRadiansDelta` radians.
  if maxRadiansDelta <= 0.0'f32:
    return current
  let ang = angle(current, target)
  if ang < Epsilon:
    target
  else:
    slerp(current, target, min(1.0'f32, maxRadiansDelta / ang))
