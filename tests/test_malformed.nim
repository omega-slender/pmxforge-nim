## Malformed and adversarial input.
##
## Provides checks that damaged buffers fail with the documented exception instead of crashing, breaking one
## thing at a time from a valid file.

import std/math
import std/unittest
import pmxforge
import ./support

const
  NameLengthOffset = 17 ## First byte of the model name length field.
  VersionOffset = 4 ## First byte of the header version float.

proc patternOf(value: float32): array[4, byte] =
  ## Returns the little-endian bytes a float32 occupies on the wire.
  var raw = value
  copyMem(addr result[0], addr raw, 4)

proc findBytes(data: seq[byte], pattern: openArray[byte]): int =
  ## Returns the first offset holding `pattern`, or -1 when it never appears.
  for start in 0 .. data.len - pattern.len:
    var matched = true
    for i in 0 ..< pattern.len:
      if data[start + i] != pattern[i]:
        matched = false
        break
    if matched:
      return start
  -1

suite "header fields":
  test "a wrong magic number is a format error":
    ## The four signature bytes decide whether this is PMX at all.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, 0, 0x51'u8))

  test "an unknown version float is a format error":
    ## Only 2.0 and 2.1 exist.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, VersionOffset, patternOf(3.0'f32)))

  test "a wrong globals size is a format error":
    ## Every PMX header declares exactly eight global fields.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, 8, 7'u8))

  test "an unknown text encoding is a format error":
    ## The encoding selects the decoder for every string in the file.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, 9, 2'u8))

  test "too many additional UV channels are a format error":
    ## The field is one byte, and the format allows four channels.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, 10, 5'u8))

  test "an invalid index width is a format error":
    ## Indices are one, two, or four bytes wide, nothing else.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, 11, 3'u8))

suite "string lengths":
  test "a length above the limit is refused before allocating":
    ## The whole point of the limit is to avoid the allocation.
    let data = modelBytes(sampleModel())
    expect PmxLimitError:
      discard readPmx(patched(data, NameLengthOffset, [0xFF'u8, 0xFF'u8, 0xFF'u8, 0x7F'u8]))

  test "a negative length is a format error":
    ## A signed length field below zero cannot describe a string.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, NameLengthOffset, [0xFF'u8, 0xFF'u8, 0xFF'u8, 0xFF'u8]))

  test "a length that runs past the buffer is truncation":
    ## The declared payload is larger than the file.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(patched(data, NameLengthOffset, [0x00'u8, 0x04'u8, 0x00'u8, 0x00'u8]))

suite "truncation":
  test "a short tail is reported as truncation":
    ## Section data that stops mid-field cannot be parsed.
    let data = modelBytes(sampleModel())
    expect PmxTruncatedError:
      discard readPmx(cropped(data, 4))

  test "losing a large part of the file is still a format error":
    ## The failure stays inside the documented exception family.
    let data = modelBytes(sampleModel())
    expect PmxFormatError:
      discard readPmx(cropped(data, 300))

  test "a one-byte file is a format error":
    ## Not even the signature fits.
    let stub: seq[byte] = @[0x50'u8]
    expect PmxFormatError:
      discard readPmx(stub)

  test "extra bytes after the last section are a format error":
    ## A larger file than the model describes is suspicious, so it is refused.
    let data = modelBytes(sampleModel())
    var extended = data
    extended.add(0x00'u8)
    expect PmxFormatError:
      discard readPmx(extended)

suite "non-finite floats":
  test "NaN in a vertex is refused by default":
    ## NaN has no meaning in a model and no accepted wire form.
    let data = modelBytes(tinyModel(Vector3(x: -1234.5'f32, y: 0.0'f32, z: 0.0'f32)))
    let offset = findBytes(data, patternOf(-1234.5'f32))
    check offset >= 0
    expect PmxFormatError:
      discard readPmx(patched(data, offset, patternOf(float32(NaN))))

  test "acceptNonFiniteFloats lets the value through":
    ## Callers that want to inspect a broken file can opt in.
    let data = modelBytes(tinyModel(Vector3(x: -1234.5'f32, y: 0.0'f32, z: 0.0'f32)))
    let offset = findBytes(data, patternOf(-1234.5'f32))
    var limits = DefaultPmxReadLimits
    limits.acceptNonFiniteFloats = true
    let reloaded = readPmx(patched(data, offset, patternOf(float32(NaN))), limits)
    check classify(reloaded.vertices[0].position.x) == fcNaN

  test "repair replaces the NaN it accepted":
    ## Repair exists precisely for models that arrived damaged.
    let data = modelBytes(tinyModel(Vector3(x: -1234.5'f32, y: 0.0'f32, z: 0.0'f32)))
    let offset = findBytes(data, patternOf(-1234.5'f32))
    var limits = DefaultPmxReadLimits
    limits.acceptNonFiniteFloats = true
    let reloaded = readPmx(patched(data, offset, patternOf(float32(NaN))), limits)
    reloaded.repair()
    check reloaded.vertices[0].position.x == 0.0'f32
    check reloaded.isValid()

suite "exception hierarchy":
  test "every failure can be caught as a ValueError":
    ## Callers that only care about failure keep a single handler.
    check PmxFormatError is ValueError
    check PmxTruncatedError is PmxFormatError
    check PmxLimitError is PmxFormatError

  test "a limit failure is still a format failure":
    ## The subtypes narrow the cause without changing the family.
    let data = modelBytes(sampleModel())
    var caught: ref ValueError
    try:
      discard readPmx(patched(data, NameLengthOffset, [0xFF'u8, 0xFF'u8, 0xFF'u8, 0x7F'u8]))
    except ValueError as exc:
      caught = exc
    check caught != nil
    check caught of PmxLimitError
    check caught of PmxFormatError

suite "IK angle representation":
  test "a degree conversion that overflows float32 is a format error":
    ## The wire stores radians; the model stores degrees. The largest finite float32
    ## radian value overflows the degree representation, so it cannot be accepted.
    expect PmxFormatError:
      discard readPmx(overflowingIkAnglePmx())

  test "acceptNonFiniteFloats keeps the documented escape hatch":
    ## Inspecting a broken file stays possible when the caller asks for it.
    var limits = DefaultPmxReadLimits
    limits.acceptNonFiniteFloats = true
    let reloaded = readPmx(overflowingIkAnglePmx(), limits)
    check classify(reloaded.bones[0].ik.limitAngle) in {fcInf, fcNegInf, fcNaN}
