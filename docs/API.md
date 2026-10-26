# PMX Forge API Reference

**Version 1.0.0** · 24 modules · 298 public symbols

> Generated from the Nim sources by [`tools/gen_api_docs.nim`](../tools/gen_api_docs.nim).
> Run `nimble apiDocs` after changing the public API.

<a id="mod-pmxforge"></a>
PMX Forge reads, validates, repairs, and writes PMX 2.0 and 2.1 model files.

Basic usage:

```nim
import pmxforge

let model = readPmx("model.pmx")
validate(model)
writePmx(model, "model-copy.pmx")
```

Reading and writing are independent, every limit is explicit, and the byte overloads
work on host-owned storage. Native builds add the path and stream overloads; browser
and WebAssembly builds use the byte buffers.

## Contents

- **Overview**
  - [Overview](#mod-pmxforge)
- **Core types**
  - [`pmxforge/core/vectors`](#mod-vectors) · 56 symbols
  - [`pmxforge/core/colors`](#mod-colors) · 33 symbols
- **Model and format**
  - [`pmxforge/format/model`](#mod-model) · 6 symbols
  - [`pmxforge/format/enums`](#mod-enums) · 3 symbols
  - [`pmxforge/format/flags`](#mod-flags) · 9 symbols
  - [`pmxforge/format/limits`](#mod-limits) · 4 symbols
  - [`pmxforge/format/errors`](#mod-errors) · 3 symbols
- **Elements**
  - [`pmxforge/format/elements/texture`](#mod-texture) · 6 symbols
  - [`pmxforge/format/elements/vertex`](#mod-vertex) · 23 symbols
  - [`pmxforge/format/elements/face`](#mod-face) · 8 symbols
  - [`pmxforge/format/elements/material`](#mod-material) · 7 symbols
  - [`pmxforge/format/elements/bone`](#mod-bone) · 15 symbols
  - [`pmxforge/format/elements/morph`](#mod-morph) · 20 symbols
  - [`pmxforge/format/elements/display_slot`](#mod-display_slot) · 11 symbols
  - [`pmxforge/format/elements/rigid_body`](#mod-rigid_body) · 8 symbols
  - [`pmxforge/format/elements/joint`](#mod-joint) · 12 symbols
  - [`pmxforge/format/elements/soft_body`](#mod-soft_body) · 14 symbols
- **Serialization**
  - [`pmxforge/format/validation`](#mod-validation) · 6 symbols
  - [`pmxforge/format/io/reader`](#mod-reader) · 6 symbols
  - [`pmxforge/format/io/writer`](#mod-writer) · 7 symbols
- **Byte-level primitives**
  - [`pmxforge/format/io/binary`](#mod-binary) · 32 symbols
  - [`pmxforge/format/io/text_codec`](#mod-text_codec) · 5 symbols
  - [`pmxforge/format/io/file_metadata`](#mod-file_metadata) · 4 symbols
- [Symbol index](#index)

## Core types

<a id="mod-vectors"></a>
### `pmxforge/core/vectors`

Vector and quaternion math.

Provides `Vector2`, `Vector3`, `Vector4`, and `Quaternion` in the PMX axis convention (+X right, +Y up, +Z
forward), with radians for rotations.

<sub>[`src/pmxforge/core/vectors.nim`](../src/pmxforge/core/vectors.nim)</sub>

#### Types

<a id="sym-vectors-0"></a>
##### `Quaternion`

```nim
Quaternion = object
  x*: float32 ## X imaginary component.
  y*: float32 ## Y imaginary component.
  z*: float32 ## Z imaginary component.
  w*: float32 ## W real component.
```

Quaternion rotation (x, y, z, w).

<sub>[`vectors.nim:30`](../src/pmxforge/core/vectors.nim#L30)</sub>

<a id="sym-vectors-1"></a>
##### `Vector2`

```nim
Vector2 = object
  x*: float32 ## X coordinate.
  y*: float32 ## Y coordinate.
```

2D float32 vector.

<sub>[`vectors.nim:15`](../src/pmxforge/core/vectors.nim#L15)</sub>

<a id="sym-vectors-2"></a>
##### `Vector3`

```nim
Vector3 = object
  x*: float32 ## X coordinate (points right).
  y*: float32 ## Y coordinate (points up).
  z*: float32 ## Z coordinate (points forward).
```

3D float32 vector.

<sub>[`vectors.nim:19`](../src/pmxforge/core/vectors.nim#L19)</sub>

<a id="sym-vectors-3"></a>
##### `Vector4`

```nim
Vector4 = object
  x*: float32 ## X component.
  y*: float32 ## Y component.
  z*: float32 ## Z component.
  w*: float32 ## W component.
```

4D float32 vector.

<sub>[`vectors.nim:24`](../src/pmxforge/core/vectors.nim#L24)</sub>

#### Constants

<a id="sym-vectors-4"></a>
##### `Deg2Rad`

```nim
Deg2Rad = 0.017453292519943295
```

Degrees-to-radians factor.

<sub>[`vectors.nim:11`](../src/pmxforge/core/vectors.nim#L11)</sub>

<a id="sym-vectors-5"></a>
##### `Epsilon`

```nim
Epsilon = 0.0000001'f32
```

Small threshold for zero-length and division checks.

<sub>[`vectors.nim:9`](../src/pmxforge/core/vectors.nim#L9)</sub>

<a id="sym-vectors-6"></a>
##### `Rad2Deg`

```nim
Rad2Deg = 57.29577951308232
```

Radians-to-degrees factor.

<sub>[`vectors.nim:12`](../src/pmxforge/core/vectors.nim#L12)</sub>

#### Procedures

<a id="sym-vectors-7"></a>
##### `abs`

```nim
func abs(v: Vector2): Vector2
func abs(v: Vector3): Vector3
func abs(v: Vector4): Vector4
```

Takes the absolute value of each component.

<sub>[`vectors.nim:244`](../src/pmxforge/core/vectors.nim#L244)</sub>

<a id="sym-vectors-8"></a>
##### `angle`

```nim
func angle(a, b: Vector2): float32
func angle(a, b: Vector3): float32
```

Returns the angle between `a` and `b` in radians.

```nim
func angle(a, b: Quaternion): float32
```

Returns the angle between two rotations, in `[0, PI]`.

<sub>[`vectors.nim:230`](../src/pmxforge/core/vectors.nim#L230)</sub>

<a id="sym-vectors-9"></a>
##### `back`

```nim
func back(T: type Vector3): Vector3
```

World back direction (0, 0, -1).

<sub>[`vectors.nim:96`](../src/pmxforge/core/vectors.nim#L96)</sub>

<a id="sym-vectors-10"></a>
##### `clamp`

```nim
func clamp(v, lo, hi: Vector2): Vector2
func clamp(v, lo, hi: Vector3): Vector3
```

Clamps each component of `v` to the supplied bounds.

<sub>[`vectors.nim:256`](../src/pmxforge/core/vectors.nim#L256)</sub>

<a id="sym-vectors-11"></a>
##### `conjugate`

```nim
func conjugate(q: Quaternion): Quaternion
```

Negates the vector part; for a unit quaternion this is its inverse.

<sub>[`vectors.nim:680`](../src/pmxforge/core/vectors.nim#L680)</sub>

<a id="sym-vectors-12"></a>
##### `cross`

```nim
func cross(a, b: Vector3): Vector3
```

Returns the cross product of `a` and `b`.

<sub>[`vectors.nim:325`](../src/pmxforge/core/vectors.nim#L325)</sub>

<a id="sym-vectors-13"></a>
##### `distance`

```nim
func distance(a, b: Vector2): float32
func distance(a, b: Vector3): float32
func distance(a, b: Vector4): float32
```

Returns Euclidean distance.

<sub>[`vectors.nim:207`](../src/pmxforge/core/vectors.nim#L207)</sub>

<a id="sym-vectors-14"></a>
##### `distanceSquared`

```nim
func distanceSquared(a, b: Vector2): float32
func distanceSquared(a, b: Vector3): float32
```

Returns squared distance without taking a square root.

<sub>[`vectors.nim:211`](../src/pmxforge/core/vectors.nim#L211)</sub>

<a id="sym-vectors-15"></a>
##### `dot`

```nim
func dot(a, b: Vector2): float32
func dot(a, b: Vector3): float32
func dot(a, b: Vector4): float32
```

Returns the dot product.

```nim
func dot(a, b: Quaternion): float32
```

Returns the quaternion dot product.

<sub>[`vectors.nim:169`](../src/pmxforge/core/vectors.nim#L169)</sub>

<a id="sym-vectors-16"></a>
##### `down`

```nim
func down(T: type Vector3): Vector3
```

World down direction (0, -1, 0).

<sub>[`vectors.nim:80`](../src/pmxforge/core/vectors.nim#L80)</sub>

<a id="sym-vectors-17"></a>
##### `forward`

```nim
func forward(T: type Vector3): Vector3
```

World forward direction (0, 0, 1).

<sub>[`vectors.nim:92`](../src/pmxforge/core/vectors.nim#L92)</sub>

<a id="sym-vectors-18"></a>
##### `fromAxisAngle`

```nim
func fromAxisAngle(axis: Vector3, angle: float32): Quaternion
```

Builds a rotation of `angle` radians around `axis`. An axis at or below `Epsilon` yields identity, matching
`normalize`, which returns such vectors unchanged.

<sub>[`vectors.nim:714`](../src/pmxforge/core/vectors.nim#L714)</sub>

<a id="sym-vectors-19"></a>
##### `fromEuler`

```nim
func fromEuler(x, y, z: float32): Quaternion
```

Creates a quaternion from Euler angles in radians (order: Z, Y, X).

```nim
func fromEuler(euler: Vector3): Quaternion
```

Builds a quaternion from a `Vector3` of radian angles.

<sub>[`vectors.nim:738`](../src/pmxforge/core/vectors.nim#L738)</sub>

<a id="sym-vectors-20"></a>
##### `fromToRotation`

```nim
func fromToRotation(fromDir, toDir: Vector3): Quaternion
```

Computes the shortest rotation between two direction vectors.

<sub>[`vectors.nim:781`](../src/pmxforge/core/vectors.nim#L781)</sub>

<a id="sym-vectors-21"></a>
##### `hash`

```nim
func hash(value: Vector2): Hash
func hash(value: Vector3): Hash
func hash(value: Vector4): Hash
```

Hashes vector components consistently with exact equality.

```nim
func hash(value: Quaternion): Hash
```

Hashes quaternion components consistently with exact equality.

<sub>[`vectors.nim:40`](../src/pmxforge/core/vectors.nim#L40)</sub>

<a id="sym-vectors-22"></a>
##### `identity`

```nim
func identity(T: type Quaternion): Quaternion
```

Identity rotation (0, 0, 0, 1).

<sub>[`vectors.nim:108`](../src/pmxforge/core/vectors.nim#L108)</sub>

<a id="sym-vectors-23"></a>
##### `inverse`

```nim
func inverse(q: Quaternion): Quaternion
```

Returns the inverse; `conjugate` is enough for unit quaternions.

<sub>[`vectors.nim:684`](../src/pmxforge/core/vectors.nim#L684)</sub>

<a id="sym-vectors-24"></a>
##### `left`

```nim
func left(T: type Vector3): Vector3
```

World left direction (-1, 0, 0).

<sub>[`vectors.nim:88`](../src/pmxforge/core/vectors.nim#L88)</sub>

<a id="sym-vectors-25"></a>
##### `length`

```nim
func length(v: Vector2): float32
func length(v: Vector3): float32
func length(v: Vector4): float32
```

Returns Euclidean length.

```nim
func length(q: Quaternion): float32
```

Returns quaternion length; valid rotations normally have length `1.0`.

<sub>[`vectors.nim:177`](../src/pmxforge/core/vectors.nim#L177)</sub>

<a id="sym-vectors-26"></a>
##### `lengthSquared`

```nim
func lengthSquared(v: Vector2): float32
func lengthSquared(v: Vector3): float32
func lengthSquared(v: Vector4): float32
```

Returns squared length; use it when only comparing distances.

```nim
func lengthSquared(q: Quaternion): float32
```

Returns squared quaternion length.

<sub>[`vectors.nim:173`](../src/pmxforge/core/vectors.nim#L173)</sub>

<a id="sym-vectors-27"></a>
##### `lerp`

```nim
func lerp(a, b: Vector2, t: float32): Vector2
func lerp(a, b: Vector3, t: float32): Vector3
func lerp(a, b: Vector4, t: float32): Vector4
```

Linearly interpolates from `a` to `b`; `t = 0` returns `a`.

```nim
func lerp(a, b: Quaternion, t: float32): Quaternion
```

Interpolates the components; use `nlerp` for rotations.

<sub>[`vectors.nim:215`](../src/pmxforge/core/vectors.nim#L215)</sub>

<a id="sym-vectors-28"></a>
##### `lookRotation`

```nim
func lookRotation(forward: Vector3, up: Vector3 = Vector3.up): Quaternion
```

Creates a rotation looking towards `forward` with the given `up` vector.

<sub>[`vectors.nim:797`](../src/pmxforge/core/vectors.nim#L797)</sub>

<a id="sym-vectors-29"></a>
##### `max`

```nim
func max(a, b: Vector2): Vector2
func max(a, b: Vector3): Vector3
```

Takes the maximum of each component.

<sub>[`vectors.nim:252`](../src/pmxforge/core/vectors.nim#L252)</sub>

<a id="sym-vectors-30"></a>
##### `min`

```nim
func min(a, b: Vector2): Vector2
func min(a, b: Vector3): Vector3
```

Takes the minimum of each component.

<sub>[`vectors.nim:248`](../src/pmxforge/core/vectors.nim#L248)</sub>

<a id="sym-vectors-31"></a>
##### `moveTowards`

```nim
func moveTowards(current, target: Vector3, maxDelta: float32): Vector3
```

Moves `current` toward `target` by at most `maxDelta`.

<sub>[`vectors.nim:453`](../src/pmxforge/core/vectors.nim#L453)</sub>

<a id="sym-vectors-32"></a>
##### `nlerp`

```nim
func nlerp(a, b: Quaternion, t: float32): Quaternion
```

Fast normalized linear interpolation along the shortest arc.

<sub>[`vectors.nim:848`](../src/pmxforge/core/vectors.nim#L848)</sub>

<a id="sym-vectors-33"></a>
##### `normalize`

```nim
func normalize(v: Vector2): Vector2
func normalize(v: Vector3): Vector3
func normalize(v: Vector4): Vector4
```

Returns a unit vector, or `v` when it is near zero.

```nim
func normalize(q: Quaternion): Quaternion
```

Returns a unit quaternion, or identity for a near-zero input.

<sub>[`vectors.nim:189`](../src/pmxforge/core/vectors.nim#L189)</sub>

<a id="sym-vectors-34"></a>
##### `one`

```nim
func one(T: type Vector2): Vector2
```

Vector with both components set to 1.

```nim
func one(T: type Vector3): Vector3
func one(T: type Vector4): Vector4
```

Vector with all components set to 1.

<sub>[`vectors.nim:64`](../src/pmxforge/core/vectors.nim#L64)</sub>

<a id="sym-vectors-35"></a>
##### `perpendicular`

```nim
func perpendicular(v: Vector2): Vector2
```

Rotates `v` 90 degrees counter-clockwise.

<sub>[`vectors.nim:203`](../src/pmxforge/core/vectors.nim#L203)</sub>

<a id="sym-vectors-36"></a>
##### `project`

```nim
func project(v, onNormal: Vector3): Vector3
```

Projects `v` onto `onNormal`; a near-zero normal returns zero.

<sub>[`vectors.nim:391`](../src/pmxforge/core/vectors.nim#L391)</sub>

<a id="sym-vectors-37"></a>
##### `projectOnPlane`

```nim
func projectOnPlane(v, planeNormal: Vector3): Vector3
```

Removes the component of `v` along `planeNormal`.

<sub>[`vectors.nim:408`](../src/pmxforge/core/vectors.nim#L408)</sub>

<a id="sym-vectors-38"></a>
##### `reflect`

```nim
func reflect(v, normal: Vector2): Vector2
func reflect(v, normal: Vector3): Vector3
```

Reflects `v` across a surface; `normal` must be unit length.

<sub>[`vectors.nim:222`](../src/pmxforge/core/vectors.nim#L222)</sub>

<a id="sym-vectors-39"></a>
##### `right`

```nim
func right(T: type Vector3): Vector3
```

World right direction (1, 0, 0).

<sub>[`vectors.nim:84`](../src/pmxforge/core/vectors.nim#L84)</sub>

<a id="sym-vectors-40"></a>
##### `rotateTowards`

```nim
func rotateTowards(current, target: Quaternion, maxRadiansDelta: float32): Quaternion
```

Rotates `current` toward `target` by at most `maxRadiansDelta` radians.

<sub>[`vectors.nim:877`](../src/pmxforge/core/vectors.nim#L877)</sub>

<a id="sym-vectors-41"></a>
##### `signedAngle`

```nim
func signedAngle(a, b, axis: Vector3): float32
```

Returns the signed angle in radians from `a` to `b` around `axis`.

<sub>[`vectors.nim:428`](../src/pmxforge/core/vectors.nim#L428)</sub>

<a id="sym-vectors-42"></a>
##### `slerp`

```nim
func slerp(a, b: Quaternion, t: float32): Quaternion
```

Spherical linear interpolation with constant angular velocity.

<sub>[`vectors.nim:855`](../src/pmxforge/core/vectors.nim#L855)</sub>

<a id="sym-vectors-43"></a>
##### `toAxisAngle`

```nim
func toAxisAngle(q: Quaternion): tuple[axis: Vector3, angle: float32]
```

Splits a rotation into an axis and an angle in radians.

<sub>[`vectors.nim:724`](../src/pmxforge/core/vectors.nim#L724)</sub>

<a id="sym-vectors-44"></a>
##### `toEuler`

```nim
func toEuler(q: Quaternion): Vector3
```

Extracts Euler angles in radians from a quaternion (order: Z, Y, X).

<sub>[`vectors.nim:758`](../src/pmxforge/core/vectors.nim#L758)</sub>

<a id="sym-vectors-45"></a>
##### `up`

```nim
func up(T: type Vector3): Vector3
```

World up direction (0, 1, 0).

<sub>[`vectors.nim:76`](../src/pmxforge/core/vectors.nim#L76)</sub>

<a id="sym-vectors-46"></a>
##### `zero`

```nim
func zero(T: type Vector2): Vector2
```

Zero vector (0, 0).

```nim
func zero(T: type Vector3): Vector3
```

Zero vector (0, 0, 0).

```nim
func zero(T: type Vector4): Vector4
```

Zero vector (0, 0, 0, 0).

<sub>[`vectors.nim:60`](../src/pmxforge/core/vectors.nim#L60)</sub>

#### Operators

<a id="sym-vectors-47"></a>
##### `*=`

```nim
func `*=`(a: var Vector2, s: float32)
func `*=`(a: var Vector3, s: float32)
func `*=`(a: var Vector4, s: float32)
```

Scales `a` in place by `s`.

<sub>[`vectors.nim:159`](../src/pmxforge/core/vectors.nim#L159)</sub>

<a id="sym-vectors-48"></a>
##### `*`

```nim
func `*`(v: Vector2, s: float32): Vector2
func `*`(s: float32, v: Vector2): Vector2
func `*`(v: Vector3, s: float32): Vector3
func `*`(s: float32, v: Vector3): Vector3
func `*`(v: Vector4, s: float32): Vector4
func `*`(s: float32, v: Vector4): Vector4
```

Multiplies every component by `s`.

```nim
func `*`(a, b: Vector2): Vector2
func `*`(a, b: Vector3): Vector3
func `*`(a, b: Vector4): Vector4
```

Multiplies corresponding components.

```nim
func `*`(a, b: Quaternion): Quaternion
```

Hamilton product (applies rotation `b` then `a`).

```nim
func `*`(q: Quaternion, s: float32): Quaternion
func `*`(s: float32, q: Quaternion): Quaternion
```

Multiplies every quaternion component by `s`.

```nim
func `*`(q: Quaternion, v: Vector3): Vector3
```

Rotates `v` by the unit quaternion `q`.

<sub>[`vectors.nim:128`](../src/pmxforge/core/vectors.nim#L128)</sub>

<a id="sym-vectors-49"></a>
##### `+=`

```nim
func `+=`(a: var Vector2, b: Vector2)
func `+=`(a: var Vector3, b: Vector3)
func `+=`(a: var Vector4, b: Vector4)
```

Adds `b` to `a` in place.

<sub>[`vectors.nim:149`](../src/pmxforge/core/vectors.nim#L149)</sub>

<a id="sym-vectors-50"></a>
##### `+`

```nim
func `+`(a, b: Vector2): Vector2
func `+`(a, b: Vector3): Vector3
func `+`(a, b: Vector4): Vector4
```

Adds corresponding components.

```nim
func `+`(a, b: Quaternion): Quaternion
```

Adds corresponding quaternion components; the result is not normalized.

<sub>[`vectors.nim:116`](../src/pmxforge/core/vectors.nim#L116)</sub>

<a id="sym-vectors-51"></a>
##### `-=`

```nim
func `-=`(a: var Vector2, b: Vector2)
func `-=`(a: var Vector3, b: Vector3)
func `-=`(a: var Vector4, b: Vector4)
```

Subtracts `b` from `a` in place.

<sub>[`vectors.nim:154`](../src/pmxforge/core/vectors.nim#L154)</sub>

<a id="sym-vectors-52"></a>
##### `-`

```nim
func `-`(a, b: Vector2): Vector2
func `-`(a, b: Vector3): Vector3
func `-`(a, b: Vector4): Vector4
```

Subtracts corresponding components.

```nim
func `-`(a: Vector2): Vector2
func `-`(a: Vector3): Vector3
func `-`(a: Vector4): Vector4
```

Negates every component.

```nim
func `-`(a, b: Quaternion): Quaternion
```

Subtracts corresponding quaternion components.

```nim
func `-`(q: Quaternion): Quaternion
```

Negates all components; `q` and `-q` are the same rotation.

<sub>[`vectors.nim:120`](../src/pmxforge/core/vectors.nim#L120)</sub>

<a id="sym-vectors-53"></a>
##### `/=`

```nim
func `/=`(a: var Vector2, s: float32)
func `/=`(a: var Vector3, s: float32)
func `/=`(a: var Vector4, s: float32)
```

Divides `a` in place by `s`.

<sub>[`vectors.nim:164`](../src/pmxforge/core/vectors.nim#L164)</sub>

<a id="sym-vectors-54"></a>
##### `/`

```nim
func `/`(v: Vector2, s: float32): Vector2
func `/`(v: Vector3, s: float32): Vector3
func `/`(v: Vector4, s: float32): Vector4
```

Divides every component by `s` directly: computing a reciprocal first would overflow for a subnormal divisor
and turn `x / x` into an infinity.

```nim
func `/`(a, b: Vector2): Vector2
func `/`(a, b: Vector3): Vector3
func `/`(a, b: Vector4): Vector4
```

Divides corresponding components.

```nim
func `/`(q: Quaternion, s: float32): Quaternion
```

Divides every quaternion component by `s` directly, so a subnormal divisor cannot turn equal components into
infinities.

<sub>[`vectors.nim:140`](../src/pmxforge/core/vectors.nim#L140)</sub>

<a id="sym-vectors-55"></a>
##### `==`

```nim
func `==`(a, b: Vector2): bool
func `==`(a, b: Vector3): bool
func `==`(a, b: Vector4): bool
func `==`(a, b: Quaternion): bool
```

Checks exact component equality.

<sub>[`vectors.nim:112`](../src/pmxforge/core/vectors.nim#L112)</sub>

<a id="mod-colors"></a>
### `pmxforge/core/colors`

Color types and conversion helpers.

Provides `RGB` and `RGBA` with clamping, sRGB conversion, and hex parsing for
material, morph, and edge colors.

<sub>[`src/pmxforge/core/colors.nim`](../src/pmxforge/core/colors.nim)</sub>

#### Types

<a id="sym-colors-0"></a>
##### `RGB`

```nim
RGB = object
  r*: float32 ## Red channel (0.0 to 1.0).
  g*: float32 ## Green channel (0.0 to 1.0).
  b*: float32 ## Blue channel (0.0 to 1.0).
```

RGB color with normalized float32 channels.

<sub>[`colors.nim:9`](../src/pmxforge/core/colors.nim#L9)</sub>

<a id="sym-colors-1"></a>
##### `RGBA`

```nim
RGBA = object
  r*: float32 ## Red channel (0.0 to 1.0).
  g*: float32 ## Green channel (0.0 to 1.0).
  b*: float32 ## Blue channel (0.0 to 1.0).
  a*: float32 ## Alpha channel (0.0 to 1.0).
```

RGBA color with normalized float32 channels and alpha.

<sub>[`colors.nim:14`](../src/pmxforge/core/colors.nim#L14)</sub>

#### Procedures

<a id="sym-colors-2"></a>
##### `black`

```nim
func black(T: type RGB): RGB
```

Opaque black (0, 0, 0).

```nim
func black(T: type RGBA): RGBA
```

Opaque black (0, 0, 0, 1).

<sub>[`colors.nim:65`](../src/pmxforge/core/colors.nim#L65)</sub>

<a id="sym-colors-3"></a>
##### `blue`

```nim
func blue(T: type RGB): RGB
```

Opaque blue (0, 0, 1).

```nim
func blue(T: type RGBA): RGBA
```

Opaque blue (0, 0, 1, 1).

<sub>[`colors.nim:89`](../src/pmxforge/core/colors.nim#L89)</sub>

<a id="sym-colors-4"></a>
##### `clamp01`

```nim
func clamp01(c: RGB): RGB
```

Clamps all RGB channels to `[0, 1]`.

```nim
func clamp01(c: RGBA): RGBA
```

Clamps all RGBA channels to `[0, 1]`.

<sub>[`colors.nim:158`](../src/pmxforge/core/colors.nim#L158)</sub>

<a id="sym-colors-5"></a>
##### `cyan`

```nim
func cyan(T: type RGB): RGB
```

Opaque cyan (0, 1, 1).

```nim
func cyan(T: type RGBA): RGBA
```

Opaque cyan (0, 1, 1, 1).

<sub>[`colors.nim:97`](../src/pmxforge/core/colors.nim#L97)</sub>

<a id="sym-colors-6"></a>
##### `fromBytes`

```nim
func fromBytes(r, g, b: uint8): RGB
```

Converts 8-bit RGB channels to normalized values. `255` maps to `1.0`.

```nim
func fromBytes(r, g, b, a: uint8): RGBA
```

Converts 8-bit RGBA channels to normalized values. `255` maps to `1.0`.

<sub>[`colors.nim:129`](../src/pmxforge/core/colors.nim#L129)</sub>

<a id="sym-colors-7"></a>
##### `fromHexRGB`

```nim
proc fromHexRGB(hexStr: string): RGB {.raises: [ValueError].}
```

Parses six hexadecimal digits, with or without a leading `#`.

<sub>[`colors.nim:353`](../src/pmxforge/core/colors.nim#L353)</sub>

<a id="sym-colors-8"></a>
##### `fromHexRGBA`

```nim
proc fromHexRGBA(hexStr: string): RGBA {.raises: [ValueError].}
```

Parses eight hexadecimal digits, with or without a leading `#`.

<sub>[`colors.nim:362`](../src/pmxforge/core/colors.nim#L362)</sub>

<a id="sym-colors-9"></a>
##### `green`

```nim
func green(T: type RGB): RGB
```

Opaque green (0, 1, 0).

```nim
func green(T: type RGBA): RGBA
```

Opaque green (0, 1, 0, 1).

<sub>[`colors.nim:85`](../src/pmxforge/core/colors.nim#L85)</sub>

<a id="sym-colors-10"></a>
##### `hash`

```nim
func hash(value: RGB): Hash
```

Hashes the channels; `0.0` and `-0.0` hash the same.

```nim
func hash(value: RGBA): Hash
```

Hashes the channels, alpha included; `0.0` and `-0.0` hash alike.

<sub>[`colors.nim:24`](../src/pmxforge/core/colors.nim#L24)</sub>

<a id="sym-colors-11"></a>
##### `lerp`

```nim
func lerp(a, b: RGB, t: float32): RGB
```

Interpolates from `a` to `b`; `t` is not clamped.

```nim
func lerp(a, b: RGBA, t: float32): RGBA
```

Interpolates from `a` to `b`, alpha included; `t` is not clamped.

<sub>[`colors.nim:288`](../src/pmxforge/core/colors.nim#L288)</sub>

<a id="sym-colors-12"></a>
##### `magenta`

```nim
func magenta(T: type RGB): RGB
```

Opaque magenta (1, 0, 1).

```nim
func magenta(T: type RGBA): RGBA
```

Opaque magenta (1, 0, 1, 1).

<sub>[`colors.nim:101`](../src/pmxforge/core/colors.nim#L101)</sub>

<a id="sym-colors-13"></a>
##### `red`

```nim
func red(T: type RGB): RGB
```

Opaque red (1, 0, 0).

```nim
func red(T: type RGBA): RGBA
```

Opaque red (1, 0, 0, 1).

<sub>[`colors.nim:81`](../src/pmxforge/core/colors.nim#L81)</sub>

<a id="sym-colors-14"></a>
##### `rgb`

```nim
func rgb(r, g, b: float32): RGB
```

Creates an RGB color from normalized channels.

```nim
func rgb(c: RGBA): RGB
```

Drops alpha and returns the RGB channels.

<sub>[`colors.nim:53`](../src/pmxforge/core/colors.nim#L53)</sub>

<a id="sym-colors-15"></a>
##### `rgba`

```nim
func rgba(r, g, b, a: float32): RGBA
```

Creates an RGBA color from normalized channels.

<sub>[`colors.nim:57`](../src/pmxforge/core/colors.nim#L57)</sub>

<a id="sym-colors-16"></a>
##### `toBytes`

```nim
func toBytes(c: RGB): tuple[r, g, b: uint8]
```

Converts normalized RGB channels to rounded 8-bit channels.

```nim
func toBytes(c: RGBA): tuple[r, g, b, a: uint8]
```

Converts normalized RGBA channels to rounded 8-bit channels.

<sub>[`colors.nim:142`](../src/pmxforge/core/colors.nim#L142)</sub>

<a id="sym-colors-17"></a>
##### `toHex`

```nim
func toHex(c: RGB): string
```

Formats RGB as six uppercase hexadecimal digits with a `#` prefix.

```nim
func toHex(c: RGBA): string
```

Formats RGBA as eight uppercase hexadecimal digits with a `#` prefix.

<sub>[`colors.nim:371`](../src/pmxforge/core/colors.nim#L371)</sub>

<a id="sym-colors-18"></a>
##### `toLinear`

```nim
func toLinear(c: RGB): RGB
```

Converts RGB from sRGB transfer values to linear light.

```nim
func toLinear(c: RGBA): RGBA
```

Converts the RGB channels from sRGB transfer values to linear light.

<sub>[`colors.nim:321`](../src/pmxforge/core/colors.nim#L321)</sub>

<a id="sym-colors-19"></a>
##### `toSRGB`

```nim
func toSRGB(c: RGB): RGB
```

Converts linear-light RGB to sRGB transfer values.

```nim
func toSRGB(c: RGBA): RGBA
```

Converts the RGB channels from linear light to sRGB transfer values.

<sub>[`colors.nim:325`](../src/pmxforge/core/colors.nim#L325)</sub>

<a id="sym-colors-20"></a>
##### `transparent`

```nim
func transparent(T: type RGBA): RGBA
```

Fully transparent black (0, 0, 0, 0).

<sub>[`colors.nim:77`](../src/pmxforge/core/colors.nim#L77)</sub>

<a id="sym-colors-21"></a>
##### `white`

```nim
func white(T: type RGB): RGB
```

Opaque white (1, 1, 1).

```nim
func white(T: type RGBA): RGBA
```

Opaque white (1, 1, 1, 1).

<sub>[`colors.nim:61`](../src/pmxforge/core/colors.nim#L61)</sub>

<a id="sym-colors-22"></a>
##### `withAlpha`

```nim
func withAlpha(c: RGB, a: float32): RGBA
```

Adds an alpha channel to an RGB value.

<sub>[`colors.nim:154`](../src/pmxforge/core/colors.nim#L154)</sub>

<a id="sym-colors-23"></a>
##### `yellow`

```nim
func yellow(T: type RGB): RGB
```

Opaque yellow (1, 1, 0).

```nim
func yellow(T: type RGBA): RGBA
```

Opaque yellow (1, 1, 0, 1).

<sub>[`colors.nim:93`](../src/pmxforge/core/colors.nim#L93)</sub>

#### Operators

<a id="sym-colors-24"></a>
##### `*=`

```nim
func `*=`(a: var RGB, s: float32)
```

Scales `a` in place by `s`.

```nim
func `*=`(a: var RGB, b: RGB)
```

Multiplies RGB channels component by component in place.

```nim
func `*=`(a: var RGBA, s: float32)
```

Scales every RGBA channel in place by `s`.

```nim
func `*=`(a: var RGBA, b: RGBA)
```

Multiplies RGBA channels component by component in place.

<sub>[`colors.nim:235`](../src/pmxforge/core/colors.nim#L235)</sub>

<a id="sym-colors-25"></a>
##### `*`

```nim
func `*`(c: RGB, s: float32): RGB
func `*`(s: float32, c: RGB): RGB
```

Scales every RGB channel by `s`.

```nim
func `*`(a, b: RGB): RGB
```

Multiplies RGB channels component by component.

```nim
func `*`(c: RGBA, s: float32): RGBA
func `*`(s: float32, c: RGBA): RGBA
```

Scales every RGBA channel, including alpha, by `s`.

```nim
func `*`(a, b: RGBA): RGBA
```

Multiplies RGBA channels component by component.

<sub>[`colors.nim:190`](../src/pmxforge/core/colors.nim#L190)</sub>

<a id="sym-colors-26"></a>
##### `+=`

```nim
func `+=`(a: var RGB, b: RGB)
```

Adds `b` to `a` in place.

```nim
func `+=`(a: var RGBA, b: RGBA)
```

Adds `b` to `a` in place, including alpha.

<sub>[`colors.nim:223`](../src/pmxforge/core/colors.nim#L223)</sub>

<a id="sym-colors-27"></a>
##### `+`

```nim
func `+`(a, b: RGB): RGB
```

Adds corresponding RGB channels.

```nim
func `+`(a, b: RGBA): RGBA
```

Adds corresponding RGBA channels.

<sub>[`colors.nim:174`](../src/pmxforge/core/colors.nim#L174)</sub>

<a id="sym-colors-28"></a>
##### `-=`

```nim
func `-=`(a: var RGB, b: RGB)
```

Subtracts `b` from `a` in place.

```nim
func `-=`(a: var RGBA, b: RGBA)
```

Subtracts `b` from `a` in place, including alpha.

<sub>[`colors.nim:229`](../src/pmxforge/core/colors.nim#L229)</sub>

<a id="sym-colors-29"></a>
##### `-`

```nim
func `-`(a, b: RGB): RGB
```

Subtracts corresponding RGB channels.

```nim
func `-`(a, b: RGBA): RGBA
```

Subtracts corresponding RGBA channels.

<sub>[`colors.nim:182`](../src/pmxforge/core/colors.nim#L182)</sub>

<a id="sym-colors-30"></a>
##### `/=`

```nim
func `/=`(a: var RGB, s: float32)
```

Divides every RGB channel in place by `s`.

```nim
func `/=`(a: var RGBA, s: float32)
```

Divides every RGBA channel in place by `s`.

<sub>[`colors.nim:247`](../src/pmxforge/core/colors.nim#L247)</sub>

<a id="sym-colors-31"></a>
##### `/`

```nim
func `/`(c: RGB, s: float32): RGB
```

Divides every channel by `s` directly: computing a reciprocal first would overflow for subnormal divisors and
turn `x / x` into an infinity.

```nim
func `/`(c: RGBA, s: float32): RGBA
```

Divides every channel, including alpha, by `s`.

<sub>[`colors.nim:214`](../src/pmxforge/core/colors.nim#L214)</sub>

<a id="sym-colors-32"></a>
##### `==`

```nim
func `==`(a, b: RGB): bool
```

Compares RGB channels exactly.

```nim
func `==`(a, b: RGBA): bool
```

Compares RGBA channels exactly, including alpha.

<sub>[`colors.nim:166`](../src/pmxforge/core/colors.nim#L166)</sub>

## Model and format

<a id="mod-model"></a>
### `pmxforge/format/model`

PMX model container.

Provides `PmxModel` with the complete element set, plus `copy`, comparison, and the in-place `repair` pass
that normalizes a damaged model.

<sub>[`src/pmxforge/format/model.nim`](../src/pmxforge/format/model.nim)</sub>

#### Types

<a id="sym-model-0"></a>
##### `PmxModel`

```nim
PmxModel = ref object
  version*: PmxVersion ## Format version (pmx20 or pmx21).
  nameJA*: string ## Japanese model name.
  nameEN*: string ## English / universal model name.
  commentsJA*: string ## Japanese description / comments.
  commentsEN*: string ## English description / comments.
  textEncoding*: TextEncoding ## Internal string encoding (UTF-8 or UTF-16LE).
  additionalUvCount*: int32 ## Number of extra UV channels per vertex (0 to 4).
  directory*: string ## Directory path for resolving relative texture files.
  vertices*: seq[Vertex] ## Vertex buffer.
  faces*: seq[Face] ## Triangle face list.
  textures*: seq[Texture] ## Texture file path table.
  materials*: seq[Material] ## Material and rendering settings.
  bones*: seq[Bone] ## Skeleton hierarchy and IK chains.
  morphs*: seq[Morph] ## Blend shape morphs.
  displayFrames*: seq[DisplaySlot] ## UI display groups for bones and morphs.
  rigidBodies*: seq[RigidBody] ## Bullet physics rigid bodies.
  joints*: seq[Joint] ## Physics constraint joints.
  softBodies*: seq[SoftBody] ## Soft body simulation records (PMX 2.1).
```

PMX model document containing all geometry, rigging, and physics data.

<sub>[`model.nim:16`](../src/pmxforge/format/model.nim#L16)</sub>

#### Procedures

<a id="sym-model-1"></a>
##### `copy`

```nim
proc copy(obj: PmxModel): PmxModel
```

Returns an independent deep copy of the entire model.

<sub>[`model.nim:101`](../src/pmxforge/format/model.nim#L101)</sub>

<a id="sym-model-2"></a>
##### `newPmxModel`

```nim
proc newPmxModel(
  nameJA = "",
  version = pmx21,
  textEncoding = teUTF8,
  nameEN = nameJA,
  commentsJA = "",
  commentsEN = "",
  additionalUvCount = 0'i32,
  directory = "",
  vertices: seq[Vertex] = @[],
  faces: seq[Face] = @[],
  textures: seq[Texture] = @[],
  materials: seq[Material] = @[],
  bones: seq[Bone] = @[],
  morphs: seq[Morph] = @[],
  displayFrames: seq[DisplaySlot] = @[],
  rigidBodies: seq[RigidBody] = @[],
  joints: seq[Joint] = @[],
  softBodies: seq[SoftBody] = @[]
): PmxModel {.raises: [ValueError].}
```

Creates a new PMX model, deep-copying all provided elements.

<sub>[`model.nim:38`](../src/pmxforge/format/model.nim#L38)</sub>

<a id="sym-model-3"></a>
##### `repair`

```nim
proc repair(obj: PmxModel) {.raises: [ValueError].}
```

Repairs the model in place: clamps values, breaks cycles, and fixes references. It keeps the declared version,
so PMX 2.1 data inside a 2.0 model still fails `validate`.

<sub>[`model.nim:335`](../src/pmxforge/format/model.nim#L335)</sub>

<a id="sym-model-4"></a>
##### `samePmxContent`

```nim
proc samePmxContent(a, b: PmxModel): bool
```

Compares serializable model content, ignoring the runtime `directory` path.

<sub>[`model.nim:84`](../src/pmxforge/format/model.nim#L84)</sub>

#### Operators

<a id="sym-model-5"></a>
##### `==`

```nim
proc `==`(a, b: PmxModel): bool
```

Compares models for full equality, including the `directory` field.

<sub>[`model.nim:95`](../src/pmxforge/format/model.nim#L95)</sub>

<a id="mod-enums"></a>
### `pmxforge/format/enums`

Header enumerations.

Provides `PmxVersion` and `TextEncoding`, whose ordinals are part of the wire format, plus the checked
conversion used by the header.

<sub>[`src/pmxforge/format/enums.nim`](../src/pmxforge/format/enums.nim)</sub>

#### Types

<a id="sym-enums-0"></a>
##### `PmxVersion`

```nim
PmxVersion = enum
  pmx20, ## Original format, without soft bodies or QDEF.
  pmx21 ## PMX 2.1 (supports soft bodies, vertex QDEF, additional morphs).
```

PMX format version.

<sub>[`enums.nim:9`](../src/pmxforge/format/enums.nim#L9)</sub>

<a id="sym-enums-1"></a>
##### `TextEncoding`

```nim
TextEncoding {.size: 4.} = enum
  teUTF16LE = 0, ## UTF-16 little-endian.
  teUTF8 = 1 ## UTF-8.
```

Text encoding used across PMX strings.

<sub>[`enums.nim:13`](../src/pmxforge/format/enums.nim#L13)</sub>

#### Procedures

<a id="sym-enums-2"></a>
##### `toFileVersion`

```nim
proc toFileVersion(version: PmxVersion): float32 {.raises: [ValueError].}
```

Returns the float version (2.0 or 2.1) for the PMX header.

<sub>[`enums.nim:17`](../src/pmxforge/format/enums.nim#L17)</sub>

<a id="mod-flags"></a>
### `pmxforge/format/flags`

Boolean flag views.

Provides `BoneFlags`, `MaterialFlags`, `SoftBodyFlags`, and `CollisionMask`, plus conversion to and
from their wire bit fields.

<sub>[`src/pmxforge/format/flags.nim`](../src/pmxforge/format/flags.nim)</sub>

#### Types

<a id="sym-flags-0"></a>
##### `BoneFlags`

```nim
BoneFlags = object
  connection*: bool ## Connects to a target bone instead of an offset.
  rotatable*: bool ## Bone can be rotated.
  translatable*: bool ## Bone can be translated.
  visible*: bool ## Bone is displayed in UI / editor.
  manipulatable*: bool ## Bone can be selected and manipulated by user.
  ik*: bool ## Bone is an inverse kinematics controller.
  inheritLocal*: bool ## Transform inheritance uses local coordinate space.
  inheritRotation*: bool ## Inherits rotation from parent bone.
  inheritTranslation*: bool ## Inherits translation from parent bone.
  fixedAxis*: bool ## Rotation is locked to a fixed directional axis.
  localCoordinate*: bool ## Uses custom local X and Z coordinate axes.
  afterPhysicsDeform*: bool ## Evaluated after physics simulation completes.
  externalParentDeform*: bool ## Inherits transform from an external model bone.
```

Bone capabilities and transform flags.

<sub>[`flags.nim:7`](../src/pmxforge/format/flags.nim#L7)</sub>

<a id="sym-flags-1"></a>
##### `CollisionMask`

```nim
CollisionMask = object
  group1*: bool ## Disables collisions with group 1.
  group2*: bool ## Disables collisions with group 2.
  group3*: bool ## Disables collisions with group 3.
  group4*: bool ## Disables collisions with group 4.
  group5*: bool ## Disables collisions with group 5.
  group6*: bool ## Disables collisions with group 6.
  group7*: bool ## Disables collisions with group 7.
  group8*: bool ## Disables collisions with group 8.
  group9*: bool ## Disables collisions with group 9.
  group10*: bool ## Disables collisions with group 10.
  group11*: bool ## Disables collisions with group 11.
  group12*: bool ## Disables collisions with group 12.
  group13*: bool ## Disables collisions with group 13.
  group14*: bool ## Disables collisions with group 14.
  group15*: bool ## Disables collisions with group 15.
  group16*: bool ## Disables collisions with group 16.
```

Collision group disable flags (groups 1 to 16).

<sub>[`flags.nim:37`](../src/pmxforge/format/flags.nim#L37)</sub>

<a id="sym-flags-2"></a>
##### `MaterialFlags`

```nim
MaterialFlags = object
  bothFace*: bool ## Disables backface culling (renders both sides).
  groundShadow*: bool ## Casts shadow onto ground plane.
  selfShadowMap*: bool ## Renders into shadow map for self-shadowing.
  selfShadow*: bool ## Receives self-shadows from the model.
  edge*: bool ## Renders pencil/toon outline around geometry.
  vertexColor*: bool ## Uses vertex color (PMX 2.1).
  pointDraw*: bool ## Renders primitives as point cloud (PMX 2.1).
  lineDraw*: bool ## Renders primitives as wireframe lines (PMX 2.1).
```

Material render and shading flags.

<sub>[`flags.nim:22`](../src/pmxforge/format/flags.nim#L22)</sub>

<a id="sym-flags-3"></a>
##### `SoftBodyFlags`

```nim
SoftBodyFlags = object
  bLink*: bool ## Generates bending links between vertices.
  cluster*: bool ## Generates cluster constraints.
  hybridLink*: bool ## Links soft body nodes with rigid body anchors.
```

Soft body generation flags.

<sub>[`flags.nim:32`](../src/pmxforge/format/flags.nim#L32)</sub>

#### Procedures

<a id="sym-flags-4"></a>
##### `toBoneFlags`

```nim
func toBoneFlags(value: int32): BoneFlags {.raises: [ValueError].}
```

Unpacks a 16-bit wire integer into `BoneFlags`. Bits the format does not define are dropped, so a read and
write pair is not byte identical for a file that carries them.

<sub>[`flags.nim:156`](../src/pmxforge/format/flags.nim#L156)</sub>

<a id="sym-flags-5"></a>
##### `toCollisionMask`

```nim
func toCollisionMask(value: int32): CollisionMask {.raises: [ValueError].}
```

Unpacks a 16-bit wire integer into `CollisionMask`.

<sub>[`flags.nim:206`](../src/pmxforge/format/flags.nim#L206)</sub>

<a id="sym-flags-6"></a>
##### `toMask`

```nim
func toMask(flags: BoneFlags): int32
```

Packs bone flags into a 16-bit wire integer.

```nim
func toMask(flags: MaterialFlags): int32
```

Packs material flags into an 8-bit wire integer.

```nim
func toMask(flags: SoftBodyFlags): int32
```

Packs soft-body flags into an 8-bit wire integer.

```nim
func toMask(mask: CollisionMask): int32
```

Packs collision flags into a 16-bit wire integer.

<sub>[`flags.nim:104`](../src/pmxforge/format/flags.nim#L104)</sub>

<a id="sym-flags-7"></a>
##### `toMaterialFlags`

```nim
func toMaterialFlags(value: int32): MaterialFlags {.raises: [ValueError].}
```

Unpacks an 8-bit wire integer into `MaterialFlags`.

<sub>[`flags.nim:178`](../src/pmxforge/format/flags.nim#L178)</sub>

<a id="sym-flags-8"></a>
##### `toSoftBodyFlags`

```nim
func toSoftBodyFlags(value: int32): SoftBodyFlags {.raises: [ValueError].}
```

Unpacks an 8-bit wire integer into `SoftBodyFlags`. Bits the format does not define are dropped, so a read and
write pair is not byte identical for a file that carries them.

<sub>[`flags.nim:194`](../src/pmxforge/format/flags.nim#L194)</sub>

<a id="mod-limits"></a>
### `pmxforge/format/limits`

Hard format limits.

Provides `MaxStringBytes`, `MaxPmxStringBytes`, and `MaxElementCount`, shared by the reader, the
writer, and the validators.

<sub>[`src/pmxforge/format/limits.nim`](../src/pmxforge/format/limits.nim)</sub>

#### Constants

<a id="sym-limits-0"></a>
##### `MaxElementCount`

```nim
MaxElementCount = 4000000
```

Cap on entries in any single PMX collection.

<sub>[`limits.nim:11`](../src/pmxforge/format/limits.nim#L11)</sub>

<a id="sym-limits-1"></a>
##### `MaxPmxStringBytes`

```nim
MaxPmxStringBytes = 2147483647'i32
```

Largest payload the PMX int32 length field can describe.

<sub>[`limits.nim:10`](../src/pmxforge/format/limits.nim#L10)</sub>

<a id="sym-limits-2"></a>
##### `MaxStringBytes`

```nim
MaxStringBytes = 65536
```

Default cap for one text field (64 KiB).

<sub>[`limits.nim:9`](../src/pmxforge/format/limits.nim#L9)</sub>

#### Procedures

<a id="sym-limits-3"></a>
##### `checkElementCount`

```nim
proc checkElementCount(count: int, label: string) {.raises: [ValueError].}
```

Raises ValueError if `count` exceeds `MaxElementCount`.

<sub>[`limits.nim:13`](../src/pmxforge/format/limits.nim#L13)</sub>

<a id="mod-errors"></a>
### `pmxforge/format/errors`

Format exceptions.

Provides `PmxFormatError`, `PmxTruncatedError`, and `PmxLimitError` so every failure can be
caught through `ValueError`.

<sub>[`src/pmxforge/format/errors.nim`](../src/pmxforge/format/errors.nim)</sub>

#### Types

<a id="sym-errors-0"></a>
##### `PmxFormatError`

```nim
PmxFormatError = object of ValueError
```

Base exception for malformed PMX data or format violations.

<sub>[`errors.nim:7`](../src/pmxforge/format/errors.nim#L7)</sub>

<a id="sym-errors-1"></a>
##### `PmxLimitError`

```nim
PmxLimitError = object of PmxFormatError
```

Input size or element count exceeded configured safety limits.

<sub>[`errors.nim:11`](../src/pmxforge/format/errors.nim#L11)</sub>

<a id="sym-errors-2"></a>
##### `PmxTruncatedError`

```nim
PmxTruncatedError = object of PmxFormatError
```

Stream or buffer ended unexpectedly before finishing a field.

<sub>[`errors.nim:9`](../src/pmxforge/format/errors.nim#L9)</sub>

## Elements

<a id="mod-texture"></a>
### `pmxforge/format/elements/texture`

Texture path entries.

Provides `Texture`, a relative path owned by the model; the library never opens or
validates the file itself.

<sub>[`src/pmxforge/format/elements/texture.nim`](../src/pmxforge/format/elements/texture.nim)</sub>

#### Types

<a id="sym-texture-0"></a>
##### `Texture`

```nim
Texture = ref object
  path*: string ## Relative file path to the texture asset.
```

Texture file path record.

<sub>[`texture.nim:9`](../src/pmxforge/format/elements/texture.nim#L9)</sub>

#### Procedures

<a id="sym-texture-1"></a>
##### `copy`

```nim
proc copy(obj: Texture): Texture
```

Returns a deep copy of the texture entry.

<sub>[`texture.nim:26`](../src/pmxforge/format/elements/texture.nim#L26)</sub>

<a id="sym-texture-2"></a>
##### `isEmpty`

```nim
func isEmpty(texture: Texture): bool
```

Returns true when the texture is nil or its path is empty.

<sub>[`texture.nim:16`](../src/pmxforge/format/elements/texture.nim#L16)</sub>

<a id="sym-texture-3"></a>
##### `isValid`

```nim
proc isValid(texture: Texture): bool
```

Returns true when the texture entry is not nil.

<sub>[`texture.nim:32`](../src/pmxforge/format/elements/texture.nim#L32)</sub>

<a id="sym-texture-4"></a>
##### `newTexture`

```nim
proc newTexture(path = ""): Texture
```

Creates a texture entry; an empty path is allowed.

<sub>[`texture.nim:12`](../src/pmxforge/format/elements/texture.nim#L12)</sub>

#### Operators

<a id="sym-texture-5"></a>
##### `==`

```nim
proc `==`(a, b: Texture): bool
```

Compares two textures for equality.

<sub>[`texture.nim:20`](../src/pmxforge/format/elements/texture.nim#L20)</sub>

<a id="mod-vertex"></a>
### `pmxforge/format/elements/vertex`

Vertex records and skinning.

Provides `Vertex` and the `BDEF1`, `BDEF2`, `BDEF4`, `SDEF`, and `QDEF` payloads that
bind it to one or more bones.

<sub>[`src/pmxforge/format/elements/vertex.nim`](../src/pmxforge/format/elements/vertex.nim)</sub>

#### Types

<a id="sym-vertex-0"></a>
##### `BDEF1`

```nim
BDEF1 = object
  boneIndex1*: int32 ## Target bone index (-1 for unbound).
```

Single-bone vertex skinning.

<sub>[`vertex.nim:11`](../src/pmxforge/format/elements/vertex.nim#L11)</sub>

<a id="sym-vertex-1"></a>
##### `BDEF2`

```nim
BDEF2 = object
  boneIndex1*: int32 ## First bone index.
  boneIndex2*: int32 ## Second bone index.
  boneWeight1*: float32 ## Weight of bone 1 in [0, 1] (bone 2 weight is 1 - weight1).
```

Two-bone linear blend skinning.

<sub>[`vertex.nim:14`](../src/pmxforge/format/elements/vertex.nim#L14)</sub>

<a id="sym-vertex-2"></a>
##### `BDEF4`

```nim
BDEF4 = object
  boneIndex1*, boneIndex2*, boneIndex3*, boneIndex4*: int32 ## Target bone indices.
  boneWeight1*, boneWeight2*, boneWeight3*, boneWeight4*: float32 ## Skinning weights.
```

Four-bone linear blend skinning.

<sub>[`vertex.nim:19`](../src/pmxforge/format/elements/vertex.nim#L19)</sub>

<a id="sym-vertex-3"></a>
##### `DeformData`

```nim
DeformData = object
  case kind*: DeformKind ## Active skinning variant.
  of dkBDEF1:
    bdef1*: BDEF1 ## Single-bone payload.
  of dkBDEF2:
    bdef2*: BDEF2 ## Two-bone linear blend payload.
  of dkBDEF4:
    bdef4*: BDEF4 ## Four-bone linear blend payload.
  of dkSDEF:
    sdef*: SDEF ## Spherical deformation payload.
  of dkQDEF:
    qdef*: QDEF ## Dual-quaternion payload.
```

Tagged union for vertex skinning data.

<sub>[`vertex.nim:39`](../src/pmxforge/format/elements/vertex.nim#L39)</sub>

<a id="sym-vertex-4"></a>
##### `DeformKind`

```nim
DeformKind {.size: 4.} = enum
  dkBDEF1 = 0, ## Single bone (rigid).
  dkBDEF2 = 1, ## Two bones (linear blend).
  dkBDEF4 = 2, ## Four bones (linear blend).
  dkSDEF = 3, ## Spherical deformation (two bones with SDEF parameters).
  dkQDEF = 4 ## Dual quaternion deformation (PMX 2.1).
```

Vertex skinning deformation type.

<sub>[`vertex.nim:32`](../src/pmxforge/format/elements/vertex.nim#L32)</sub>

<a id="sym-vertex-5"></a>
##### `QDEF`

```nim
QDEF = object
  boneIndex1*, boneIndex2*, boneIndex3*, boneIndex4*: int32 ## Target bone indices.
  boneWeight1*, boneWeight2*, boneWeight3*, boneWeight4*: float32 ## Skinning weights.
```

Dual-quaternion skinning (four bones, PMX 2.1).

<sub>[`vertex.nim:28`](../src/pmxforge/format/elements/vertex.nim#L28)</sub>

<a id="sym-vertex-6"></a>
##### `SDEF`

```nim
SDEF = object
  boneIndex1*, boneIndex2*: int32 ## Target bone indices.
  boneWeight1*: float32 ## Weight of bone 1; bone 2 takes the rest.
  c*, r0*, r1*: Vector3 ## SDEF blending center and correction vectors.
```

Spherical deformation skinning (two bones).

<sub>[`vertex.nim:23`](../src/pmxforge/format/elements/vertex.nim#L23)</sub>

<a id="sym-vertex-7"></a>
##### `Vertex`

```nim
Vertex = ref object
  position*: Vector3 ## 3D position vector.
  normal*: Vector3 ## Surface normal vector.
  uv*: Vector2 ## Primary UV texture coordinates.
  additionalUv*: seq[Vector4] ## Up to 4 extra UV channels.
  weightDeform*: DeformData ## Skinning deformation and weights.
  edgeScale*: float32 ## Outline edge scale factor.
```

PMX vertex containing geometry, UVs, skinning, and edge scale.

<sub>[`vertex.nim:52`](../src/pmxforge/format/elements/vertex.nim#L52)</sub>

#### Procedures

<a id="sym-vertex-8"></a>
##### `copy`

```nim
proc copy(obj: Vertex): Vertex
```

Returns a deep copy of the vertex.

<sub>[`vertex.nim:432`](../src/pmxforge/format/elements/vertex.nim#L432)</sub>

<a id="sym-vertex-9"></a>
##### `getBoneIndices`

```nim
proc getBoneIndices(deform: DeformData): seq[int32] {.raises: [ValueError].}
```

Returns the active bone indices for this deformation.

<sub>[`vertex.nim:386`](../src/pmxforge/format/elements/vertex.nim#L386)</sub>

<a id="sym-vertex-10"></a>
##### `getBoneIndicesInto`

```nim
proc getBoneIndicesInto(deform: DeformData, into: var seq[int32]) {.raises: [ValueError].}
```

Writes the bone indices into `into`, reusing its capacity.

<sub>[`vertex.nim:358`](../src/pmxforge/format/elements/vertex.nim#L358)</sub>

<a id="sym-vertex-11"></a>
##### `getWeights`

```nim
proc getWeights(deform: DeformData): seq[float32] {.raises: [ValueError].}
```

Returns the skinning weights for this deformation.

<sub>[`vertex.nim:390`](../src/pmxforge/format/elements/vertex.nim#L390)</sub>

<a id="sym-vertex-12"></a>
##### `isPmx21Only`

```nim
func isPmx21Only(deform: DeformData): bool
```

Returns true if this deformation uses QDEF (PMX 2.1 only).

<sub>[`vertex.nim:405`](../src/pmxforge/format/elements/vertex.nim#L405)</sub>

<a id="sym-vertex-13"></a>
##### `isValid`

```nim
proc isValid(deform: DeformData, boneCount = -1'i32): bool
```

Returns true when the deformation is valid and fits `boneCount`.

```nim
proc isValid(obj: Vertex, boneCount = -1'i32, additionalUvCount = -1'i32): bool
```

Returns true when positions, UVs, and skinning are valid.

<sub>[`vertex.nim:100`](../src/pmxforge/format/elements/vertex.nim#L100)</sub>

<a id="sym-vertex-14"></a>
##### `newBDEF1`

```nim
proc newBDEF1(boneIndex1 = -1'i32): DeformData {.raises: [ValueError].}
```

Creates single-bone (rigid) skinning data. Pass -1 for unbound.

<sub>[`vertex.nim:229`](../src/pmxforge/format/elements/vertex.nim#L229)</sub>

<a id="sym-vertex-15"></a>
##### `newBDEF2`

```nim
proc newBDEF2(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneWeight1 = 0.5'f32
): DeformData {.raises: [ValueError].}
```

Creates two-bone linear blend skinning data.

<sub>[`vertex.nim:234`](../src/pmxforge/format/elements/vertex.nim#L234)</sub>

<a id="sym-vertex-16"></a>
##### `newBDEF4`

```nim
proc newBDEF4(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneIndex3 = -1'i32,
  boneIndex4 = -1'i32,
  boneWeight1 = 0.25'f32,
  boneWeight2 = 0.25'f32,
  boneWeight3 = 0.25'f32,
  boneWeight4 = 0.25'f32
): DeformData {.raises: [ValueError].}
```

Creates four-bone linear blend skinning data.

<sub>[`vertex.nim:246`](../src/pmxforge/format/elements/vertex.nim#L246)</sub>

<a id="sym-vertex-17"></a>
##### `newQDEF`

```nim
proc newQDEF(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneIndex3 = -1'i32,
  boneIndex4 = -1'i32,
  boneWeight1 = 0.25'f32,
  boneWeight2 = 0.25'f32,
  boneWeight3 = 0.25'f32,
  boneWeight4 = 0.25'f32
): DeformData {.raises: [ValueError].}
```

Creates four-bone dual-quaternion skinning data (PMX 2.1).

<sub>[`vertex.nim:294`](../src/pmxforge/format/elements/vertex.nim#L294)</sub>

<a id="sym-vertex-18"></a>
##### `newSDEF`

```nim
proc newSDEF(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneWeight1 = 0.5'f32,
  c = Vector3.zero,
  r0 = Vector3.zero,
  r1 = Vector3.zero
): DeformData {.raises: [ValueError].}
```

Creates SDEF (spherical deformation) skinning data.

<sub>[`vertex.nim:272`](../src/pmxforge/format/elements/vertex.nim#L272)</sub>

<a id="sym-vertex-19"></a>
##### `newVertex`

```nim
proc newVertex(
  position = Vector3.zero,
  normal = Vector3.up,
  uv = Vector2.zero,
  additionalUv: seq[Vector4] = @[],
  weightDeform = newBDEF1(-1'i32),
  edgeScale = 1.0'f32
): Vertex {.raises: [ValueError].}
```

Creates a vertex with the given geometry and skinning.

```nim
proc newVertex(
  position: Vector3,
  normal: Vector3,
  uv: Vector2,
  boneIndex: int32
): Vertex {.raises: [ValueError].}
```

Creates a vertex bound to a single bone.

<sub>[`vertex.nim:320`](../src/pmxforge/format/elements/vertex.nim#L320)</sub>

<a id="sym-vertex-20"></a>
##### `repair`

```nim
proc repair(deform: var DeformData, boneCount = -1'i32) {.raises: [ValueError].}
```

Clamps weights and resets bad bone indices to -1.

```nim
proc repair(obj: Vertex, boneCount = -1'i32, additionalUvCount = -1'i32) {.raises: [ValueError].}
```

Fixes non-finite values and repairs skinning in place.

<sub>[`vertex.nim:134`](../src/pmxforge/format/elements/vertex.nim#L134)</sub>

<a id="sym-vertex-21"></a>
##### `validateDeform`

```nim
proc validateDeform(deform: DeformData) {.raises: [ValueError].}
```

Raises ValueError when the bone indices, weights, or vectors are invalid.

<sub>[`vertex.nim:60`](../src/pmxforge/format/elements/vertex.nim#L60)</sub>

#### Operators

<a id="sym-vertex-22"></a>
##### `==`

```nim
proc `==`(a, b: DeformData): bool
```

Compares two deformation values for equality.

```nim
proc `==`(a, b: Vertex): bool
```

Compares two vertices for equality.

<sub>[`vertex.nim:409`](../src/pmxforge/format/elements/vertex.nim#L409)</sub>

<a id="mod-face"></a>
### `pmxforge/format/elements/face`

Triangle faces.

Provides `Face`: three unsigned vertex indices.

<sub>[`src/pmxforge/format/elements/face.nim`](../src/pmxforge/format/elements/face.nim)</sub>

#### Types

<a id="sym-face-0"></a>
##### `Face`

```nim
Face = ref object
  vertexIndex1*: int32 ## First vertex index of the triangle.
  vertexIndex2*: int32 ## Second vertex index of the triangle.
  vertexIndex3*: int32 ## Third vertex index of the triangle.
```

Triangle formed by three vertex indices.

<sub>[`face.nim:8`](../src/pmxforge/format/elements/face.nim#L8)</sub>

#### Procedures

<a id="sym-face-1"></a>
##### `containsVertex`

```nim
func containsVertex(face: Face, vertexIndex: int32): bool {.raises: [ValueError].}
```

Returns true when the triangle uses `vertexIndex`.

<sub>[`face.nim:29`](../src/pmxforge/format/elements/face.nim#L29)</sub>

<a id="sym-face-2"></a>
##### `copy`

```nim
proc copy(obj: Face): Face
```

Returns a deep copy of the face.

<sub>[`face.nim:41`](../src/pmxforge/format/elements/face.nim#L41)</sub>

<a id="sym-face-3"></a>
##### `getIndices`

```nim
func getIndices(face: Face): array[3, int32] {.raises: [ValueError].}
```

Returns the three vertex indices.

<sub>[`face.nim:23`](../src/pmxforge/format/elements/face.nim#L23)</sub>

<a id="sym-face-4"></a>
##### `isValid`

```nim
proc isValid(face: Face, vertexCount = -1'i32): bool
```

Returns true when every index is in range.

<sub>[`face.nim:47`](../src/pmxforge/format/elements/face.nim#L47)</sub>

<a id="sym-face-5"></a>
##### `newFace`

```nim
proc newFace(
  vertexIndex1 = 0'i32,
  vertexIndex2 = 0'i32,
  vertexIndex3 = 0'i32
): Face {.raises: [ValueError].}
```

Creates a face from three vertex indices.

<sub>[`face.nim:13`](../src/pmxforge/format/elements/face.nim#L13)</sub>

<a id="sym-face-6"></a>
##### `repair`

```nim
proc repair(face: Face, vertexCount = -1'i32) {.raises: [ValueError].}
```

Clamps negative vertex indices to 0; out-of-range corners are left to `PmxModel.repair`.

<sub>[`face.nim:56`](../src/pmxforge/format/elements/face.nim#L56)</sub>

#### Operators

<a id="sym-face-7"></a>
##### `==`

```nim
proc `==`(a, b: Face): bool
```

Compares two faces for equality.

<sub>[`face.nim:35`](../src/pmxforge/format/elements/face.nim#L35)</sub>

<a id="mod-material"></a>
### `pmxforge/format/elements/material`

Material records.

Provides `Material` with its colors, render flags, outline settings, and diffuse, sphere,
and toon texture references.

<sub>[`src/pmxforge/format/elements/material.nim`](../src/pmxforge/format/elements/material.nim)</sub>

#### Types

<a id="sym-material-0"></a>
##### `Material`

```nim
Material = ref object
  nameJA*: string ## Japanese material name.
  nameEN*: string ## English / universal material name.
  diffuseColor*: RGB ## Diffuse surface color.
  alpha*: float32 ## Opacity in [0.0, 1.0].
  specularColor*: RGB ## Specular highlight color.
  specularStrength*: float32 ## Specular shininess power.
  ambientColor*: RGB ## Ambient lighting color.
  flags*: MaterialFlags ## Rendering flags (double-sided, edges, shadows).
  edgeColor*: RGBA ## Outline edge color and alpha.
  edgeScale*: float32 ## Outline edge thickness scale factor.
  textureIndex*: int32 ## Diffuse texture index (-1 if none).
  sphereTextureIndex*: int32 ## Sphere map texture index (-1 if none).
  sphereBlendMode*: SphereBlendMode ## Sphere map blending mode.
  internalToon*: bool ## If true, uses shared system toon texture.
  toonTextureIndex*: int32 ## Toon texture index (0-9 for system, or texture index).
  comment*: string ## Free-form material comment.
  faceCount*: int32 ## Triangles drawn by this material.
```

PMX material properties and texture references.

<sub>[`material.nim:18`](../src/pmxforge/format/elements/material.nim#L18)</sub>

<a id="sym-material-1"></a>
##### `SphereBlendMode`

```nim
SphereBlendMode {.size: 4.} = enum
  sbmDisabled = 0, ## No sphere map.
  sbmMultiply = 1, ## Multiply (standard sphere map).
  sbmAdd = 2, ## Additive blending.
  sbmSubTexture = 3 ## Sub-texture (extra texture with separate UVs).
```

Sphere map blending mode.

<sub>[`material.nim:12`](../src/pmxforge/format/elements/material.nim#L12)</sub>

#### Procedures

<a id="sym-material-2"></a>
##### `copy`

```nim
proc copy(obj: Material): Material
```

Returns a deep copy of the material.

<sub>[`material.nim:94`](../src/pmxforge/format/elements/material.nim#L94)</sub>

<a id="sym-material-3"></a>
##### `isValid`

```nim
proc isValid(material: Material, textureCount = -1'i32): bool
```

Returns true when colors, flags, and textures are valid.

<sub>[`material.nim:37`](../src/pmxforge/format/elements/material.nim#L37)</sub>

<a id="sym-material-4"></a>
##### `newMaterial`

```nim
proc newMaterial(
  nameJA = "",
  nameEN = nameJA,
  diffuseColor = RGB.white,
  alpha = 1.0'f32,
  specularColor = RGB.black,
  specularStrength = 0.0'f32,
  ambientColor = RGB(r: 0.5'f32, g: 0.5'f32, b: 0.5'f32),
  flags = MaterialFlags(),
  edgeColor = RGBA.black,
  edgeScale = 1.0'f32,
  textureIndex = -1'i32,
  sphereTextureIndex = -1'i32,
  sphereBlendMode = sbmDisabled,
  internalToon = true,
  toonTextureIndex = 0'i32,
  comment = "",
  faceCount = 0'i32
): Material {.raises: [ValueError].}
```

Creates a material with the given colors, flags, and textures.

<sub>[`material.nim:40`](../src/pmxforge/format/elements/material.nim#L40)</sub>

<a id="sym-material-5"></a>
##### `repair`

```nim
proc repair(material: Material, textureCount = -1'i32) {.raises: [ValueError].}
```

Clamps colors and resets bad texture references to -1.

<sub>[`material.nim:151`](../src/pmxforge/format/elements/material.nim#L151)</sub>

#### Operators

<a id="sym-material-6"></a>
##### `==`

```nim
proc `==`(a, b: Material): bool
```

Compares two materials for equality.

<sub>[`material.nim:82`](../src/pmxforge/format/elements/material.nim#L82)</sub>

<a id="mod-bone"></a>
### `pmxforge/format/elements/bone`

Bone and inverse kinematics records.

Provides `Bone`, `BoneIK`, and `IKLink`, covering hierarchy, tail connection, transform inheritance, local
axes, and IK limits in degrees.

<sub>[`src/pmxforge/format/elements/bone.nim`](../src/pmxforge/format/elements/bone.nim)</sub>

#### Types

<a id="sym-bone-0"></a>
##### `Bone`

```nim
Bone = ref object
  nameJA*: string ## Japanese bone name.
  nameEN*: string ## English / universal bone name.
  position*: Vector3 ## Rest position in 3D space.
  parentBoneIndex*: int32 ## Parent bone index (-1 if none).
  layer*: int32 ## Transform hierarchy evaluation layer.
  flags*: BoneFlags ## Capabilities such as rotatable, translatable, and IK.
  tailIndex*: int32 ## Connected child bone index (-1 if offset used).
  tailPosition*: Vector3 ## Offset vector to tail if connection flag is false.
  inheritParentIndex*: int32 ## Target bone index to inherit transforms from (-1 if none).
  inheritParentInfluence*: float32 ## Weight factor for transform inheritance.
  fixedAxisDirection*: Vector3 ## Direction vector for fixed-axis rotation constraint.
  localXVector*: Vector3 ## Custom local X axis orientation vector.
  localZVector*: Vector3 ## Custom local Z axis orientation vector.
  externalParentKey*: int32 ## Key identifier for external parent bone linking.
  ik*: BoneIK ## Inverse kinematics settings.
```

PMX bone containing hierarchy, transforms, and IK data.

<sub>[`bone.nim:24`](../src/pmxforge/format/elements/bone.nim#L24)</sub>

<a id="sym-bone-1"></a>
##### `BoneIK`

```nim
BoneIK = object
  targetIndex*: int32 ## IK target effector bone index.
  loopCount*: int32 ## Iterations per frame for the IK solver.
  limitAngle*: float32 ## Maximum rotation step per iteration in degrees. The wire stores radians; the conversion can change the last bit, so a read/write pair is accurate to one `float32` ULP.
  links*: seq[IKLink] ## Ordered chain of bones participating in the IK solve.
```

Inverse kinematics settings and link chain.

<sub>[`bone.nim:18`](../src/pmxforge/format/elements/bone.nim#L18)</sub>

<a id="sym-bone-2"></a>
##### `IKLink`

```nim
IKLink = object
  boneIndex*: int32 ## Target bone index in the IK chain.
  hasLimits*: bool ## Enables Euler rotation limits.
  limitMin*: Vector3 ## Minimum rotation limits in degrees (wire radians converted; one ULP tolerance).
  limitMax*: Vector3 ## Maximum rotation limits in degrees (wire radians converted; one ULP tolerance).
```

Single bone link in an IK chain with optional rotation limits.

<sub>[`bone.nim:12`](../src/pmxforge/format/elements/bone.nim#L12)</sub>

#### Procedures

<a id="sym-bone-3"></a>
##### `copy`

```nim
proc copy(obj: Bone): Bone
```

Returns a deep copy of the bone and its IK links.

<sub>[`bone.nim:171`](../src/pmxforge/format/elements/bone.nim#L171)</sub>

<a id="sym-bone-4"></a>
##### `hasIk`

```nim
func hasIk(bone: Bone): bool
```

Returns true if the bone is an IK controller.

<sub>[`bone.nim:154`](../src/pmxforge/format/elements/bone.nim#L154)</sub>

<a id="sym-bone-5"></a>
##### `hasParent`

```nim
func hasParent(bone: Bone): bool
```

Returns true if the bone has a valid parent bone.

<sub>[`bone.nim:148`](../src/pmxforge/format/elements/bone.nim#L148)</sub>

<a id="sym-bone-6"></a>
##### `hasTailBone`

```nim
func hasTailBone(bone: Bone): bool
```

Returns true if the bone connects to another bone (tail connection).

<sub>[`bone.nim:151`](../src/pmxforge/format/elements/bone.nim#L151)</sub>

<a id="sym-bone-7"></a>
##### `isValid`

```nim
proc isValid(bone: Bone, boneCount = -1'i32): bool
```

Returns true when transforms, tail data, and references are valid.

<sub>[`bone.nim:41`](../src/pmxforge/format/elements/bone.nim#L41)</sub>

<a id="sym-bone-8"></a>
##### `newBone`

```nim
proc newBone(
  nameJA = "",
  position = Vector3.zero,
  parentBoneIndex = -1'i32,
  nameEN = nameJA,
  layer = 0'i32,
  flags = BoneFlags(rotatable: true, visible: true, manipulatable: true),
  tailIndex = -1'i32,
  tailPosition = Vector3.zero,
  inheritParentIndex = -1'i32,
  inheritParentInfluence = 0.0'f32,
  fixedAxisDirection = Vector3.zero,
  localXVector = Vector3.zero,
  localZVector = Vector3.zero,
  externalParentKey = -1'i32,
  ik = BoneIK()
): Bone {.raises: [ValueError].}
```

Creates a bone with the given transform, hierarchy, and flags.

<sub>[`bone.nim:44`](../src/pmxforge/format/elements/bone.nim#L44)</sub>

<a id="sym-bone-9"></a>
##### `newBoneIK`

```nim
proc newBoneIK(
  targetIndex = 0'i32,
  loopCount = 1'i32,
  limitAngle = 0.0'f32,
  links: seq[IKLink] = @[]
): BoneIK {.raises: [ValueError].}
```

Creates IK settings and link sequence for an IK root bone.

<sub>[`bone.nim:127`](../src/pmxforge/format/elements/bone.nim#L127)</sub>

<a id="sym-bone-10"></a>
##### `newBoneTail`

```nim
proc newBoneTail(
  nameJA = "",
  tailIndex = 0'i32,
  position = Vector3.zero,
  parentBoneIndex = -1'i32
): Bone {.raises: [ValueError].}
```

Creates a bone connected to another bone (tail connection).

<sub>[`bone.nim:85`](../src/pmxforge/format/elements/bone.nim#L85)</sub>

<a id="sym-bone-11"></a>
##### `newIKLink`

```nim
proc newIKLink(
  boneIndex = 0'i32,
  hasLimits = false,
  limitMin = Vector3.zero,
  limitMax = Vector3.zero
): IKLink {.raises: [ValueError].}
```

Creates an IK link for a target bone. Pass -1 for unbound.

<sub>[`bone.nim:98`](../src/pmxforge/format/elements/bone.nim#L98)</sub>

<a id="sym-bone-12"></a>
##### `newLimitedIKLink`

```nim
proc newLimitedIKLink(
  boneIndex = 0'i32,
  limitMin = Vector3.zero,
  limitMax = Vector3.zero
): IKLink {.raises: [ValueError].}
```

Creates an IK link with angular rotation limits.

<sub>[`bone.nim:113`](../src/pmxforge/format/elements/bone.nim#L113)</sub>

<a id="sym-bone-13"></a>
##### `repair`

```nim
proc repair(bone: Bone, boneCount = -1'i32) {.raises: [ValueError].}
```

Fixes non-finite numbers, resets bad references to -1, and clears the IK link chain when the IK flag is off,
because the writer does not encode links behind that flag.

<sub>[`bone.nim:241`](../src/pmxforge/format/elements/bone.nim#L241)</sub>

#### Operators

<a id="sym-bone-14"></a>
##### `==`

```nim
proc `==`(a, b: Bone): bool
```

Compares two bones for equality.

<sub>[`bone.nim:158`](../src/pmxforge/format/elements/bone.nim#L158)</sub>

<a id="mod-morph"></a>
### `pmxforge/format/elements/morph`

Morph records and offsets.

Provides `Morph` and the tagged offset payloads for vertex, UV, bone, material,
group, flip, and impulse morphs.

<sub>[`src/pmxforge/format/elements/morph.nim`](../src/pmxforge/format/elements/morph.nim)</sub>

#### Types

<a id="sym-morph-0"></a>
##### `BoneMorphOffset`

```nim
BoneMorphOffset = object
  boneIndex*: int32 ## Target bone index.
  translation*: Vector3 ## Position displacement vector.
  rotation*: Quaternion ## Rotation offset quaternion.
```

Position and rotation offset for a single bone.

<sub>[`morph.nim:40`](../src/pmxforge/format/elements/morph.nim#L40)</sub>

<a id="sym-morph-1"></a>
##### `FlipMorphOffset`

```nim
FlipMorphOffset = object
  morphIndex*: int32 ## Target morph index.
  influence*: float32 ## Threshold weight for activation.
```

Group morph switching between targets based on weight (PMX 2.1).

<sub>[`morph.nim:66`](../src/pmxforge/format/elements/morph.nim#L66)</sub>

<a id="sym-morph-2"></a>
##### `GroupMorphOffset`

```nim
GroupMorphOffset = object
  morphIndex*: int32 ## Target morph index.
  influence*: float32 ## Multiplier / blend ratio.
```

Weight multiplier applied to another morph.

<sub>[`morph.nim:32`](../src/pmxforge/format/elements/morph.nim#L32)</sub>

<a id="sym-morph-3"></a>
##### `ImpulseMorphOffset`

```nim
ImpulseMorphOffset = object
  rigidBodyIndex*: int32 ## Target rigid body index.
  localFlag*: bool ## If true, impulse vectors are in local space.
  movementSpeed*: Vector3 ## Linear velocity impulse vector.
  rotationTorque*: Vector3 ## Angular velocity torque vector.
```

Physics velocity and torque applied to a rigid body (PMX 2.1).

<sub>[`morph.nim:70`](../src/pmxforge/format/elements/morph.nim#L70)</sub>

<a id="sym-morph-4"></a>
##### `MaterialMorphBlendMode`

```nim
MaterialMorphBlendMode {.size: 4.} = enum
  mmbMultiply = 0, ## Multiply existing color.
  mmbAdd = 1 ## Add to existing color.
```

Blend operation for material morphs.

<sub>[`morph.nim:49`](../src/pmxforge/format/elements/morph.nim#L49)</sub>

<a id="sym-morph-5"></a>
##### `MaterialMorphOffset`

```nim
MaterialMorphOffset = object
  materialIndex*: int32 ## Target material index (-1 for all materials).
  blendMode*: MaterialMorphBlendMode ## Blend operation (multiply or add).
  diffuseColor*: RGBA ## Diffuse color and alpha offset.
  specularColor*: RGB ## Specular highlight color offset.
  specularStrength*: float32 ## Specular shininess power offset.
  ambientColor*: RGB ## Ambient color offset.
  edgeColor*: RGBA ## Outline edge color and alpha offset.
  edgeScale*: float32 ## Outline edge thickness scale offset.
  textureTint*: RGBA ## Diffuse texture tint multiplier/offset.
  sphereTint*: RGBA ## Sphere map tint multiplier/offset.
  toonTint*: RGBA ## Toon texture tint multiplier/offset.
```

Color and shading offsets for a material.

<sub>[`morph.nim:53`](../src/pmxforge/format/elements/morph.nim#L53)</sub>

<a id="sym-morph-6"></a>
##### `Morph`

```nim
Morph = ref object
  nameJA*: string ## Japanese morph name.
  nameEN*: string ## English / universal morph name.
  panelType*: MorphPanelType ## UI category panel (eyebrow, eye, mouth, other).
  morphType*: MorphType ## Target kind modified by this morph.
  offsetData*: seq[MorphOffset] ## List of offset records.
```

Named morph and its ordered offset records.

<sub>[`morph.nim:102`](../src/pmxforge/format/elements/morph.nim#L102)</sub>

<a id="sym-morph-7"></a>
##### `MorphOffset`

```nim
MorphOffset = object
  case kind*: MorphOffsetKind ## Active offset variant.
  of moGroup:
    group*: GroupMorphOffset ## Group offset payload.
  of moVertex:
    vertex*: VertexMorphOffset ## Vertex offset payload.
  of moBone:
    bone*: BoneMorphOffset ## Bone offset payload.
  of moUV:
    uv*: UVMorphOffset ## UV offset payload.
  of moMaterial:
    material*: MaterialMorphOffset ## Material offset payload.
  of moFlip:
    flip*: FlipMorphOffset ## Flip offset payload.
  of moImpulse:
    impulse*: ImpulseMorphOffset ## Impulse offset payload.
```

Tagged union containing one morph offset payload.

<sub>[`morph.nim:85`](../src/pmxforge/format/elements/morph.nim#L85)</sub>

<a id="sym-morph-8"></a>
##### `MorphOffsetKind`

```nim
MorphOffsetKind {.size: 4.} = enum
  moGroup = 0, ## Group offset.
  moVertex = 1, ## Vertex offset.
  moBone = 2, ## Bone offset.
  moUV = 3, ## UV offset.
  moMaterial = 4, ## Material offset.
  moFlip = 5, ## Flip offset.
  moImpulse = 6 ## Impulse offset.
```

Internal tag for MorphOffset variant.

<sub>[`morph.nim:76`](../src/pmxforge/format/elements/morph.nim#L76)</sub>

<a id="sym-morph-9"></a>
##### `MorphPanelType`

```nim
MorphPanelType {.size: 4.} = enum
  mptSystem = 0, ## Reserved / system.
  mptEyebrow = 1, ## Eyebrows (bottom left).
  mptEye = 2, ## Eyes (top left).
  mptMouth = 3, ## Mouth / lips (top right).
  mptOther = 4 ## Other / miscellaneous (bottom right).
```

UI panel category in MMD.

<sub>[`morph.nim:12`](../src/pmxforge/format/elements/morph.nim#L12)</sub>

<a id="sym-morph-10"></a>
##### `MorphType`

```nim
MorphType {.size: 4.} = enum
  mtGroup = 0, ## Group (controls other morphs).
  mtVertex = 1, ## Vertex position offsets.
  mtBone = 2, ## Bone transform offsets.
  mtUV = 3, ## Primary UV offsets.
  mtUVExt1 = 4, ## Extra UV 1 offsets.
  mtUVExt2 = 5, ## Extra UV 2 offsets.
  mtUVExt3 = 6, ## Extra UV 3 offsets.
  mtUVExt4 = 7, ## Extra UV 4 offsets.
  mtMaterial = 8, ## Material color and texture tint offsets.
  mtFlip = 9, ## Flip morph (PMX 2.1).
  mtImpulse = 10 ## Physics impulse (PMX 2.1).
```

Target type modified by this morph.

<sub>[`morph.nim:19`](../src/pmxforge/format/elements/morph.nim#L19)</sub>

<a id="sym-morph-11"></a>
##### `UVMorphOffset`

```nim
UVMorphOffset = object
  vertexIndex*: int32 ## Target vertex index.
  floats*: Vector4 ## UV displacement (X, Y are primary UV; Z, W optional).
```

Texture coordinate offset for a single vertex.

<sub>[`morph.nim:45`](../src/pmxforge/format/elements/morph.nim#L45)</sub>

<a id="sym-morph-12"></a>
##### `VertexMorphOffset`

```nim
VertexMorphOffset = object
  vertexIndex*: int32 ## Target vertex index.
  translation*: Vector3 ## Position displacement vector.
```

Position offset for a single vertex.

<sub>[`morph.nim:36`](../src/pmxforge/format/elements/morph.nim#L36)</sub>

#### Procedures

<a id="sym-morph-13"></a>
##### `copy`

```nim
proc copy(obj: Morph): Morph
```

Returns a deep copy of the morph and its offsets.

<sub>[`morph.nim:189`](../src/pmxforge/format/elements/morph.nim#L189)</sub>

<a id="sym-morph-14"></a>
##### `getExpectedMorphOffsetKind`

```nim
proc getExpectedMorphOffsetKind(morphType: MorphType): MorphOffsetKind {.raises: [ValueError].}
```

Maps a morph type to the offset variant it must carry.

<sub>[`morph.nim:139`](../src/pmxforge/format/elements/morph.nim#L139)</sub>

<a id="sym-morph-15"></a>
##### `isPmx21Only`

```nim
func isPmx21Only(morph: Morph): bool
```

Returns true if this morph requires PMX 2.1 (flip or impulse).

<sub>[`morph.nim:158`](../src/pmxforge/format/elements/morph.nim#L158)</sub>

<a id="sym-morph-16"></a>
##### `isValid`

```nim
proc isValid(
  morph: Morph,
  vertexCount = -1'i32,
  boneCount = -1'i32,
  materialCount = -1'i32,
  morphCount = -1'i32,
  rigidBodyCount = -1'i32
): bool
```

Returns true when the type, panel, and targets are valid.

<sub>[`morph.nim:109`](../src/pmxforge/format/elements/morph.nim#L109)</sub>

<a id="sym-morph-17"></a>
##### `newMorph`

```nim
proc newMorph(
  nameJA = "",
  morphType = mtVertex,
  panelType = mptOther,
  nameEN = nameJA,
  offsetData: seq[MorphOffset] = @[]
): Morph {.raises: [ValueError].}
```

Creates a morph with its panel, type, and offsets.

<sub>[`morph.nim:119`](../src/pmxforge/format/elements/morph.nim#L119)</sub>

<a id="sym-morph-18"></a>
##### `repair`

```nim
proc repair(
  morph: Morph,
  vertexCount = -1'i32,
  boneCount = -1'i32,
  materialCount = -1'i32,
  morphCount = -1'i32,
  rigidBodyCount = -1'i32
) {.raises: [ValueError].}
```

Drops bad offsets, clamps values, and fixes references.

<sub>[`morph.nim:268`](../src/pmxforge/format/elements/morph.nim#L268)</sub>

#### Operators

<a id="sym-morph-19"></a>
##### `==`

```nim
proc `==`(a, b: MorphOffset): bool
```

Compares two morph offsets for equality.

```nim
proc `==`(a, b: Morph): bool
```

Compares two morphs for equality.

<sub>[`morph.nim:162`](../src/pmxforge/format/elements/morph.nim#L162)</sub>

<a id="mod-display_slot"></a>
### `pmxforge/format/elements/display_slot`

Display slots for the MMD UI.

Provides `DisplaySlot` and `DisplayFrame`, the ordered bone and morph groups the model editor shows.

<sub>[`src/pmxforge/format/elements/display_slot.nim`](../src/pmxforge/format/elements/display_slot.nim)</sub>

#### Types

<a id="sym-display_slot-0"></a>
##### `DisplayFrame`

```nim
DisplayFrame = object
  frameType*: DisplayFrameType ## Target type (bone or morph).
  targetIndex*: int32 ## Index of the target bone or morph (-1 if unbound).
```

Target bone or morph entry in a display slot.

<sub>[`display_slot.nim:13`](../src/pmxforge/format/elements/display_slot.nim#L13)</sub>

<a id="sym-display_slot-1"></a>
##### `DisplayFrameType`

```nim
DisplayFrameType {.size: 4.} = enum
  dftBone = 0, ## Bone target.
  dftMorph = 1 ## Morph target.
```

Target type in a display frame.

<sub>[`display_slot.nim:9`](../src/pmxforge/format/elements/display_slot.nim#L9)</sub>

<a id="sym-display_slot-2"></a>
##### `DisplaySlot`

```nim
DisplaySlot = ref object
  nameJA*: string ## Japanese slot name.
  nameEN*: string ## English / universal slot name.
  specialFlag*: bool ## Marks a special system frame, such as Root.
  frames*: seq[DisplayFrame] ## List of bone and morph frame entries.
```

Named UI category containing bones and morphs.

<sub>[`display_slot.nim:17`](../src/pmxforge/format/elements/display_slot.nim#L17)</sub>

#### Procedures

<a id="sym-display_slot-3"></a>
##### `copy`

```nim
proc copy(obj: DisplaySlot): DisplaySlot
```

Returns a deep copy of the display slot.

<sub>[`display_slot.nim:58`](../src/pmxforge/format/elements/display_slot.nim#L58)</sub>

<a id="sym-display_slot-4"></a>
##### `isValid`

```nim
proc isValid(slot: DisplaySlot, boneCount = -1'i32, morphCount = -1'i32): bool
```

Returns true when frame types and targets are valid.

<sub>[`display_slot.nim:23`](../src/pmxforge/format/elements/display_slot.nim#L23)</sub>

<a id="sym-display_slot-5"></a>
##### `newBoneDisplayFrame`

```nim
proc newBoneDisplayFrame(boneIndex = 0'i32): DisplayFrame {.raises: [ValueError].}
```

Creates a bone display frame.

<sub>[`display_slot.nim:44`](../src/pmxforge/format/elements/display_slot.nim#L44)</sub>

<a id="sym-display_slot-6"></a>
##### `newDisplayFrame`

```nim
proc newDisplayFrame(
  frameType = dftBone,
  targetIndex = 0'i32
): DisplayFrame {.raises: [ValueError].}
```

Creates a frame for a bone or morph; -1 means unbound.

<sub>[`display_slot.nim:37`](../src/pmxforge/format/elements/display_slot.nim#L37)</sub>

<a id="sym-display_slot-7"></a>
##### `newDisplaySlot`

```nim
proc newDisplaySlot(
  nameJA = "",
  specialFlag = false,
  nameEN = nameJA,
  frames: seq[DisplayFrame] = @[]
): DisplaySlot {.raises: [ValueError].}
```

Creates a display slot from its name and frames.

<sub>[`display_slot.nim:26`](../src/pmxforge/format/elements/display_slot.nim#L26)</sub>

<a id="sym-display_slot-8"></a>
##### `newMorphDisplayFrame`

```nim
proc newMorphDisplayFrame(morphIndex = 0'i32): DisplayFrame {.raises: [ValueError].}
```

Creates a morph display frame.

<sub>[`display_slot.nim:48`](../src/pmxforge/format/elements/display_slot.nim#L48)</sub>

<a id="sym-display_slot-9"></a>
##### `repair`

```nim
proc repair(slot: DisplaySlot, boneCount = -1'i32, morphCount = -1'i32) {.raises: [ValueError].}
```

Drops unknown frame types and resets bad targets to -1.

<sub>[`display_slot.nim:87`](../src/pmxforge/format/elements/display_slot.nim#L87)</sub>

#### Operators

<a id="sym-display_slot-10"></a>
##### `==`

```nim
proc `==`(a, b: DisplaySlot): bool
```

Compares two display slots for equality.

<sub>[`display_slot.nim:52`](../src/pmxforge/format/elements/display_slot.nim#L52)</sub>

<a id="mod-rigid_body"></a>
### `pmxforge/format/elements/rigid_body`

Rigid body records.

Provides `RigidBody` with its collision shape, mass, damping, collision group, and simulation mode.

<sub>[`src/pmxforge/format/elements/rigid_body.nim`](../src/pmxforge/format/elements/rigid_body.nim)</sub>

#### Types

<a id="sym-rigid_body-0"></a>
##### `PhysicsMode`

```nim
PhysicsMode {.size: 4.} = enum
  pmFollowBone = 0, ## Static (kinematic, follows bone animation).
  pmPhysics = 1, ## Dynamic (driven by physics simulation).
  pmPhysicsAndBone = 2 ## Alignment (physics with bone positioning).
```

Simulation mode for the rigid body.

<sub>[`rigid_body.nim:16`](../src/pmxforge/format/elements/rigid_body.nim#L16)</sub>

<a id="sym-rigid_body-1"></a>
##### `RigidBody`

```nim
RigidBody = ref object
  nameJA*: string ## Japanese body name.
  nameEN*: string ## English / universal body name.
  relatedBoneIndex*: int32 ## Target bone index (-1 if none).
  groupId*: int32 ## Collision group ID (1 to 16).
  nonCollisionMask*: CollisionMask ## Mask disabling collisions with other groups.
  shape*: RigidBodyShape ## Collision primitive shape (sphere, box, capsule).
  shapeSize*: Vector3 ## Primitive dimensions.
  shapePosition*: Vector3 ## Position offset relative to bone.
  shapeRotation*: Vector3 ## Euler rotation in radians.
  mass*: float32 ## Body mass in kilograms.
  moveAttenuation*: float32 ## Linear velocity damping.
  rotationDamping*: float32 ## Angular velocity damping.
  repulsion*: float32 ## Restitution / bounce factor.
  frictionForce*: float32 ## Surface friction coefficient.
  physicsMode*: PhysicsMode ## Physics simulation mode.
```

Physics rigid body record.

<sub>[`rigid_body.nim:21`](../src/pmxforge/format/elements/rigid_body.nim#L21)</sub>

<a id="sym-rigid_body-2"></a>
##### `RigidBodyShape`

```nim
RigidBodyShape {.size: 4.} = enum
  rbsSphere = 0, ## Sphere (radius = shapeSize.x).
  rbsBox = 1, ## Box (half-extents = shapeSize).
  rbsCapsule = 2 ## Capsule (radius = shapeSize.x, height = shapeSize.y).
```

Collision primitive shape.

<sub>[`rigid_body.nim:11`](../src/pmxforge/format/elements/rigid_body.nim#L11)</sub>

#### Procedures

<a id="sym-rigid_body-3"></a>
##### `copy`

```nim
proc copy(obj: RigidBody): RigidBody
```

Returns a deep copy of the rigid body.

<sub>[`rigid_body.nim:94`](../src/pmxforge/format/elements/rigid_body.nim#L94)</sub>

<a id="sym-rigid_body-4"></a>
##### `isValid`

```nim
proc isValid(body: RigidBody, boneCount = -1'i32): bool
```

Returns true when dimensions and physics values are valid.

<sub>[`rigid_body.nim:38`](../src/pmxforge/format/elements/rigid_body.nim#L38)</sub>

<a id="sym-rigid_body-5"></a>
##### `newRigidBody`

```nim
proc newRigidBody(
  nameJA = "",
  relatedBoneIndex = -1'i32,
  groupId = 1'i32,
  nonCollisionMask = CollisionMask(),
  shape = rbsSphere,
  shapeSize = Vector3.one,
  shapePosition = Vector3.zero,
  shapeRotation = Vector3.zero,
  mass = 1.0'f32,
  moveAttenuation = 0.5'f32,
  rotationDamping = 0.5'f32,
  repulsion = 0.0'f32,
  frictionForce = 0.5'f32,
  physicsMode = pmFollowBone,
  nameEN = nameJA
): RigidBody {.raises: [ValueError].}
```

Creates a rigid body with its shape, mass, and collision settings.

<sub>[`rigid_body.nim:41`](../src/pmxforge/format/elements/rigid_body.nim#L41)</sub>

<a id="sym-rigid_body-6"></a>
##### `repair`

```nim
proc repair(body: RigidBody, boneCount = -1'i32) {.raises: [ValueError].}
```

Clamps physics values and bounds the bone reference.

<sub>[`rigid_body.nim:142`](../src/pmxforge/format/elements/rigid_body.nim#L142)</sub>

#### Operators

<a id="sym-rigid_body-7"></a>
##### `==`

```nim
proc `==`(a, b: RigidBody): bool
```

Compares two rigid bodies for equality.

<sub>[`rigid_body.nim:83`](../src/pmxforge/format/elements/rigid_body.nim#L83)</sub>

<a id="mod-joint"></a>
### `pmxforge/format/elements/joint`

Physics joints.

Provides `Joint`, the constraint linking two rigid bodies, with its limits, springs, and
the joint types PMX 2.1 adds.

<sub>[`src/pmxforge/format/elements/joint.nim`](../src/pmxforge/format/elements/joint.nim)</sub>

#### Types

<a id="sym-joint-0"></a>
##### `Joint`

```nim
Joint = ref object
  nameJA*: string ## Japanese joint name.
  nameEN*: string ## English / universal joint name.
  jointType*: JointType ## Constraint type: 6DOF spring, slider, hinge, or cone twist.
  rigidBodyIndexA*: int32 ## First rigid body index (-1 if none).
  rigidBodyIndexB*: int32 ## Second rigid body index (-1 if none).
  position*: Vector3 ## Rest position in 3D space.
  rotation*: Vector3 ## Rest Euler rotation in radians.
  positionMinimum*: Vector3 ## Minimum position limit; some joint types store unrelated settings here.
  positionMaximum*: Vector3 ## Maximum position limit; some joint types store unrelated settings here.
  rotationMinimum*: Vector3 ## Minimum rotation limit; ConeTwist stores its three span angles here.
  rotationMaximum*: Vector3 ## Maximum rotation limit; unused by ConeTwist.
  positionSpring*: Vector3 ## Position spring constant stiffness.
  rotationSpring*: Vector3 ## Rotation spring constant stiffness.
```

Physics constraint record connecting two rigid bodies.

<sub>[`joint.nim:19`](../src/pmxforge/format/elements/joint.nim#L19)</sub>

<a id="sym-joint-1"></a>
##### `JointType`

```nim
JointType {.size: 4.} = enum
  jtSpring6DOF = 0, ## 6-DOF spring constraint (standard PMX 2.0).
  jt6DOF = 1, ## 6-DOF constraint without springs (PMX 2.1).
  jtPointToPoint = 2, ## Point-to-point / ball socket (PMX 2.1).
  jtConeTwist = 3, ## Cone twist constraint (PMX 2.1).
  jtSlider = 4, ## Slider constraint (PMX 2.1).
  jtHinge = 5 ## Hinge constraint (PMX 2.1).
```

Physics constraint type between two bodies.

<sub>[`joint.nim:11`](../src/pmxforge/format/elements/joint.nim#L11)</sub>

#### Procedures

<a id="sym-joint-2"></a>
##### `copy`

```nim
proc copy(obj: Joint): Joint
```

Returns a deep copy of the joint.

<sub>[`joint.nim:155`](../src/pmxforge/format/elements/joint.nim#L155)</sub>

<a id="sym-joint-3"></a>
##### `isPmx21Only`

```nim
func isPmx21Only(jointType: JointType): bool
```

Returns true for every type except `jtSpring6DOF`, which PMX 2.0 already has.

```nim
func isPmx21Only(joint: Joint): bool
```

Returns true if this joint instance requires PMX 2.1.

<sub>[`joint.nim:34`](../src/pmxforge/format/elements/joint.nim#L34)</sub>

<a id="sym-joint-4"></a>
##### `isValid`

```nim
proc isValid(joint: Joint, rigidBodyCount = -1'i32): bool
```

Returns true when limits, springs, and body indices are valid.

<sub>[`joint.nim:100`](../src/pmxforge/format/elements/joint.nim#L100)</sub>

<a id="sym-joint-5"></a>
##### `limitOrderIsValid`

```nim
func limitOrderIsValid(joint: Joint): bool
```

Returns true when the limits this type uses are ordered.

<sub>[`joint.nim:60`](../src/pmxforge/format/elements/joint.nim#L60)</sub>

<a id="sym-joint-6"></a>
##### `newJoint`

```nim
proc newJoint(
  nameJA = "",
  rigidBodyIndexA = -1'i32,
  rigidBodyIndexB = -1'i32,
  jointType = jtSpring6DOF,
  position = Vector3.zero,
  rotation = Vector3.zero,
  positionMinimum = Vector3.zero,
  positionMaximum = Vector3.zero,
  rotationMinimum = Vector3.zero,
  rotationMaximum = Vector3.zero,
  positionSpring = Vector3.zero,
  rotationSpring = Vector3.zero,
  nameEN = nameJA
): Joint {.raises: [ValueError].}
```

Creates a joint; -1 means an unbound body index.

<sub>[`joint.nim:103`](../src/pmxforge/format/elements/joint.nim#L103)</sub>

<a id="sym-joint-7"></a>
##### `orderedPositionLimitAxes`

```nim
func orderedPositionLimitAxes(jointType: JointType): set[0 .. 2]
```

Returns the position axes that hold a real bound for `jointType`. Every joint shares the same twelve limit
floats, but most types store something else there.

<sub>[`joint.nim:38`](../src/pmxforge/format/elements/joint.nim#L38)</sub>

<a id="sym-joint-8"></a>
##### `orderedRotationLimitAxes`

```nim
func orderedRotationLimitAxes(jointType: JointType): set[0 .. 2]
```

Returns the rotation axes that hold a real bound for `jointType`. ConeTwist keeps span angles in the lower
vector, and P2P has no rotation limits at all.

<sub>[`joint.nim:49`](../src/pmxforge/format/elements/joint.nim#L49)</sub>

<a id="sym-joint-9"></a>
##### `repair`

```nim
proc repair(joint: Joint, rigidBodyCount = -1'i32) {.raises: [ValueError].}
```

Fixes vectors, orders the used limits, and bounds body indices.

<sub>[`joint.nim:199`](../src/pmxforge/format/elements/joint.nim#L199)</sub>

<a id="sym-joint-10"></a>
##### `repairLimitOrder`

```nim
proc repairLimitOrder(joint: Joint)
```

Clamps the limit pairs this joint type uses and leaves the repurposed components untouched.

<sub>[`joint.nim:80`](../src/pmxforge/format/elements/joint.nim#L80)</sub>

#### Operators

<a id="sym-joint-11"></a>
##### `==`

```nim
proc `==`(a, b: Joint): bool
```

Compares two joints for equality.

<sub>[`joint.nim:144`](../src/pmxforge/format/elements/joint.nim#L144)</sub>

<a id="mod-soft_body"></a>
### `pmxforge/format/elements/soft_body`

Soft body records.

Provides `SoftBody` with its Bullet parameters, clusters, anchors, and pinned vertices for PMX 2.1 models.

<sub>[`src/pmxforge/format/elements/soft_body.nim`](../src/pmxforge/format/elements/soft_body.nim)</sub>

#### Types

<a id="sym-soft_body-0"></a>
##### `AerodynamicsModel`

```nim
AerodynamicsModel {.size: 4.} = enum
  amVPoint = 0, ## Vertex two-sided lift/drag.
  amVTwoSided = 1, ## Vertex two-sided.
  amVOneSided = 2, ## Vertex one-sided.
  amFTwoSided = 3, ## Face two-sided.
  amFOneSided = 4 ## Face one-sided.
```

Aerodynamic interaction model.

<sub>[`soft_body.nim:14`](../src/pmxforge/format/elements/soft_body.nim#L14)</sub>

<a id="sym-soft_body-1"></a>
##### `AnchorRigidBody`

```nim
AnchorRigidBody = object
  rigidBodyIndex*: int32 ## Target rigid body index.
  vertexIndex*: int32 ## Target vertex index.
  nearMode*: bool ## Uses the near collision mode for this anchor.
```

Anchor connecting a rigid body to a soft body vertex.

<sub>[`soft_body.nim:54`](../src/pmxforge/format/elements/soft_body.nim#L54)</sub>

<a id="sym-soft_body-2"></a>
##### `SoftBody`

```nim
SoftBody = ref object
  nameJA*: string ## Japanese soft body name.
  nameEN*: string ## English / universal soft body name.
  shape*: SoftBodyShape ## Mesh shape (tri-mesh or rope).
  materialIndex*: int32 ## Target material index (-1 if none).
  groupId*: int32 ## Collision group ID (1 to 16).
  nonCollisionMask*: CollisionMask ## Mask disabling collisions with other groups.
  flags*: SoftBodyFlags ## Generation flags (B-link, cluster, hybrid).
  bLinkCreateDistance*: int32 ## B-link generation distance.
  numberOfClusters*: int32 ## Cluster count.
  totalMass*: float32 ## Total mass in kilograms.
  collisionMargin*: float32 ## Collision margin distance.
  aerodynamicsModel*: AerodynamicsModel ## Aerodynamics interaction model.
  config*: SoftBodyConfig ## Bullet configuration parameters.
  cluster*: SoftBodyCluster ## Cluster parameters.
  iteration*: SoftBodyIteration ## Solver iterations.
  material*: SoftBodyMaterial ## Material stiffness parameters.
  anchorRigidBodies*: seq[AnchorRigidBody] ## Attached rigid body anchors.
  vertexPins*: seq[int32] ## Pinned vertex indices.
```

PMX 2.1 soft body simulation record.

<sub>[`soft_body.nim:59`](../src/pmxforge/format/elements/soft_body.nim#L59)</sub>

<a id="sym-soft_body-3"></a>
##### `SoftBodyCluster`

```nim
SoftBodyCluster = object
  srhrCl*: float32 ## Soft vs rigid hardness.
  skhrCl*: float32 ## Soft vs kinetic hardness.
  sshrCl*: float32 ## Soft vs soft hardness.
  srSpltCl*: float32 ## Soft vs rigid impulse split.
  skSpltCl*: float32 ## Soft vs kinetic impulse split.
  ssSpltCl*: float32 ## Soft vs soft impulse split.
```

Cluster and splitting parameters.

<sub>[`soft_body.nim:35`](../src/pmxforge/format/elements/soft_body.nim#L35)</sub>

<a id="sym-soft_body-4"></a>
##### `SoftBodyConfig`

```nim
SoftBodyConfig = object
  vcf*: float32 ## Velocities correction factor.
  dp*: float32 ## Damping coefficient.
  dg*: float32 ## Drag coefficient.
  lf*: float32 ## Lift coefficient.
  pr*: float32 ## Pressure coefficient.
  vc*: float32 ## Volume conservation coefficient.
  df*: float32 ## Dynamic friction coefficient.
  mt*: float32 ## Pose matching coefficient.
  chr*: float32 ## Rigid contacts hardness.
  khr*: float32 ## Kinetic contacts hardness.
  ahr*: float32 ## Anchors hardness.
```

Bullet physics soft body coefficients.

<sub>[`soft_body.nim:21`](../src/pmxforge/format/elements/soft_body.nim#L21)</sub>

<a id="sym-soft_body-5"></a>
##### `SoftBodyIteration`

```nim
SoftBodyIteration = object
  vIt*: int32 ## Velocities solver iterations.
  pIt*: int32 ## Positions solver iterations.
  dIt*: int32 ## Drift solver iterations.
  cIt*: int32 ## Cluster solver iterations.
```

Solver iteration counts per simulation phase.

<sub>[`soft_body.nim:43`](../src/pmxforge/format/elements/soft_body.nim#L43)</sub>

<a id="sym-soft_body-6"></a>
##### `SoftBodyMaterial`

```nim
SoftBodyMaterial = object
  lst*: float32 ## Linear stiffness coefficient.
  ast*: float32 ## Area/angular stiffness coefficient.
  vst*: float32 ## Volume stiffness coefficient.
```

Linear, angular, and volume stiffness parameters.

<sub>[`soft_body.nim:49`](../src/pmxforge/format/elements/soft_body.nim#L49)</sub>

<a id="sym-soft_body-7"></a>
##### `SoftBodyShape`

```nim
SoftBodyShape {.size: 4.} = enum
  sbshTriMesh = 0, ## Triangle mesh.
  sbshRope = 1 ## Rope / line.
```

Mesh shape representation for soft body.

<sub>[`soft_body.nim:10`](../src/pmxforge/format/elements/soft_body.nim#L10)</sub>

#### Procedures

<a id="sym-soft_body-8"></a>
##### `copy`

```nim
proc copy(obj: SoftBody): SoftBody
```

Returns a deep copy of the soft body.

<sub>[`soft_body.nim:190`](../src/pmxforge/format/elements/soft_body.nim#L190)</sub>

<a id="sym-soft_body-9"></a>
##### `isValid`

```nim
proc isValid(
  body: SoftBody,
  materialCount = -1'i32,
  rigidBodyCount = -1'i32,
  vertexCount = -1'i32
): bool
```

Returns true when coefficients and references are valid.

<sub>[`soft_body.nim:121`](../src/pmxforge/format/elements/soft_body.nim#L121)</sub>

<a id="sym-soft_body-10"></a>
##### `newSoftBody`

```nim
proc newSoftBody(
  nameJA = "",
  materialIndex = 0'i32,
  shape = sbshTriMesh,
  groupId = 1'i32,
  nonCollisionMask = CollisionMask(),
  flags = SoftBodyFlags(),
  bLinkCreateDistance = 0'i32,
  numberOfClusters = 0'i32,
  totalMass = 1.0'f32,
  collisionMargin = 0.0'f32,
  aerodynamicsModel = amVPoint,
  config = newSoftBodyConfig(),
  cluster = SoftBodyCluster(),
  iteration = SoftBodyIteration(),
  material = SoftBodyMaterial(),
  anchorRigidBodies: seq[AnchorRigidBody] = @[],
  vertexPins: seq[int32] = @[],
  nameEN = nameJA
): SoftBody {.raises: [ValueError].}
```

Creates a soft body; -1 means no material is bound.

<sub>[`soft_body.nim:129`](../src/pmxforge/format/elements/soft_body.nim#L129)</sub>

<a id="sym-soft_body-11"></a>
##### `newSoftBodyConfig`

```nim
proc newSoftBodyConfig(
  vcf = 1.0'f32,
  dp = 0.0'f32,
  dg = 0.0'f32,
  lf = 0.05'f32,
  pr = 0.0'f32,
  vc = 0.5'f32,
  df = 1.0'f32,
  mt = 0.0'f32,
  chr = 1.0'f32,
  khr = 0.5'f32,
  shr = 1.0'f32,
  ahr = 1.0'f32
): SoftBodyConfig {.raises: [ValueError].}
```

Creates Bullet soft-body coefficients.

<sub>[`soft_body.nim:79`](../src/pmxforge/format/elements/soft_body.nim#L79)</sub>

<a id="sym-soft_body-12"></a>
##### `repair`

```nim
proc repair(
  body: SoftBody,
  materialCount = -1'i32,
  rigidBodyCount = -1'i32,
  vertexCount = -1'i32
) {.raises: [ValueError].}
```

Clamps parameters and drops dangling vertex anchors.

<sub>[`soft_body.nim:271`](../src/pmxforge/format/elements/soft_body.nim#L271)</sub>

#### Operators

<a id="sym-soft_body-13"></a>
##### `==`

```nim
proc `==`(a, b: SoftBody): bool
```

Compares two soft bodies for equality.

<sub>[`soft_body.nim:177`](../src/pmxforge/format/elements/soft_body.nim#L177)</sub>

## Serialization

<a id="mod-validation"></a>
### `pmxforge/format/validation`

Model validation.

Provides `validate` for the strict semantic contract and `validateWireSafe` for the looser rule that a
model can still be written to bytes.

<sub>[`src/pmxforge/format/validation.nim`](../src/pmxforge/format/validation.nim)</sub>

#### Procedures

<a id="sym-validation-0"></a>
##### `isPmx21Only`

```nim
func isPmx21Only(model: PmxModel): bool
```

Returns true if the model uses any PMX 2.1-only feature.

<sub>[`validation.nim:396`](../src/pmxforge/format/validation.nim#L396)</sub>

<a id="sym-validation-1"></a>
##### `isValid`

```nim
proc isValid(model: PmxModel, strict = true, maxStringBytes = MaxStringBytes): bool
```

Returns true when `model` passes `validate`, or the wire-safe rule with `strict = false`. Semantic problems
come back as `false`; the call does not raise.

<sub>[`validation.nim:963`](../src/pmxforge/format/validation.nim#L963)</sub>

<a id="sym-validation-2"></a>
##### `repairWithReport`

```nim
proc repairWithReport(
  obj: PmxModel,
  maxStringBytes = MaxStringBytes
): seq[ string] {.raises: [ValueError].}
```

Repairs `obj` in place and returns the strict violations that remain. An empty sequence means the model now
passes `validate`.

<sub>[`validation.nim:692`](../src/pmxforge/format/validation.nim#L692)</sub>

<a id="sym-validation-3"></a>
##### `validate`

```nim
proc validate(model: PmxModel, maxStringBytes = MaxStringBytes) {.raises: [ValueError].}
```

Validates `model` against the strict PMX rules: enums, texts, ranges, references, and cycles. It raises
ValueError on the first problem found.

<sub>[`validation.nim:673`](../src/pmxforge/format/validation.nim#L673)</sub>

<a id="sym-validation-4"></a>
##### `validateWireSafe`

```nim
proc validateWireSafe(model: PmxModel, maxStringBytes = MaxStringBytes) {.raises: [ValueError].}
```

Checks that `model` can be written in lenient mode. Only what would corrupt the wire is rejected, so the
semantic rules are skipped.

<sub>[`validation.nim:950`](../src/pmxforge/format/validation.nim#L950)</sub>

<a id="sym-validation-5"></a>
##### `validateWritePreparation`

```nim
proc validateWritePreparation(
  model: PmxModel,
  maxStringBytes = MaxStringBytes
) {.raises: [ValueError].}
```

Checks everything a writer needs before it copies or repairs the model. Defects that `repair` normalizes are
allowed here.

<sub>[`validation.nim:199`](../src/pmxforge/format/validation.nim#L199)</sub>

<a id="mod-reader"></a>
### `pmxforge/format/io/reader`

Binary PMX parser.

Provides `readPmx` and `PmxReadLimits` to load PMX 2.0 and 2.1 models from a path,
a stream, or a byte buffer. A face count that is not a multiple of three is rounded
down instead of refused.

<sub>[`src/pmxforge/format/io/reader.nim`](../src/pmxforge/format/io/reader.nim)</sub>

#### Types

<a id="sym-reader-0"></a>
##### `PmxReadLimits`

```nim
PmxReadLimits = object
  maxSourceBytes*: int64 ## Maximum input size in bytes.
  maxStringBytes*: int32 ## Maximum byte length for a single string.
  maxElementCount*: int32 ## Maximum entries per collection.
  maxTotalAllocationBytes*: int64 ## Total estimated memory limit during parsing.
  acceptNonFiniteFloats*: bool ## If true, accepts NaN and Inf instead of failing.
```

Resource limits for parsing untrusted PMX files.

<sub>[`reader.nim:25`](../src/pmxforge/format/io/reader.nim#L25)</sub>

#### Constants

<a id="sym-reader-1"></a>
##### `DefaultPmxReadLimits`

```nim
DefaultPmxReadLimits = (
  maxSourceBytes: 67108864,
  maxStringBytes: 65536,
  maxElementCount: 250000,
  maxTotalAllocationBytes: 67108864,
  acceptNonFiniteFloats: false
)
```

Default limits used by readPmx.

<sub>[`reader.nim:57`](../src/pmxforge/format/io/reader.nim#L57)</sub>

<a id="sym-reader-2"></a>
##### `DesktopPmxReadLimits`

```nim
DesktopPmxReadLimits = (
  maxSourceBytes: 268435456,
  maxStringBytes: 65536,
  maxElementCount: 1000000,
  maxTotalAllocationBytes: 268435456,
  acceptNonFiniteFloats: false
)
```

Standard limits for desktop applications (256 MB).

<sub>[`reader.nim:41`](../src/pmxforge/format/io/reader.nim#L41)</sub>

<a id="sym-reader-3"></a>
##### `SafePmxReadLimits`

```nim
SafePmxReadLimits = (
  maxSourceBytes: 67108864,
  maxStringBytes: 65536,
  maxElementCount: 250000,
  maxTotalAllocationBytes: 67108864,
  acceptNonFiniteFloats: false
)
```

Conservative limits for untrusted files and web services (64 MB).

<sub>[`reader.nim:33`](../src/pmxforge/format/io/reader.nim#L33)</sub>

<a id="sym-reader-4"></a>
##### `TrustedLargePmxReadLimits`

```nim
TrustedLargePmxReadLimits = (
  maxSourceBytes: 1073741824,
  maxStringBytes: 65536,
  maxElementCount: 4000000,
  maxTotalAllocationBytes: 1073741824,
  acceptNonFiniteFloats: false
)
```

High limits for trusted large models (1 GB).

<sub>[`reader.nim:49`](../src/pmxforge/format/io/reader.nim#L49)</sub>

#### Procedures

<a id="sym-reader-5"></a>
##### `readPmx`

```nim
proc readPmx(
  s: Stream,
  limits = DefaultPmxReadLimits
): PmxModel {.raises: [IOError, OSError, ValueError].}
```

Reads a PMX model from an open stream.

```nim
proc readPmx(
  filePath: string,
  limits = DefaultPmxReadLimits
): PmxModel {.raises: [IOError, OSError, ValueError].}
```

Reads a PMX model from disk, saving the parent directory for relative texture paths.

```nim
proc readPmx(
  data: seq[byte],
  limits = DefaultPmxReadLimits
): PmxModel {.raises: [IOError, OSError, ValueError].}
```

Reads a PMX model from an in-memory byte buffer.

<sub>[`reader.nim:941`](../src/pmxforge/format/io/reader.nim#L941)</sub>

<a id="mod-writer"></a>
### `pmxforge/format/io/writer`

Binary PMX serializer.

Provides `writePmx` and `PmxWriteLimits` to serialize a model to a path, a stream, or a byte sequence in
strict, lenient, or repair mode.

<sub>[`src/pmxforge/format/io/writer.nim`](../src/pmxforge/format/io/writer.nim)</sub>

#### Types

<a id="sym-writer-0"></a>
##### `PmxWriteLimits`

```nim
PmxWriteLimits = object
  maxOutputBytes*: int64 ## Maximum allowed size of serialized output in bytes.
  maxStringBytes*: int ## Maximum text field size; zero means `MaxStringBytes`.
```

Resource limits for serializing PMX data.

<sub>[`writer.nim:64`](../src/pmxforge/format/io/writer.nim#L64)</sub>

<a id="sym-writer-1"></a>
##### `PmxWriteMode`

```nim
PmxWriteMode = enum
  pwmStrict, ## Enforce all PMX semantic invariants (default).
  pwmLenient, ## Write as-is if wire-safe, preserving dangling references.
  pwmRepair ## Automatically repair a copy before writing.
```

Serialization validation and repair mode.

<sub>[`writer.nim:68`](../src/pmxforge/format/io/writer.nim#L68)</sub>

#### Constants

<a id="sym-writer-2"></a>
##### `DesktopPmxWriteLimits`

```nim
DesktopPmxWriteLimits = (maxOutputBytes: 268435456, maxStringBytes: 65536)
```

Standard budget for desktop models (256 MB).

<sub>[`writer.nim:79`](../src/pmxforge/format/io/writer.nim#L79)</sub>

<a id="sym-writer-3"></a>
##### `SafePmxWriteLimits`

```nim
SafePmxWriteLimits = (maxOutputBytes: 67108864, maxStringBytes: 65536)
```

Default output budget for untrusted models (64 MB).

<sub>[`writer.nim:74`](../src/pmxforge/format/io/writer.nim#L74)</sub>

<a id="sym-writer-4"></a>
##### `TrustedLargePmxWriteLimits`

```nim
TrustedLargePmxWriteLimits = (maxOutputBytes: 1073741824, maxStringBytes: 65536)
```

High budget for large trusted models (1 GB).

<sub>[`writer.nim:84`](../src/pmxforge/format/io/writer.nim#L84)</sub>

<a id="sym-writer-5"></a>
##### `UnboundedPmxWriteLimits`

```nim
UnboundedPmxWriteLimits = (maxOutputBytes: 9223372036854775807, maxStringBytes: 65536)
```

No output size limit.

<sub>[`writer.nim:89`](../src/pmxforge/format/io/writer.nim#L89)</sub>

#### Procedures

<a id="sym-writer-6"></a>
##### `writePmx`

```nim
proc writePmx(
  model: PmxModel,
  filePath: string,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].}
```

Writes `model` to `filePath` atomically using SafePmxWriteLimits.

```nim
proc writePmx(
  model: PmxModel,
  filePath: string,
  limits: PmxWriteLimits,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].}
```

Writes `model` to `filePath` atomically using the specified write limits.

```nim
proc writePmx(
  model: PmxModel,
  s: Stream,
  limits: PmxWriteLimits,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].}
```

Writes `model` to an open stream using the specified limits, with an optional `maxStringBytes` override.

```nim
proc writePmx(
  model: PmxModel,
  s: Stream,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].}
```

Writes `model` to an open stream using SafePmxWriteLimits.

```nim
proc writePmx(
  model: PmxModel,
  limits: PmxWriteLimits,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
): seq[ byte] {.raises: [IOError, OSError, ValueError].}
```

Serializes `model` to a byte sequence using the specified limits.

```nim
proc writePmx(
  model: PmxModel,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
): seq[byte] {.raises: [IOError, OSError, ValueError].}
```

Serializes `model` to a byte sequence using SafePmxWriteLimits.

<sub>[`writer.nim:728`](../src/pmxforge/format/io/writer.nim#L728)</sub>

## Byte-level primitives

<a id="mod-binary"></a>
### `pmxforge/format/io/binary`

Buffered binary primitives.

Provides `BinaryReader` and `BinaryWriter`, the little-endian layer that checks widths, text lengths, and
floats before allocating or converting.

<sub>[`src/pmxforge/format/io/binary.nim`](../src/pmxforge/format/io/binary.nim)</sub>

#### Types

<a id="sym-binary-0"></a>
##### `BinaryReader`

```nim
BinaryReader = object
```

Buffered little-endian reader over a caller-owned stream.

<sub>[`binary.nim:17`](../src/pmxforge/format/io/binary.nim#L17)</sub>

<a id="sym-binary-1"></a>
##### `BinaryWriter`

```nim
BinaryWriter = object
```

Buffered little-endian writer over a caller-owned stream.

<sub>[`binary.nim:24`](../src/pmxforge/format/io/binary.nim#L24)</sub>

#### Procedures

<a id="sym-binary-2"></a>
##### `flush`

```nim
proc flush(writer: var BinaryWriter) {.raises: [IOError, OSError].}
```

Flushes pending bytes without closing the underlying stream.

<sub>[`binary.nim:62`](../src/pmxforge/format/io/binary.nim#L62)</sub>

<a id="sym-binary-3"></a>
##### `isEnd`

```nim
proc isEnd(reader: BinaryReader): bool {.raises: [IOError, OSError].}
```

Returns true when no bytes are left, buffered or not.

<sub>[`binary.nim:89`](../src/pmxforge/format/io/binary.nim#L89)</sub>

<a id="sym-binary-4"></a>
##### `logicalPosition`

```nim
proc logicalPosition(reader: BinaryReader): int64
```

Returns how many bytes this reader has handed to the caller. The count is kept here because `std/streams` does
not check `getPositionImpl` for nil.

<sub>[`binary.nim:95`](../src/pmxforge/format/io/binary.nim#L95)</sub>

<a id="sym-binary-5"></a>
##### `newBinaryReader`

```nim
proc newBinaryReader(
  stream: Stream,
  acceptNonFiniteFloats = false
): BinaryReader {.raises: [ValueError].}
```

Creates a reader over `stream`; the caller keeps ownership. Non-finite floats are refused unless
`acceptNonFiniteFloats` is set.

<sub>[`binary.nim:81`](../src/pmxforge/format/io/binary.nim#L81)</sub>

<a id="sym-binary-6"></a>
##### `newBinaryWriter`

```nim
proc newBinaryWriter(stream: Stream): BinaryWriter {.raises: [ValueError].}
```

Creates a writer over `stream`; ownership stays with the caller.

<sub>[`binary.nim:232`](../src/pmxforge/format/io/binary.nim#L232)</sub>

<a id="sym-binary-7"></a>
##### `readFloat32`

```nim
proc readFloat32(reader: var BinaryReader): float32 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads a little-endian `float32`. NaN and infinity are rejected unless the reader accepts non-finite values.

<sub>[`binary.nim:167`](../src/pmxforge/format/io/binary.nim#L167)</sub>

<a id="sym-binary-8"></a>
##### `readIndex`

```nim
proc readIndex(
  reader: var BinaryReader,
  size: int
): int32 {.raises: [IOError, OSError, ValueError].}
```

Reads a signed PMX reference. Only `-1` may represent a null reference.

<sub>[`binary.nim:146`](../src/pmxforge/format/io/binary.nim#L146)</sub>

<a id="sym-binary-9"></a>
##### `readInt`

```nim
proc readInt(reader: var BinaryReader, size: int): int32 {.raises: [IOError, OSError, ValueError].}
```

Reads a signed PMX integer whose width is 1, 2, or 4 bytes.

<sub>[`binary.nim:134`](../src/pmxforge/format/io/binary.nim#L134)</sub>

<a id="sym-binary-10"></a>
##### `readInt16`

```nim
proc readInt16(reader: var BinaryReader): int16 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads a signed little-endian 16-bit value.

<sub>[`binary.nim:126`](../src/pmxforge/format/io/binary.nim#L126)</sub>

<a id="sym-binary-11"></a>
##### `readInt32`

```nim
proc readInt32(reader: var BinaryReader): int32 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads a signed little-endian 32-bit value.

<sub>[`binary.nim:130`](../src/pmxforge/format/io/binary.nim#L130)</sub>

<a id="sym-binary-12"></a>
##### `readInt8`

```nim
proc readInt8(reader: var BinaryReader): int8 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads a signed little-endian 8-bit value.

<sub>[`binary.nim:122`](../src/pmxforge/format/io/binary.nim#L122)</sub>

<a id="sym-binary-13"></a>
##### `readString`

```nim
proc readString(
  reader: var BinaryReader,
  textEncoding: int32,
  maxBytes = MaxStringBytes
): string {.raises: [IOError, OSError, ValueError].}
```

Reads a length-prefixed PMX string using the selected encoding.

<sub>[`binary.nim:223`](../src/pmxforge/format/io/binary.nim#L223)</sub>

<a id="sym-binary-14"></a>
##### `readStringLength`

```nim
proc readStringLength(
  reader: var BinaryReader,
  maxBytes = MaxStringBytes
): int {.raises: [IOError, OSError, ValueError].}
```

Reads a string length and applies the configured limit before allocation.

<sub>[`binary.nim:177`](../src/pmxforge/format/io/binary.nim#L177)</sub>

<a id="sym-binary-15"></a>
##### `readStringPayload`

```nim
proc readStringPayload(
  reader: var BinaryReader,
  byteLength: int,
  textEncoding: int32,
  maxBytes = MaxStringBytes
): string {.raises: [IOError, OSError, ValueError].}
```

Reads and decodes a payload after its length has been checked.

<sub>[`binary.nim:191`](../src/pmxforge/format/io/binary.nim#L191)</sub>

<a id="sym-binary-16"></a>
##### `readUInt16`

```nim
proc readUInt16(reader: var BinaryReader): uint16 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads an unsigned little-endian 16-bit value.

<sub>[`binary.nim:108`](../src/pmxforge/format/io/binary.nim#L108)</sub>

<a id="sym-binary-17"></a>
##### `readUInt32`

```nim
proc readUInt32(reader: var BinaryReader): uint32 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads an unsigned little-endian 32-bit value.

<sub>[`binary.nim:114`](../src/pmxforge/format/io/binary.nim#L114)</sub>

<a id="sym-binary-18"></a>
##### `readUInt8`

```nim
proc readUInt8(reader: var BinaryReader): uint8 {.raises: [IOError, OSError, PmxFormatError].}
```

Reads one unsigned byte.

<sub>[`binary.nim:100`](../src/pmxforge/format/io/binary.nim#L100)</sub>

<a id="sym-binary-19"></a>
##### `readVertexIndex`

```nim
proc readVertexIndex(
  reader: var BinaryReader,
  size: int
): int32 {.raises: [IOError, OSError, ValueError].}
```

Reads a vertex reference, the only unsigned index type in PMX.

<sub>[`binary.nim:152`](../src/pmxforge/format/io/binary.nim#L152)</sub>

<a id="sym-binary-20"></a>
##### `writeFloat32`

```nim
proc writeFloat32(writer: var BinaryWriter, val: float32) {.raises: [IOError, OSError, ValueError].}
```

Writes a little-endian `float32`. A value that is not finite is refused, and on JavaScript one that would
overflow the 32-bit range is refused as well.

<sub>[`binary.nim:310`](../src/pmxforge/format/io/binary.nim#L310)</sub>

<a id="sym-binary-21"></a>
##### `writeIndex`

```nim
proc writeIndex(
  writer: var BinaryWriter,
  val: int32,
  size: int
) {.raises: [IOError, OSError, ValueError].}
```

Writes a signed PMX reference, reserving only `-1` for null.

<sub>[`binary.nim:282`](../src/pmxforge/format/io/binary.nim#L282)</sub>

<a id="sym-binary-22"></a>
##### `writeInt`

```nim
proc writeInt(
  writer: var BinaryWriter,
  val: int32,
  size: int
) {.raises: [IOError, OSError, ValueError].}
```

Writes a signed PMX integer using a 1-, 2-, or 4-byte width.

<sub>[`binary.nim:266`](../src/pmxforge/format/io/binary.nim#L266)</sub>

<a id="sym-binary-23"></a>
##### `writeInt16`

```nim
proc writeInt16(writer: var BinaryWriter, val: int16) {.raises: [IOError, OSError].}
```

Writes a signed little-endian 16-bit value.

<sub>[`binary.nim:258`](../src/pmxforge/format/io/binary.nim#L258)</sub>

<a id="sym-binary-24"></a>
##### `writeInt32`

```nim
proc writeInt32(writer: var BinaryWriter, val: int32) {.raises: [IOError, OSError].}
```

Writes a signed little-endian 32-bit value.

<sub>[`binary.nim:262`](../src/pmxforge/format/io/binary.nim#L262)</sub>

<a id="sym-binary-25"></a>
##### `writeInt8`

```nim
proc writeInt8(writer: var BinaryWriter, val: int8) {.raises: [IOError, OSError].}
```

Writes a signed little-endian 8-bit value.

<sub>[`binary.nim:254`](../src/pmxforge/format/io/binary.nim#L254)</sub>

<a id="sym-binary-26"></a>
##### `writeRawStr`

```nim
proc writeRawStr(writer: var BinaryWriter, s: string) {.raises: [IOError, OSError].}
```

Flushes buffered bytes and writes raw bytes without a length prefix.

<sub>[`binary.nim:320`](../src/pmxforge/format/io/binary.nim#L320)</sub>

<a id="sym-binary-27"></a>
##### `writeString`

```nim
proc writeString(
  writer: var BinaryWriter,
  text: string,
  textEncoding: int32,
  maxBytes = MaxStringBytes
) {.raises: [IOError, OSError, ValueError].}
```

Encodes and writes a length-prefixed PMX string within `maxBytes`.

<sub>[`binary.nim:325`](../src/pmxforge/format/io/binary.nim#L325)</sub>

<a id="sym-binary-28"></a>
##### `writeUInt16`

```nim
proc writeUInt16(writer: var BinaryWriter, val: uint16) {.raises: [IOError, OSError].}
```

Writes an unsigned little-endian 16-bit value.

<sub>[`binary.nim:242`](../src/pmxforge/format/io/binary.nim#L242)</sub>

<a id="sym-binary-29"></a>
##### `writeUInt32`

```nim
proc writeUInt32(writer: var BinaryWriter, val: uint32) {.raises: [IOError, OSError].}
```

Writes an unsigned little-endian 32-bit value.

<sub>[`binary.nim:247`](../src/pmxforge/format/io/binary.nim#L247)</sub>

<a id="sym-binary-30"></a>
##### `writeUInt8`

```nim
proc writeUInt8(writer: var BinaryWriter, val: uint8) {.raises: [IOError, OSError].}
```

Writes one unsigned byte.

<sub>[`binary.nim:238`](../src/pmxforge/format/io/binary.nim#L238)</sub>

<a id="sym-binary-31"></a>
##### `writeVertexIndex`

```nim
proc writeVertexIndex(
  writer: var BinaryWriter,
  val: int32,
  size: int
) {.raises: [IOError, OSError, ValueError].}
```

Writes a non-negative unsigned PMX vertex reference.

<sub>[`binary.nim:288`](../src/pmxforge/format/io/binary.nim#L288)</sub>

<a id="mod-text_codec"></a>
### `pmxforge/format/io/text_codec`

PMX text codec.

Provides UTF-8 validation and UTF-16LE conversion for the text fields, which PMX stores in either encoding.

<sub>[`src/pmxforge/format/io/text_codec.nim`](../src/pmxforge/format/io/text_codec.nim)</sub>

#### Procedures

<a id="sym-text_codec-0"></a>
##### `decodeUtf16Le`

```nim
proc decodeUtf16Le(bytes: string): string {.raises: [ValueError].}
```

Decodes UTF-16LE bytes into a UTF-8 Nim string.

<sub>[`text_codec.nim:89`](../src/pmxforge/format/io/text_codec.nim#L89)</sub>

<a id="sym-text_codec-1"></a>
##### `encodeUtf16Le`

```nim
proc encodeUtf16Le(text: string, maxBytes = high(int)): string {.raises: [ValueError].}
```

Encodes a UTF-8 string to UTF-16LE bytes.

<sub>[`text_codec.nim:124`](../src/pmxforge/format/io/text_codec.nim#L124)</sub>

<a id="sym-text_codec-2"></a>
##### `utf16LeByteLength`

```nim
proc utf16LeByteLength(text: string, maxBytes = high(int)): int {.raises: [ValueError].}
```

Returns the byte length of `text` when encoded as UTF-16LE.

<sub>[`text_codec.nim:114`](../src/pmxforge/format/io/text_codec.nim#L114)</sub>

<a id="sym-text_codec-3"></a>
##### `validateUtf8`

```nim
proc validateUtf8(s: string) {.raises: [ValueError].}
```

Validates that `s` contains well-formed UTF-8 without allocating.

<sub>[`text_codec.nim:84`](../src/pmxforge/format/io/text_codec.nim#L84)</sub>

#### Iterators

<a id="sym-text_codec-4"></a>
##### `utf8Codepoints`

```nim
iterator utf8Codepoints(s: string): int32 {.raises: [ValueError].}
```

Iterates over Unicode codepoints in a UTF-8 string, validating sequences.

<sub>[`text_codec.nim:50`](../src/pmxforge/format/io/text_codec.nim#L50)</sub>

<a id="mod-file_metadata"></a>
### `pmxforge/format/io/file_metadata`

Extended metadata preservation.

Provides the xattr and ACL snapshot and restore helpers used when an existing file is replaced on
Linux, macOS, and the BSDs.

<sub>[`src/pmxforge/format/io/file_metadata.nim`](../src/pmxforge/format/io/file_metadata.nim)</sub>

#### Types

<a id="sym-file_metadata-0"></a>
##### `ExtendedFileAttribute`

```nim
ExtendedFileAttribute = object
  name*: string ## Attribute name string.
  value*: seq[byte] ## Binary attribute value payload.
```

Extended file attribute name-value pair.

<sub>[`file_metadata.nim:11`](../src/pmxforge/format/io/file_metadata.nim#L11)</sub>

#### Procedures

<a id="sym-file_metadata-1"></a>
##### `clearUnlistedExtendedFileAttributes`

```nim
proc clearUnlistedExtendedFileAttributes(
  file: File,
  filePath: string,
  attributes: openArray[ExtendedFileAttribute]
) {.raises: [IOError].}
```

Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.

<sub>[`file_metadata.nim:691`](../src/pmxforge/format/io/file_metadata.nim#L691)</sub>

<a id="sym-file_metadata-2"></a>
##### `restoreExtendedFileAttributes`

```nim
proc restoreExtendedFileAttributes(
  file: File,
  filePath: string,
  attributes: openArray[ExtendedFileAttribute]
) {.raises: [IOError].}
```

Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.

<sub>[`file_metadata.nim:680`](../src/pmxforge/format/io/file_metadata.nim#L680)</sub>

<a id="sym-file_metadata-3"></a>
##### `snapshotExtendedFileAttributes`

```nim
proc snapshotExtendedFileAttributes(
  filePath: string
): seq[ExtendedFileAttribute] {.raises: [IOError].}
```

Fails closed on unsupported POSIX targets lacking xattr/ACL bindings.

<sub>[`file_metadata.nim:673`](../src/pmxforge/format/io/file_metadata.nim#L673)</sub>

<a id="index"></a>
## Symbol index

| Symbol | Kind | Module |
|:-------|:-----|:-------|
| `*=` | func | [pmxforge/core/colors](#sym-colors-24) |
| `*=` | func | [pmxforge/core/vectors](#sym-vectors-47) |
| `*` | func | [pmxforge/core/colors](#sym-colors-25) |
| `*` | func | [pmxforge/core/vectors](#sym-vectors-48) |
| `+=` | func | [pmxforge/core/colors](#sym-colors-26) |
| `+=` | func | [pmxforge/core/vectors](#sym-vectors-49) |
| `+` | func | [pmxforge/core/colors](#sym-colors-27) |
| `+` | func | [pmxforge/core/vectors](#sym-vectors-50) |
| `-=` | func | [pmxforge/core/colors](#sym-colors-28) |
| `-=` | func | [pmxforge/core/vectors](#sym-vectors-51) |
| `-` | func | [pmxforge/core/colors](#sym-colors-29) |
| `-` | func | [pmxforge/core/vectors](#sym-vectors-52) |
| `/=` | func | [pmxforge/core/colors](#sym-colors-30) |
| `/=` | func | [pmxforge/core/vectors](#sym-vectors-53) |
| `/` | func | [pmxforge/core/colors](#sym-colors-31) |
| `/` | func | [pmxforge/core/vectors](#sym-vectors-54) |
| `==` | func | [pmxforge/core/colors](#sym-colors-32) |
| `==` | func | [pmxforge/core/vectors](#sym-vectors-55) |
| `==` | proc | [pmxforge/format/elements/bone](#sym-bone-14) |
| `==` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-10) |
| `==` | proc | [pmxforge/format/elements/face](#sym-face-7) |
| `==` | proc | [pmxforge/format/elements/joint](#sym-joint-11) |
| `==` | proc | [pmxforge/format/elements/material](#sym-material-6) |
| `==` | proc | [pmxforge/format/elements/morph](#sym-morph-19) |
| `==` | proc | [pmxforge/format/elements/rigid_body](#sym-rigid_body-7) |
| `==` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-13) |
| `==` | proc | [pmxforge/format/elements/texture](#sym-texture-5) |
| `==` | proc | [pmxforge/format/elements/vertex](#sym-vertex-22) |
| `==` | proc | [pmxforge/format/model](#sym-model-5) |
| `abs` | func | [pmxforge/core/vectors](#sym-vectors-7) |
| `AerodynamicsModel` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-0) |
| `AnchorRigidBody` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-1) |
| `angle` | func | [pmxforge/core/vectors](#sym-vectors-8) |
| `back` | func | [pmxforge/core/vectors](#sym-vectors-9) |
| `BDEF1` | type | [pmxforge/format/elements/vertex](#sym-vertex-0) |
| `BDEF2` | type | [pmxforge/format/elements/vertex](#sym-vertex-1) |
| `BDEF4` | type | [pmxforge/format/elements/vertex](#sym-vertex-2) |
| `BinaryReader` | type | [pmxforge/format/io/binary](#sym-binary-0) |
| `BinaryWriter` | type | [pmxforge/format/io/binary](#sym-binary-1) |
| `black` | func | [pmxforge/core/colors](#sym-colors-2) |
| `blue` | func | [pmxforge/core/colors](#sym-colors-3) |
| `Bone` | type | [pmxforge/format/elements/bone](#sym-bone-0) |
| `BoneFlags` | type | [pmxforge/format/flags](#sym-flags-0) |
| `BoneIK` | type | [pmxforge/format/elements/bone](#sym-bone-1) |
| `BoneMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-0) |
| `checkElementCount` | proc | [pmxforge/format/limits](#sym-limits-3) |
| `clamp` | func | [pmxforge/core/vectors](#sym-vectors-10) |
| `clamp01` | func | [pmxforge/core/colors](#sym-colors-4) |
| `clearUnlistedExtendedFileAttributes` | proc | [pmxforge/format/io/file_metadata](#sym-file_metadata-1) |
| `CollisionMask` | type | [pmxforge/format/flags](#sym-flags-1) |
| `conjugate` | func | [pmxforge/core/vectors](#sym-vectors-11) |
| `containsVertex` | func | [pmxforge/format/elements/face](#sym-face-1) |
| `copy` | proc | [pmxforge/format/elements/bone](#sym-bone-3) |
| `copy` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-3) |
| `copy` | proc | [pmxforge/format/elements/face](#sym-face-2) |
| `copy` | proc | [pmxforge/format/elements/joint](#sym-joint-2) |
| `copy` | proc | [pmxforge/format/elements/material](#sym-material-2) |
| `copy` | proc | [pmxforge/format/elements/morph](#sym-morph-13) |
| `copy` | proc | [pmxforge/format/elements/rigid_body](#sym-rigid_body-3) |
| `copy` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-8) |
| `copy` | proc | [pmxforge/format/elements/texture](#sym-texture-1) |
| `copy` | proc | [pmxforge/format/elements/vertex](#sym-vertex-8) |
| `copy` | proc | [pmxforge/format/model](#sym-model-1) |
| `cross` | func | [pmxforge/core/vectors](#sym-vectors-12) |
| `cyan` | func | [pmxforge/core/colors](#sym-colors-5) |
| `decodeUtf16Le` | proc | [pmxforge/format/io/text_codec](#sym-text_codec-0) |
| `DefaultPmxReadLimits` | const | [pmxforge/format/io/reader](#sym-reader-1) |
| `DeformData` | type | [pmxforge/format/elements/vertex](#sym-vertex-3) |
| `DeformKind` | type | [pmxforge/format/elements/vertex](#sym-vertex-4) |
| `Deg2Rad` | const | [pmxforge/core/vectors](#sym-vectors-4) |
| `DesktopPmxReadLimits` | const | [pmxforge/format/io/reader](#sym-reader-2) |
| `DesktopPmxWriteLimits` | const | [pmxforge/format/io/writer](#sym-writer-2) |
| `DisplayFrame` | type | [pmxforge/format/elements/display_slot](#sym-display_slot-0) |
| `DisplayFrameType` | type | [pmxforge/format/elements/display_slot](#sym-display_slot-1) |
| `DisplaySlot` | type | [pmxforge/format/elements/display_slot](#sym-display_slot-2) |
| `distance` | func | [pmxforge/core/vectors](#sym-vectors-13) |
| `distanceSquared` | func | [pmxforge/core/vectors](#sym-vectors-14) |
| `dot` | func | [pmxforge/core/vectors](#sym-vectors-15) |
| `down` | func | [pmxforge/core/vectors](#sym-vectors-16) |
| `encodeUtf16Le` | proc | [pmxforge/format/io/text_codec](#sym-text_codec-1) |
| `Epsilon` | const | [pmxforge/core/vectors](#sym-vectors-5) |
| `ExtendedFileAttribute` | type | [pmxforge/format/io/file_metadata](#sym-file_metadata-0) |
| `Face` | type | [pmxforge/format/elements/face](#sym-face-0) |
| `FlipMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-1) |
| `flush` | proc | [pmxforge/format/io/binary](#sym-binary-2) |
| `forward` | func | [pmxforge/core/vectors](#sym-vectors-17) |
| `fromAxisAngle` | func | [pmxforge/core/vectors](#sym-vectors-18) |
| `fromBytes` | func | [pmxforge/core/colors](#sym-colors-6) |
| `fromEuler` | func | [pmxforge/core/vectors](#sym-vectors-19) |
| `fromHexRGB` | proc | [pmxforge/core/colors](#sym-colors-7) |
| `fromHexRGBA` | proc | [pmxforge/core/colors](#sym-colors-8) |
| `fromToRotation` | func | [pmxforge/core/vectors](#sym-vectors-20) |
| `getBoneIndices` | proc | [pmxforge/format/elements/vertex](#sym-vertex-9) |
| `getBoneIndicesInto` | proc | [pmxforge/format/elements/vertex](#sym-vertex-10) |
| `getExpectedMorphOffsetKind` | proc | [pmxforge/format/elements/morph](#sym-morph-14) |
| `getIndices` | func | [pmxforge/format/elements/face](#sym-face-3) |
| `getWeights` | proc | [pmxforge/format/elements/vertex](#sym-vertex-11) |
| `green` | func | [pmxforge/core/colors](#sym-colors-9) |
| `GroupMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-2) |
| `hash` | func | [pmxforge/core/colors](#sym-colors-10) |
| `hash` | func | [pmxforge/core/vectors](#sym-vectors-21) |
| `hasIk` | func | [pmxforge/format/elements/bone](#sym-bone-4) |
| `hasParent` | func | [pmxforge/format/elements/bone](#sym-bone-5) |
| `hasTailBone` | func | [pmxforge/format/elements/bone](#sym-bone-6) |
| `identity` | func | [pmxforge/core/vectors](#sym-vectors-22) |
| `IKLink` | type | [pmxforge/format/elements/bone](#sym-bone-2) |
| `ImpulseMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-3) |
| `inverse` | func | [pmxforge/core/vectors](#sym-vectors-23) |
| `isEmpty` | func | [pmxforge/format/elements/texture](#sym-texture-2) |
| `isEnd` | proc | [pmxforge/format/io/binary](#sym-binary-3) |
| `isPmx21Only` | func | [pmxforge/format/elements/joint](#sym-joint-3) |
| `isPmx21Only` | func | [pmxforge/format/elements/morph](#sym-morph-15) |
| `isPmx21Only` | func | [pmxforge/format/elements/vertex](#sym-vertex-12) |
| `isPmx21Only` | func | [pmxforge/format/validation](#sym-validation-0) |
| `isValid` | proc | [pmxforge/format/elements/bone](#sym-bone-7) |
| `isValid` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-4) |
| `isValid` | proc | [pmxforge/format/elements/face](#sym-face-4) |
| `isValid` | proc | [pmxforge/format/elements/joint](#sym-joint-4) |
| `isValid` | proc | [pmxforge/format/elements/material](#sym-material-3) |
| `isValid` | proc | [pmxforge/format/elements/morph](#sym-morph-16) |
| `isValid` | proc | [pmxforge/format/elements/rigid_body](#sym-rigid_body-4) |
| `isValid` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-9) |
| `isValid` | proc | [pmxforge/format/elements/texture](#sym-texture-3) |
| `isValid` | proc | [pmxforge/format/elements/vertex](#sym-vertex-13) |
| `isValid` | proc | [pmxforge/format/validation](#sym-validation-1) |
| `Joint` | type | [pmxforge/format/elements/joint](#sym-joint-0) |
| `JointType` | type | [pmxforge/format/elements/joint](#sym-joint-1) |
| `left` | func | [pmxforge/core/vectors](#sym-vectors-24) |
| `length` | func | [pmxforge/core/vectors](#sym-vectors-25) |
| `lengthSquared` | func | [pmxforge/core/vectors](#sym-vectors-26) |
| `lerp` | func | [pmxforge/core/colors](#sym-colors-11) |
| `lerp` | func | [pmxforge/core/vectors](#sym-vectors-27) |
| `limitOrderIsValid` | func | [pmxforge/format/elements/joint](#sym-joint-5) |
| `logicalPosition` | proc | [pmxforge/format/io/binary](#sym-binary-4) |
| `lookRotation` | func | [pmxforge/core/vectors](#sym-vectors-28) |
| `magenta` | func | [pmxforge/core/colors](#sym-colors-12) |
| `Material` | type | [pmxforge/format/elements/material](#sym-material-0) |
| `MaterialFlags` | type | [pmxforge/format/flags](#sym-flags-2) |
| `MaterialMorphBlendMode` | type | [pmxforge/format/elements/morph](#sym-morph-4) |
| `MaterialMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-5) |
| `max` | func | [pmxforge/core/vectors](#sym-vectors-29) |
| `MaxElementCount` | const | [pmxforge/format/limits](#sym-limits-0) |
| `MaxPmxStringBytes` | const | [pmxforge/format/limits](#sym-limits-1) |
| `MaxStringBytes` | const | [pmxforge/format/limits](#sym-limits-2) |
| `min` | func | [pmxforge/core/vectors](#sym-vectors-30) |
| `Morph` | type | [pmxforge/format/elements/morph](#sym-morph-6) |
| `MorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-7) |
| `MorphOffsetKind` | type | [pmxforge/format/elements/morph](#sym-morph-8) |
| `MorphPanelType` | type | [pmxforge/format/elements/morph](#sym-morph-9) |
| `MorphType` | type | [pmxforge/format/elements/morph](#sym-morph-10) |
| `moveTowards` | func | [pmxforge/core/vectors](#sym-vectors-31) |
| `newBDEF1` | proc | [pmxforge/format/elements/vertex](#sym-vertex-14) |
| `newBDEF2` | proc | [pmxforge/format/elements/vertex](#sym-vertex-15) |
| `newBDEF4` | proc | [pmxforge/format/elements/vertex](#sym-vertex-16) |
| `newBinaryReader` | proc | [pmxforge/format/io/binary](#sym-binary-5) |
| `newBinaryWriter` | proc | [pmxforge/format/io/binary](#sym-binary-6) |
| `newBone` | proc | [pmxforge/format/elements/bone](#sym-bone-8) |
| `newBoneDisplayFrame` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-5) |
| `newBoneIK` | proc | [pmxforge/format/elements/bone](#sym-bone-9) |
| `newBoneTail` | proc | [pmxforge/format/elements/bone](#sym-bone-10) |
| `newDisplayFrame` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-6) |
| `newDisplaySlot` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-7) |
| `newFace` | proc | [pmxforge/format/elements/face](#sym-face-5) |
| `newIKLink` | proc | [pmxforge/format/elements/bone](#sym-bone-11) |
| `newJoint` | proc | [pmxforge/format/elements/joint](#sym-joint-6) |
| `newLimitedIKLink` | proc | [pmxforge/format/elements/bone](#sym-bone-12) |
| `newMaterial` | proc | [pmxforge/format/elements/material](#sym-material-4) |
| `newMorph` | proc | [pmxforge/format/elements/morph](#sym-morph-17) |
| `newMorphDisplayFrame` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-8) |
| `newPmxModel` | proc | [pmxforge/format/model](#sym-model-2) |
| `newQDEF` | proc | [pmxforge/format/elements/vertex](#sym-vertex-17) |
| `newRigidBody` | proc | [pmxforge/format/elements/rigid_body](#sym-rigid_body-5) |
| `newSDEF` | proc | [pmxforge/format/elements/vertex](#sym-vertex-18) |
| `newSoftBody` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-10) |
| `newSoftBodyConfig` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-11) |
| `newTexture` | proc | [pmxforge/format/elements/texture](#sym-texture-4) |
| `newVertex` | proc | [pmxforge/format/elements/vertex](#sym-vertex-19) |
| `nlerp` | func | [pmxforge/core/vectors](#sym-vectors-32) |
| `normalize` | func | [pmxforge/core/vectors](#sym-vectors-33) |
| `one` | func | [pmxforge/core/vectors](#sym-vectors-34) |
| `orderedPositionLimitAxes` | func | [pmxforge/format/elements/joint](#sym-joint-7) |
| `orderedRotationLimitAxes` | func | [pmxforge/format/elements/joint](#sym-joint-8) |
| `perpendicular` | func | [pmxforge/core/vectors](#sym-vectors-35) |
| `PhysicsMode` | type | [pmxforge/format/elements/rigid_body](#sym-rigid_body-0) |
| `PmxFormatError` | type | [pmxforge/format/errors](#sym-errors-0) |
| `PmxLimitError` | type | [pmxforge/format/errors](#sym-errors-1) |
| `PmxModel` | type | [pmxforge/format/model](#sym-model-0) |
| `PmxReadLimits` | type | [pmxforge/format/io/reader](#sym-reader-0) |
| `PmxTruncatedError` | type | [pmxforge/format/errors](#sym-errors-2) |
| `PmxVersion` | type | [pmxforge/format/enums](#sym-enums-0) |
| `PmxWriteLimits` | type | [pmxforge/format/io/writer](#sym-writer-0) |
| `PmxWriteMode` | type | [pmxforge/format/io/writer](#sym-writer-1) |
| `project` | func | [pmxforge/core/vectors](#sym-vectors-36) |
| `projectOnPlane` | func | [pmxforge/core/vectors](#sym-vectors-37) |
| `QDEF` | type | [pmxforge/format/elements/vertex](#sym-vertex-5) |
| `Quaternion` | type | [pmxforge/core/vectors](#sym-vectors-0) |
| `Rad2Deg` | const | [pmxforge/core/vectors](#sym-vectors-6) |
| `readFloat32` | proc | [pmxforge/format/io/binary](#sym-binary-7) |
| `readIndex` | proc | [pmxforge/format/io/binary](#sym-binary-8) |
| `readInt` | proc | [pmxforge/format/io/binary](#sym-binary-9) |
| `readInt16` | proc | [pmxforge/format/io/binary](#sym-binary-10) |
| `readInt32` | proc | [pmxforge/format/io/binary](#sym-binary-11) |
| `readInt8` | proc | [pmxforge/format/io/binary](#sym-binary-12) |
| `readPmx` | proc | [pmxforge/format/io/reader](#sym-reader-5) |
| `readString` | proc | [pmxforge/format/io/binary](#sym-binary-13) |
| `readStringLength` | proc | [pmxforge/format/io/binary](#sym-binary-14) |
| `readStringPayload` | proc | [pmxforge/format/io/binary](#sym-binary-15) |
| `readUInt16` | proc | [pmxforge/format/io/binary](#sym-binary-16) |
| `readUInt32` | proc | [pmxforge/format/io/binary](#sym-binary-17) |
| `readUInt8` | proc | [pmxforge/format/io/binary](#sym-binary-18) |
| `readVertexIndex` | proc | [pmxforge/format/io/binary](#sym-binary-19) |
| `red` | func | [pmxforge/core/colors](#sym-colors-13) |
| `reflect` | func | [pmxforge/core/vectors](#sym-vectors-38) |
| `repair` | proc | [pmxforge/format/elements/bone](#sym-bone-13) |
| `repair` | proc | [pmxforge/format/elements/display_slot](#sym-display_slot-9) |
| `repair` | proc | [pmxforge/format/elements/face](#sym-face-6) |
| `repair` | proc | [pmxforge/format/elements/joint](#sym-joint-9) |
| `repair` | proc | [pmxforge/format/elements/material](#sym-material-5) |
| `repair` | proc | [pmxforge/format/elements/morph](#sym-morph-18) |
| `repair` | proc | [pmxforge/format/elements/rigid_body](#sym-rigid_body-6) |
| `repair` | proc | [pmxforge/format/elements/soft_body](#sym-soft_body-12) |
| `repair` | proc | [pmxforge/format/elements/vertex](#sym-vertex-20) |
| `repair` | proc | [pmxforge/format/model](#sym-model-3) |
| `repairLimitOrder` | proc | [pmxforge/format/elements/joint](#sym-joint-10) |
| `repairWithReport` | proc | [pmxforge/format/validation](#sym-validation-2) |
| `restoreExtendedFileAttributes` | proc | [pmxforge/format/io/file_metadata](#sym-file_metadata-2) |
| `RGB` | type | [pmxforge/core/colors](#sym-colors-0) |
| `rgb` | func | [pmxforge/core/colors](#sym-colors-14) |
| `RGBA` | type | [pmxforge/core/colors](#sym-colors-1) |
| `rgba` | func | [pmxforge/core/colors](#sym-colors-15) |
| `right` | func | [pmxforge/core/vectors](#sym-vectors-39) |
| `RigidBody` | type | [pmxforge/format/elements/rigid_body](#sym-rigid_body-1) |
| `RigidBodyShape` | type | [pmxforge/format/elements/rigid_body](#sym-rigid_body-2) |
| `rotateTowards` | func | [pmxforge/core/vectors](#sym-vectors-40) |
| `SafePmxReadLimits` | const | [pmxforge/format/io/reader](#sym-reader-3) |
| `SafePmxWriteLimits` | const | [pmxforge/format/io/writer](#sym-writer-3) |
| `samePmxContent` | proc | [pmxforge/format/model](#sym-model-4) |
| `SDEF` | type | [pmxforge/format/elements/vertex](#sym-vertex-6) |
| `signedAngle` | func | [pmxforge/core/vectors](#sym-vectors-41) |
| `slerp` | func | [pmxforge/core/vectors](#sym-vectors-42) |
| `snapshotExtendedFileAttributes` | proc | [pmxforge/format/io/file_metadata](#sym-file_metadata-3) |
| `SoftBody` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-2) |
| `SoftBodyCluster` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-3) |
| `SoftBodyConfig` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-4) |
| `SoftBodyFlags` | type | [pmxforge/format/flags](#sym-flags-3) |
| `SoftBodyIteration` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-5) |
| `SoftBodyMaterial` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-6) |
| `SoftBodyShape` | type | [pmxforge/format/elements/soft_body](#sym-soft_body-7) |
| `SphereBlendMode` | type | [pmxforge/format/elements/material](#sym-material-1) |
| `TextEncoding` | type | [pmxforge/format/enums](#sym-enums-1) |
| `Texture` | type | [pmxforge/format/elements/texture](#sym-texture-0) |
| `toAxisAngle` | func | [pmxforge/core/vectors](#sym-vectors-43) |
| `toBoneFlags` | func | [pmxforge/format/flags](#sym-flags-4) |
| `toBytes` | func | [pmxforge/core/colors](#sym-colors-16) |
| `toCollisionMask` | func | [pmxforge/format/flags](#sym-flags-5) |
| `toEuler` | func | [pmxforge/core/vectors](#sym-vectors-44) |
| `toFileVersion` | proc | [pmxforge/format/enums](#sym-enums-2) |
| `toHex` | func | [pmxforge/core/colors](#sym-colors-17) |
| `toLinear` | func | [pmxforge/core/colors](#sym-colors-18) |
| `toMask` | func | [pmxforge/format/flags](#sym-flags-6) |
| `toMaterialFlags` | func | [pmxforge/format/flags](#sym-flags-7) |
| `toSoftBodyFlags` | func | [pmxforge/format/flags](#sym-flags-8) |
| `toSRGB` | func | [pmxforge/core/colors](#sym-colors-19) |
| `transparent` | func | [pmxforge/core/colors](#sym-colors-20) |
| `TrustedLargePmxReadLimits` | const | [pmxforge/format/io/reader](#sym-reader-4) |
| `TrustedLargePmxWriteLimits` | const | [pmxforge/format/io/writer](#sym-writer-4) |
| `UnboundedPmxWriteLimits` | const | [pmxforge/format/io/writer](#sym-writer-5) |
| `up` | func | [pmxforge/core/vectors](#sym-vectors-45) |
| `utf16LeByteLength` | proc | [pmxforge/format/io/text_codec](#sym-text_codec-2) |
| `utf8Codepoints` | iterator | [pmxforge/format/io/text_codec](#sym-text_codec-4) |
| `UVMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-11) |
| `validate` | proc | [pmxforge/format/validation](#sym-validation-3) |
| `validateDeform` | proc | [pmxforge/format/elements/vertex](#sym-vertex-21) |
| `validateUtf8` | proc | [pmxforge/format/io/text_codec](#sym-text_codec-3) |
| `validateWireSafe` | proc | [pmxforge/format/validation](#sym-validation-4) |
| `validateWritePreparation` | proc | [pmxforge/format/validation](#sym-validation-5) |
| `Vector2` | type | [pmxforge/core/vectors](#sym-vectors-1) |
| `Vector3` | type | [pmxforge/core/vectors](#sym-vectors-2) |
| `Vector4` | type | [pmxforge/core/vectors](#sym-vectors-3) |
| `Vertex` | type | [pmxforge/format/elements/vertex](#sym-vertex-7) |
| `VertexMorphOffset` | type | [pmxforge/format/elements/morph](#sym-morph-12) |
| `white` | func | [pmxforge/core/colors](#sym-colors-21) |
| `withAlpha` | func | [pmxforge/core/colors](#sym-colors-22) |
| `writeFloat32` | proc | [pmxforge/format/io/binary](#sym-binary-20) |
| `writeIndex` | proc | [pmxforge/format/io/binary](#sym-binary-21) |
| `writeInt` | proc | [pmxforge/format/io/binary](#sym-binary-22) |
| `writeInt16` | proc | [pmxforge/format/io/binary](#sym-binary-23) |
| `writeInt32` | proc | [pmxforge/format/io/binary](#sym-binary-24) |
| `writeInt8` | proc | [pmxforge/format/io/binary](#sym-binary-25) |
| `writePmx` | proc | [pmxforge/format/io/writer](#sym-writer-6) |
| `writeRawStr` | proc | [pmxforge/format/io/binary](#sym-binary-26) |
| `writeString` | proc | [pmxforge/format/io/binary](#sym-binary-27) |
| `writeUInt16` | proc | [pmxforge/format/io/binary](#sym-binary-28) |
| `writeUInt32` | proc | [pmxforge/format/io/binary](#sym-binary-29) |
| `writeUInt8` | proc | [pmxforge/format/io/binary](#sym-binary-30) |
| `writeVertexIndex` | proc | [pmxforge/format/io/binary](#sym-binary-31) |
| `yellow` | func | [pmxforge/core/colors](#sym-colors-23) |
| `zero` | func | [pmxforge/core/vectors](#sym-vectors-46) |

---

*This reference is generated. Do not edit it by hand: run `nimble apiDocs` after changing the public API.*

