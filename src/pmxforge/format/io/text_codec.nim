## PMX text codec.
##
## Provides UTF-8 validation and UTF-16LE conversion for the text fields, which PMX stores in either encoding.

import strformat

const
  ReplacementMax = 0x10FFFF'i32 ## Maximum valid Unicode code point.
  HighSurrogateMin = 0xD800'i32 ## Start of UTF-16 high surrogate range.
  HighSurrogateMax = 0xDBFF'i32 ## End of UTF-16 high surrogate range.
  LowSurrogateMin = 0xDC00'i32 ## Start of UTF-16 low surrogate range.
  LowSurrogateMax = 0xDFFF'i32 ## End of UTF-16 low surrogate range.

proc appendByte(result: var string, b: int32) {.inline.} =
  ## Appends one byte to the string `result`.
  result.add(char(b and 0xFF))

proc appendUtf8(result: var string, rune: int32) {.raises: [ValueError].} =
  ## Encodes a Unicode scalar value as UTF-8 bytes and appends to `result`.
  if rune < 0 or rune > ReplacementMax:
    raise newException(ValueError, fmt"Unicode scalar U+{rune:X} is out of range.")
  if rune in HighSurrogateMin..LowSurrogateMax:
    raise newException(ValueError, fmt"Unicode scalar U+{rune:X} is a surrogate.")

  if rune <= 0x7F:
    result.appendByte(rune)
  elif rune <= 0x7FF:
    result.appendByte(0xC0 or (rune shr 6))
    result.appendByte(0x80 or (rune and 0x3F))
  elif rune <= 0xFFFF:
    result.appendByte(0xE0 or (rune shr 12))
    result.appendByte(0x80 or ((rune shr 6) and 0x3F))
    result.appendByte(0x80 or (rune and 0x3F))
  else:
    result.appendByte(0xF0 or (rune shr 18))
    result.appendByte(0x80 or ((rune shr 12) and 0x3F))
    result.appendByte(0x80 or ((rune shr 6) and 0x3F))
    result.appendByte(0x80 or (rune and 0x3F))

proc readContByte(s: string, i: var int, context: string): int32 {.raises: [ValueError].} =
  ## Reads and validates a UTF-8 continuation byte (0x80..0xBF).
  if i >= s.len:
    raise newException(ValueError, fmt"{context} ends inside a UTF-8 sequence.")
  result = int32(ord(s[i]))
  if (result and 0xC0) != 0x80:
    raise newException(ValueError, fmt"{context} has invalid UTF-8 continuation byte 0x{result:02X}.")
  inc i
  result = result and 0x3F

iterator utf8Codepoints*(s: string): int32 {.raises: [ValueError].} =
  ## Iterates over Unicode codepoints in a UTF-8 string, validating sequences.
  var i = 0
  while i < s.len:
    let b0 = int32(ord(s[i]))
    inc i
    var rune: int32
    var minRune: int32

    if b0 <= 0x7F:
      rune = b0
      minRune = 0
    elif b0 in 0xC2'i32..0xDF'i32:
      rune = ((b0 and 0x1F) shl 6) or readContByte(s, i, "String")
      minRune = 0x80
    elif b0 in 0xE0'i32..0xEF'i32:
      rune = ((b0 and 0x0F) shl 12) or (readContByte(s, i, "String") shl 6) or readContByte(s, i, "String")
      minRune = 0x800
    elif b0 in 0xF0'i32..0xF4'i32:
      rune =
        ((b0 and 0x07) shl 18) or (readContByte(s, i, "String") shl 12) or
        (readContByte(s, i, "String") shl 6) or readContByte(s, i, "String")
      minRune = 0x10000
    else:
      raise newException(ValueError, fmt"String has invalid UTF-8 leading byte 0x{b0:02X}.")

    if rune < minRune:
      raise newException(ValueError, fmt"String has overlong UTF-8 sequence for U+{rune:X}.")
    if rune in HighSurrogateMin..LowSurrogateMax:
      raise newException(ValueError, fmt"String contains invalid UTF-8 surrogate U+{rune:X}.")
    if rune > ReplacementMax:
      raise newException(ValueError, fmt"String contains Unicode scalar U+{rune:X} outside range.")
    yield rune

proc validateUtf8*(s: string) {.raises: [ValueError].} =
  ## Validates that `s` contains well-formed UTF-8 without allocating.
  for _ in utf8Codepoints(s):
    discard

proc decodeUtf16Le*(bytes: string): string {.raises: [ValueError].} =
  ## Decodes UTF-16LE bytes into a UTF-8 Nim string.
  if (bytes.len mod 2) != 0:
    raise newException(ValueError, fmt"UTF-16LE byte length must be even, got {bytes.len}.")

  var i = 0
  result = newStringOfCap(bytes.len)
  while i < bytes.len:
    let unit = int32(ord(bytes[i])) or (int32(ord(bytes[i + 1])) shl 8)
    i += 2

    if unit in HighSurrogateMin..HighSurrogateMax:
      if i >= bytes.len:
        raise newException(ValueError, fmt"UTF-16LE high surrogate 0x{unit:04X} has no low surrogate.")
      let low = int32(ord(bytes[i])) or (int32(ord(bytes[i + 1])) shl 8)
      i += 2
      if low notin LowSurrogateMin..LowSurrogateMax:
        raise newException(ValueError, fmt"UTF-16LE high surrogate 0x{unit:04X} is followed by 0x{low:04X}.")
      let rune = 0x10000'i32 + (((unit - HighSurrogateMin) shl 10) or (low - LowSurrogateMin))
      result.appendUtf8(rune)
    elif unit in LowSurrogateMin..LowSurrogateMax:
      raise newException(ValueError, fmt"UTF-16LE low surrogate 0x{unit:04X} has no high surrogate.")
    else:
      result.appendUtf8(unit)

proc utf16LeByteLength*(text: string, maxBytes = high(int)): int {.raises: [ValueError].} =
  ## Returns the byte length of `text` when encoded as UTF-16LE.
  if maxBytes < 0:
    raise newException(ValueError, "UTF-16LE byte limit must not be negative.")
  for rune in utf8Codepoints(text):
    let runeBytes = if rune <= 0xFFFF: 2 else: 4
    if result > maxBytes - runeBytes:
      raise newException(ValueError, fmt"Encoded UTF-16LE string exceeds the limit of {maxBytes} bytes.")
    result += runeBytes

proc encodeUtf16Le*(text: string, maxBytes = high(int)): string {.raises: [ValueError].} =
  ## Encodes a UTF-8 string to UTF-16LE bytes.
  let encodedLength = utf16LeByteLength(text, maxBytes)

  result = newStringOfCap(encodedLength)
  for rune in utf8Codepoints(text):
    if rune <= 0xFFFF:
      result.appendByte(rune)
      result.appendByte(rune shr 8)
    else:
      let v = rune - 0x10000
      let high = HighSurrogateMin + (v shr 10)
      let low = LowSurrogateMin + (v and 0x3FF)
      result.appendByte(high)
      result.appendByte(high shr 8)
      result.appendByte(low)
      result.appendByte(low shr 8)
