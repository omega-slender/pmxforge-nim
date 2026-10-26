## Color types and conversion helpers.
##
## Provides `RGB` and `RGBA` with clamping, sRGB conversion, and hex parsing for
## material, morph, and edge colors.

import std/[hashes, math, strutils, strformat]

type
  RGB* = object ## RGB color with normalized float32 channels.
    r*: float32 ## Red channel (0.0 to 1.0).
    g*: float32 ## Green channel (0.0 to 1.0).
    b*: float32 ## Blue channel (0.0 to 1.0).

  RGBA* = object ## RGBA color with normalized float32 channels and alpha.
    r*: float32 ## Red channel (0.0 to 1.0).
    g*: float32 ## Green channel (0.0 to 1.0).
    b*: float32 ## Blue channel (0.0 to 1.0).
    a*: float32 ## Alpha channel (0.0 to 1.0).

func canonicalFloatHash(value: float32): Hash {.inline.} =
  ## Canonicalizes signed zero before hashing.
  hash(if value == 0.0'f32: 0.0'f32 else: value)

func hash*(value: RGB): Hash =
  ## Hashes the channels; `0.0` and `-0.0` hash the same.
  result = !$(canonicalFloatHash(value.r) !& canonicalFloatHash(value.g) !& canonicalFloatHash(value.b))

func hash*(value: RGBA): Hash =
  ## Hashes the channels, alpha included; `0.0` and `-0.0` hash alike.
  result = !$(
    canonicalFloatHash(value.r) !& canonicalFloatHash(value.g) !& canonicalFloatHash(value.b) !&
      canonicalFloatHash(value.a))

func toByte(v: float32): uint8 {.inline.} =
  ## Converts a 0.0-1.0 channel to uint8, clamping and rounding.
  let c = classify(v)
  if c == fcNaN or v <= 0.0'f32:
    0'u8
  elif c == fcInf or v >= 1.0'f32:
    255'u8
  else:
    uint8(v * 255.0'f32 + 0.5'f32)

func clamp01Value(v: float32): float32 {.inline.} =
  ## Clamps a float to the 0.0-1.0 range, treating NaN as 0.0.
  if classify(v) == fcNaN or v < 0.0'f32:
    0.0'f32
  elif v > 1.0'f32:
    1.0'f32
  else:
    v

func rgb*(r, g, b: float32): RGB {.inline.} =
  ## Creates an RGB color from normalized channels.
  RGB(r: r, g: g, b: b)

func rgba*(r, g, b, a: float32): RGBA {.inline.} =
  ## Creates an RGBA color from normalized channels.
  RGBA(r: r, g: g, b: b, a: a)

func white*(T: type RGB): RGB {.inline.} =
  ## Opaque white (1, 1, 1).
  RGB(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32)

