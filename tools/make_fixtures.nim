## Writes the independent PMX fixtures used by `tests/test_fixtures.nim`.
##
## The bytes are assembled here with primitive writes, without importing `pmxforge`, so the tests read
## files that were not produced by the library's own writer. The binary fixtures are committed; run this
## tool only when they need to change.

import std/[os, strformat]

const FixtureDir = "tests/fixtures"

proc addU8(data: var seq[byte], value: int) =
  ## Appends one unsigned byte.
  data.add(byte(value and 0xFF))

proc addI8(data: var seq[byte], value: int) =
  ## Appends one byte from a signed value using two's complement.
  data.add(byte(value and 0xFF))

proc addI32(data: var seq[byte], value: int32) =
  ## Appends a little-endian signed 32-bit value.
  let bits = cast[uint32](value)
  data.add(byte(bits and 0xFF))
  data.add(byte((bits shr 8) and 0xFF))
  data.add(byte((bits shr 16) and 0xFF))
  data.add(byte(bits shr 24))

proc addF32(data: var seq[byte], value: float32) =
  ## Appends a little-endian IEEE-754 float32.
  data.addI32(cast[int32](cast[uint32](value)))

proc addText(data: var seq[byte], value: string) =
  ## Appends a length-prefixed UTF-8 string.
  data.addI32(int32(value.len))
  for ch in value:
    data.add(byte(ch))

proc header(data: var seq[byte], version: float32, additionalUv: int) =
  ## Writes the magic, globals, encoding, UV count, and six one-byte index widths.
  for ch in "PMX ":
    data.add(byte(ch))
  data.addF32(version)
  data.addU8(8)
  data.addU8(1)
  data.addU8(additionalUv)
  for _ in 0 ..< 6:
    data.addU8(1)

proc subtexture20(): seq[byte] =
  ## PMX 2.0 with `sbmSubTexture` and one additional UV channel.
  result.header(2.0'f32, 1)
  result.addText("subtex")
  result.addText("subtex")
  result.addText("")
  result.addText("")

  result.addI32(1)
  result.addF32(0.0)
  result.addF32(1.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(1.0)
  result.addF32(0.0)
  result.addF32(0.25)
  result.addF32(0.75)
  result.addF32(0.1)
  result.addF32(0.2)
  result.addF32(0.3)
  result.addF32(0.4)
  result.addU8(0)
  result.addI8(-1)
  result.addF32(1.0)

  result.addI32(3)
  result.addU8(0)
  result.addU8(0)
  result.addU8(0)
  result.addI32(1)
  result.addText("tex/sub.png")

  result.addI32(1)
  result.addText("mat")
  result.addText("mat")
  result.addF32(1.0)
  result.addF32(1.0)
  result.addF32(1.0)
  result.addF32(1.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.5)
  result.addF32(0.5)
  result.addF32(0.5)
  result.addU8(0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(1.0)
  result.addF32(1.0)
  result.addI8(-1)
  result.addI8(-1)
  result.addU8(3)
  result.addU8(1)
  result.addU8(0)
  result.addText("")
  result.addI32(3)

  for _ in 0 ..< 4:
    result.addI32(0)
  result.addI32(0)

proc conetwist21(): seq[byte] =
  ## PMX 2.1 with one ConeTwist joint whose limit fields are repurposed.
  result.header(2.1'f32, 0)
  result.addText("cone")
  result.addText("cone")
  result.addText("")
  result.addText("")

  for _ in 0 ..< 6:
    result.addI32(0)
  result.addI32(0)
  result.addI32(0)

  result.addI32(1)
  result.addText("cone joint")
  result.addText("cone joint")
  result.addU8(3)
  result.addI8(-1)
  result.addI8(-1)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(1.5)
  result.addF32(2.5)
  result.addF32(1.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(3.0)
  result.addF32(0.5)
  result.addF32(0.25)
  result.addF32(0.75)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)
  result.addF32(0.0)

  result.addI32(0)

proc flipSelf21(): seq[byte] =
  ## PMX 2.1 with a flip morph that references its own index.
  result.header(2.1'f32, 0)
  result.addText("flip")
  result.addText("flip")
  result.addText("")
  result.addText("")

  for _ in 0 ..< 5:
    result.addI32(0)

  result.addI32(1)
  result.addText("flip")
  result.addText("flip")
  result.addU8(4)
  result.addU8(9)
  result.addI32(1)
  result.addI8(0)
  result.addF32(0.5)

  result.addI32(0)
  result.addI32(0)
  result.addI32(0)
  result.addI32(0)

proc writeFixture(name: string, data: seq[byte]) =
  ## Writes one fixture and reports its size.
  let path = FixtureDir / name
  var raw = newString(data.len)
  for i, value in data:
    raw[i] = char(value)
  writeFile(path, raw)
  echo fmt"wrote {path} ({data.len} bytes)"

proc main() =
  createDir(FixtureDir)
  writeFixture("pmx20-subtexture.pmx", subtexture20())
  writeFixture("pmx21-conetwist.pmx", conetwist21())
  writeFixture("pmx21-flip-self.pmx", flipSelf21())

when isMainModule:
  main()
