## Native host tests for the WebAssembly C ABI.
##
## The browser/Node smoke test needs Emscripten. This suite compiles the same procs
## with `-d:pmxforgeWasmHostTest` so the limit, diagnostic, and reentrancy contracts
## are checked on every `nimble test` run.

import std/[strutils, unittest]
import pmxforge
import pmxforge/wasm/bridge
import ./support

proc statusOf(bytes: seq[byte]): cint =
  ## Feeds `bytes` to `pmxforge_validate` and returns the status code.
  if bytes.len == 0:
    return pmxforge_validate(nil, 0)
  pmxforge_validate(unsafeAddr bytes[0], cint(bytes.len))

proc roundtripOf(bytes: seq[byte]): seq[byte] =
  ## Feeds `bytes` to `pmxforge_roundtrip` and copies the returned buffer.
  var outLength: cint = 0
  let output =
    if bytes.len == 0:
      pmxforge_roundtrip(nil, 0, addr outLength)
    else:
      pmxforge_roundtrip(unsafeAddr bytes[0], cint(bytes.len), addr outLength)
  if output == nil:
    raise newException(ValueError, $pmxforge_last_message())
  result = newSeq[byte](int(outLength))
  if outLength > 0:
    copyMem(addr result[0], output, int(outLength))
  pmxforge_free(output)

suite "wasm ABI host":
  teardown:
    pmxforge_set_limits(250_000, 64 * 1024 * 1024, 65_536, 64 * 1024 * 1024)

  test "a valid model validates and round-trips":
    let bytes = writePmx(sampleModel())
    check statusOf(bytes) == 0
    check roundtripOf(bytes) == bytes

  test "a model that parses but fails validation reports status 4":
    let bytes = writePmx(damagedModel(), mode = pwmLenient)
    check statusOf(bytes) == 4
    check $pmxforge_last_message() != "ok"

  test "a corrupt header reports status 1":
    var bytes = writePmx(sampleModel())
    bytes[1] = 0
    check statusOf(bytes) == 1

  test "set_limits refuses a zero element budget":
    pmxforge_set_limits(0, 1024, 1024, 1024)
    check pmxforge_last_status() == 5

  test "set_limits shrinks the source budget below the safe 64 MiB floor":
    pmxforge_set_limits(4_000_000, 8, 1024, 1024)
    check pmxforge_last_status() == 0
    let bytes = writePmx(sampleModel())
    check bytes.len > 8
    check statusOf(bytes) == 3
    check "maxSourceBytes" in $pmxforge_last_message()

  test "a failed call still clears the busy latch":
    var bytes = writePmx(sampleModel())
    bytes[1] = 0
    check statusOf(bytes) == 1
    pmxforge_set_limits(4_000_000, 8, 1024, 1024)
    check pmxforge_last_status() == 0

  test "a nested ABI call is refused and does not change the budget":
    let bytes = writePmx(sampleModel())
    check statusOf(bytes) == 0
    let previous = pmxforge_last_status()
    withBusyForTest(proc () =
      pmxforge_set_limits(1, 8, 8, 8)
      check pmxforge_last_status() == previous)
    check statusOf(bytes) == 0

  test "set_limits carries the text budget into validate and roundtrip":
    ## The reader used to honor `maxStringBytes` while `validate` and the writer kept the
    ## 64 KiB default, so a host that raised the limit could parse a model it could not
    ## validate or re-serialize.
    let bigName = repeat('a', 70_000)
    let model = newPmxModel(nameJA = bigName)
    let bytes = writePmx(model, UnboundedPmxWriteLimits, maxStringBytes = 200_000)
    check statusOf(bytes) == 3
    pmxforge_set_limits(250_000, cint(bytes.len + 1024), 200_000, 64 * 1024 * 1024)
    check statusOf(bytes) == 0
    check roundtripOf(bytes).len == bytes.len

  test "roundtrip refuses a nil outLength without taking the busy latch":
    let bytes = writePmx(sampleModel())
    check pmxforge_roundtrip(unsafeAddr bytes[0], cint(bytes.len), nil) == nil
    check pmxforge_last_status() == 5
    pmxforge_set_limits(250_000, 64 * 1024 * 1024, 65_536, 64 * 1024 * 1024)
    check pmxforge_last_status() == 0