func black*(T: type RGB): RGB {.inline.} =
  ## Opaque black (0, 0, 0).
  RGB(r: 0.0'f32, g: 0.0'f32, b: 0.0'f32)

func white*(T: type RGBA): RGBA {.inline.} =
  ## Opaque white (1, 1, 1, 1).
  RGBA(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32, a: 1.0'f32)

func black*(T: type RGBA): RGBA {.inline.} =
  ## Opaque black (0, 0, 0, 1).
  RGBA(r: 0.0'f32, g: 0.0'f32, b: 0.0'f32, a: 1.0'f32)

func transparent*(T: type RGBA): RGBA {.inline.} =
  ## Fully transparent black (0, 0, 0, 0).
  RGBA(r: 0.0'f32, g: 0.0'f32, b: 0.0'f32, a: 0.0'f32)

func red*(T: type RGB): RGB {.inline.} =
  ## Opaque red (1, 0, 0).
  RGB(r: 1.0'f32, g: 0.0'f32, b: 0.0'f32)

func green*(T: type RGB): RGB {.inline.} =
  ## Opaque green (0, 1, 0).
  RGB(r: 0.0'f32, g: 1.0'f32, b: 0.0'f32)

func blue*(T: type RGB): RGB {.inline.} =
  ## Opaque blue (0, 0, 1).
  RGB(r: 0.0'f32, g: 0.0'f32, b: 1.0'f32)

func yellow*(T: type RGB): RGB {.inline.} =
  ## Opaque yellow (1, 1, 0).
  RGB(r: 1.0'f32, g: 1.0'f32, b: 0.0'f32)

func cyan*(T: type RGB): RGB {.inline.} =
  ## Opaque cyan (0, 1, 1).
  RGB(r: 0.0'f32, g: 1.0'f32, b: 1.0'f32)

func magenta*(T: type RGB): RGB {.inline.} =
  ## Opaque magenta (1, 0, 1).
  RGB(r: 1.0'f32, g: 0.0'f32, b: 1.0'f32)

func red*(T: type RGBA): RGBA {.inline.} =
  ## Opaque red (1, 0, 0, 1).
  RGBA(r: 1.0'f32, g: 0.0'f32, b: 0.0'f32, a: 1.0'f32)

func green*(T: type RGBA): RGBA {.inline.} =
  ## Opaque green (0, 1, 0, 1).
  RGBA(r: 0.0'f32, g: 1.0'f32, b: 0.0'f32, a: 1.0'f32)

func blue*(T: type RGBA): RGBA {.inline.} =
  ## Opaque blue (0, 0, 1, 1).
  RGBA(r: 0.0'f32, g: 0.0'f32, b: 1.0'f32, a: 1.0'f32)

func yellow*(T: type RGBA): RGBA {.inline.} =
  ## Opaque yellow (1, 1, 0, 1).
  RGBA(r: 1.0'f32, g: 1.0'f32, b: 0.0'f32, a: 1.0'f32)

func cyan*(T: type RGBA): RGBA {.inline.} =
  ## Opaque cyan (0, 1, 1, 1).
  RGBA(r: 0.0'f32, g: 1.0'f32, b: 1.0'f32, a: 1.0'f32)

func magenta*(T: type RGBA): RGBA {.inline.} =
  ## Opaque magenta (1, 0, 1, 1).
  RGBA(r: 1.0'f32, g: 0.0'f32, b: 1.0'f32, a: 1.0'f32)

func fromBytes*(r, g, b: uint8): RGB {.inline.} =
  ## Converts 8-bit RGB channels to normalized values. `255` maps to `1.0`.
  RGB(r: float32(r) / 255.0'f32, g: float32(g) / 255.0'f32, b: float32(b) / 255.0'f32)

func fromBytes*(r, g, b, a: uint8): RGBA {.inline.} =
  ## Converts 8-bit RGBA channels to normalized values. `255` maps to `1.0`.
  RGBA(
    r: float32(r) / 255.0'f32,
    g: float32(g) / 255.0'f32,
    b: float32(b) / 255.0'f32,
    a: float32(a) / 255.0'f32
  )

func toBytes*(c: RGB): tuple[r, g, b: uint8] {.inline.} =
  ## Converts normalized RGB channels to rounded 8-bit channels.
  (toByte(c.r), toByte(c.g), toByte(c.b))

func toBytes*(c: RGBA): tuple[r, g, b, a: uint8] {.inline.} =
  ## Converts normalized RGBA channels to rounded 8-bit channels.
  (toByte(c.r), toByte(c.g), toByte(c.b), toByte(c.a))

func rgb*(c: RGBA): RGB {.inline.} =
  ## Drops alpha and returns the RGB channels.
  RGB(r: c.r, g: c.g, b: c.b)

func withAlpha*(c: RGB, a: float32): RGBA {.inline.} =
  ## Adds an alpha channel to an RGB value.
  RGBA(r: c.r, g: c.g, b: c.b, a: a)

func clamp01*(c: RGB): RGB {.inline.} =
  ## Clamps all RGB channels to `[0, 1]`.
  RGB(r: clamp01Value(c.r), g: clamp01Value(c.g), b: clamp01Value(c.b))

func clamp01*(c: RGBA): RGBA {.inline.} =
  ## Clamps all RGBA channels to `[0, 1]`.
  RGBA(r: clamp01Value(c.r), g: clamp01Value(c.g), b: clamp01Value(c.b), a: clamp01Value(c.a))

func `==`*(a, b: RGB): bool {.inline.} =
  ## Compares RGB channels exactly.
  a.r == b.r and a.g == b.g and a.b == b.b

func `==`*(a, b: RGBA): bool {.inline.} =
  ## Compares RGBA channels exactly, including alpha.
  a.r == b.r and a.g == b.g and a.b == b.b and a.a == b.a

func `+`*(a, b: RGB): RGB {.inline.} =
  ## Adds corresponding RGB channels.
  RGB(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b)

func `+`*(a, b: RGBA): RGBA {.inline.} =
  ## Adds corresponding RGBA channels.
  RGBA(r: a.r + b.r, g: a.g + b.g, b: a.b + b.b, a: a.a + b.a)

func `-`*(a, b: RGB): RGB {.inline.} =
  ## Subtracts corresponding RGB channels.
  RGB(r: a.r - b.r, g: a.g - b.g, b: a.b - b.b)

func `-`*(a, b: RGBA): RGBA {.inline.} =
  ## Subtracts corresponding RGBA channels.
  RGBA(r: a.r - b.r, g: a.g - b.g, b: a.b - b.b, a: a.a - b.a)

func `*`*(c: RGB, s: float32): RGB {.inline.} =
  ## Scales every RGB channel by `s`.
  RGB(r: c.r * s, g: c.g * s, b: c.b * s)

func `*`*(s: float32, c: RGB): RGB {.inline.} =
  ## Scales every RGB channel by `s`.
  c * s

func `*`*(a, b: RGB): RGB {.inline.} =
  ## Multiplies RGB channels component by component.
  RGB(r: a.r * b.r, g: a.g * b.g, b: a.b * b.b)

func `*`*(c: RGBA, s: float32): RGBA {.inline.} =
  ## Scales every RGBA channel, including alpha, by `s`.
  RGBA(r: c.r * s, g: c.g * s, b: c.b * s, a: c.a * s)

func `*`*(s: float32, c: RGBA): RGBA {.inline.} =
  ## Scales every RGBA channel, including alpha, by `s`.
  c * s

func `*`*(a, b: RGBA): RGBA {.inline.} =
  ## Multiplies RGBA channels component by component.
  RGBA(r: a.r * b.r, g: a.g * b.g, b: a.b * b.b, a: a.a * b.a)

func `/`*(c: RGB, s: float32): RGB {.inline.} =
  ## Divides every channel by `s` directly: computing a reciprocal first would
  ## overflow for subnormal divisors and turn `x / x` into an infinity.
  RGB(r: c.r / s, g: c.g / s, b: c.b / s)

func `/`*(c: RGBA, s: float32): RGBA {.inline.} =
  ## Divides every channel, including alpha, by `s`.
  RGBA(r: c.r / s, g: c.g / s, b: c.b / s, a: c.a / s)

func `+=`*(a: var RGB, b: RGB) {.inline.} =
  ## Adds `b` to `a` in place.
  a.r += b.r
  a.g += b.g
  a.b += b.b

func `-=`*(a: var RGB, b: RGB) {.inline.} =
  ## Subtracts `b` from `a` in place.
  a.r -= b.r
  a.g -= b.g
  a.b -= b.b

func `*=`*(a: var RGB, s: float32) {.inline.} =
  ## Scales `a` in place by `s`.
  a.r *= s
  a.g *= s
  a.b *= s

func `*=`*(a: var RGB, b: RGB) {.inline.} =
  ## Multiplies RGB channels component by component in place.
  a.r *= b.r
  a.g *= b.g
  a.b *= b.b

func `/=`*(a: var RGB, s: float32) {.inline.} =
  ## Divides every RGB channel in place by `s`.
  a.r = a.r / s
  a.g = a.g / s
  a.b = a.b / s

func `+=`*(a: var RGBA, b: RGBA) {.inline.} =
  ## Adds `b` to `a` in place, including alpha.
  a.r += b.r
  a.g += b.g
  a.b += b.b
  a.a += b.a

func `-=`*(a: var RGBA, b: RGBA) {.inline.} =
  ## Subtracts `b` from `a` in place, including alpha.
  a.r -= b.r
  a.g -= b.g
  a.b -= b.b
  a.a -= b.a

func `*=`*(a: var RGBA, s: float32) {.inline.} =
  ## Scales every RGBA channel in place by `s`.
  a.r *= s
  a.g *= s
  a.b *= s
  a.a *= s

func `*=`*(a: var RGBA, b: RGBA) {.inline.} =
  ## Multiplies RGBA channels component by component in place.
  a.r *= b.r
  a.g *= b.g
  a.b *= b.b
  a.a *= b.a

func `/=`*(a: var RGBA, s: float32) {.inline.} =
  ## Divides every RGBA channel in place by `s`.
  a.r = a.r / s
  a.g = a.g / s
  a.b = a.b / s
  a.a = a.a / s

func lerp*(a, b: RGB, t: float32): RGB {.inline.} =
  ## Interpolates from `a` to `b`; `t` is not clamped.
  RGB(
    r: float32(float(a.r) + (float(b.r) - float(a.r)) * float(t)),
    g: float32(float(a.g) + (float(b.g) - float(a.g)) * float(t)),
    b: float32(float(a.b) + (float(b.b) - float(a.b)) * float(t))
  )

func lerp*(a, b: RGBA, t: float32): RGBA {.inline.} =
  ## Interpolates from `a` to `b`, alpha included; `t` is not clamped.
  RGBA(
    r: float32(float(a.r) + (float(b.r) - float(a.r)) * float(t)),
    g: float32(float(a.g) + (float(b.g) - float(a.g)) * float(t)),
    b: float32(float(a.b) + (float(b.b) - float(a.b)) * float(t)),
    a: float32(float(a.a) + (float(b.a) - float(a.a)) * float(t))
  )

func srgbToLinear(value: float32): float32 {.inline.} =
  ## Converts an sRGB color channel value to linear light.
  let channel = clamp01Value(value)
  if channel <= 0.04045'f32:
    channel / 12.92'f32
  else:
    pow((channel + 0.055'f32) / 1.055'f32, 2.4'f32)

func linearToSrgb(value: float32): float32 {.inline.} =
  ## Converts a linear light color channel value to sRGB.
  let channel = clamp01Value(value)
  if channel <= 0.0031308'f32:
    channel * 12.92'f32
  else:
    1.055'f32 * pow(channel, 1.0'f32 / 2.4'f32) - 0.055'f32

func toLinear*(c: RGB): RGB {.inline.} =
  ## Converts RGB from sRGB transfer values to linear light.
  RGB(r: srgbToLinear(c.r), g: srgbToLinear(c.g), b: srgbToLinear(c.b))

func toSRGB*(c: RGB): RGB {.inline.} =
  ## Converts linear-light RGB to sRGB transfer values.
  RGB(r: linearToSrgb(c.r), g: linearToSrgb(c.g), b: linearToSrgb(c.b))

func toLinear*(c: RGBA): RGBA {.inline.} =
  ## Converts the RGB channels from sRGB transfer values to linear light.
  RGBA(r: srgbToLinear(c.r), g: srgbToLinear(c.g), b: srgbToLinear(c.b), a: c.a)

func toSRGB*(c: RGBA): RGBA {.inline.} =
  ## Converts the RGB channels from linear light to sRGB transfer values.
  RGBA(r: linearToSrgb(c.r), g: linearToSrgb(c.g), b: linearToSrgb(c.b), a: c.a)

func parseHexDigit(ch: char): int {.inline, raises: [ValueError].} =
  ## Parses a single hexadecimal character into its integer value (0 to 15).
  case ch
  of '0'..'9':
    int(ch) - int('0')
  of 'a'..'f':
    int(ch) - int('a') + 10
  of 'A'..'F':
    int(ch) - int('A') + 10
  else:
    raise newException(ValueError, fmt"Invalid hexadecimal digit '{ch}'.")

func parseHexByteAt(s: string, index: int): uint8 {.inline, raises: [ValueError].} =
  ## Parses two hexadecimal characters at `index` into a uint8 byte.
  uint8((parseHexDigit(s[index]) shl 4) or parseHexDigit(s[index + 1]))

proc fromHexRGB*(hexStr: string): RGB {.raises: [ValueError].} =
  ## Parses six hexadecimal digits, with or without a leading `#`.
  var s = hexStr.strip()
  if s.len > 0 and s[0] == '#':
    s = if s.len == 1: "" else: s[1 .. ^1]
  if s.len != 6:
    raise newException(ValueError, fmt"RGB hex string must be 6 hex digits, got '{hexStr}'")
  fromBytes(parseHexByteAt(s, 0), parseHexByteAt(s, 2), parseHexByteAt(s, 4))

proc fromHexRGBA*(hexStr: string): RGBA {.raises: [ValueError].} =
  ## Parses eight hexadecimal digits, with or without a leading `#`.
  var s = hexStr.strip()
  if s.len > 0 and s[0] == '#':
    s = if s.len == 1: "" else: s[1 .. ^1]
  if s.len != 8:
    raise newException(ValueError, fmt"RGBA hex string must be 8 hex digits, got '{hexStr}'")
  fromBytes(parseHexByteAt(s, 0), parseHexByteAt(s, 2), parseHexByteAt(s, 4), parseHexByteAt(s, 6))

func toHex*(c: RGB): string =
  ## Formats RGB as six uppercase hexadecimal digits with a `#` prefix.
  let (r, g, b) = c.toBytes
  fmt"#{r:02X}{g:02X}{b:02X}"

func toHex*(c: RGBA): string =
  ## Formats RGBA as eight uppercase hexadecimal digits with a `#` prefix.
  let (r, g, b, a) = c.toBytes
  fmt"#{r:02X}{g:02X}{b:02X}{a:02X}"
