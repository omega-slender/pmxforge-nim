## Byte and stream paths for hosts without a filesystem.
##
## Provides byte and stream round-trip coverage for hosts that own storage. Compile it with
## `-d:pmxforgeNoFileSystem`, or to JavaScript with `nim js`.

import std/streams
import std/unittest
import pmxforge
import ./support

suite "buffer paths":
  test "a model round trips through bytes":
    ## Re-serializing what was just parsed must reproduce the same bytes.
    let model = sampleModel()
    let bytes = writePmx(model)
    check bytes.len > 0
    let reloaded = readPmx(bytes)
    check writePmx(reloaded) == bytes
    when not defined(js):
      check samePmxContent(model, reloaded)

  test "the byte overloads honour both limits":
    ## Resource limits work the same way without a filesystem.
    let bytes = modelBytes(sampleModel())
    var readLimits = DefaultPmxReadLimits
    readLimits.maxSourceBytes = 8
    expect PmxLimitError:
      discard readPmx(bytes, readLimits)
    expect PmxLimitError:
      discard writePmx(sampleModel(), PmxWriteLimits(maxOutputBytes: 16))

  test "an empty buffer is still refused":
    ## There is nothing to parse, and the caller hears about it.
    let empty: seq[byte] = @[]
    expect PmxFormatError:
      discard readPmx(empty)

suite "float32 wire range":
  test "a value that overflows float32 is rejected on every backend":
    ## JavaScript keeps the double-range product finite until `setFloat32` encodes it; validation has
    ## to apply the same rounding the wire writer does.
    let model = sampleModel()
    var left = 1.0e30'f32
    var right = 1.0e30'f32
    model.vertices[0].position.x = left * right
    check not model.isValid()
    check not isValid(model, strict = false)
    expect ValueError:
      discard writePmx(model)

  test "an IK angle whose degree conversion overflows is rejected":
    ## JavaScript keeps the scaled value in double range, so the reader has to apply the
    ## same float32 representability rule on every backend.
    expect PmxFormatError:
      discard readPmx(overflowingIkAnglePmx())

suite "stream paths":
  test "a string stream carries the same bytes":
    ## Hosts that only offer streams can use the stream overload.
    let model = sampleModel()
    let bytes = writePmx(model)
    let target = newStringStream()
    writePmx(model, target)
    target.setPosition(0)
    let reloaded = readPmx(target)
    check writePmx(reloaded) == bytes
    when not defined(js):
      check samePmxContent(model, reloaded)

  test "reading from the wrong offset fails cleanly":
    ## A stream that starts mid-header is a format error, not a crash.
    let target = newStringStream()
    writePmx(sampleModel(), target)
    target.setPosition(2)
    expect PmxFormatError:
      discard readPmx(target)
