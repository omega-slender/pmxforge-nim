## WebAssembly bridge.
##
## Provides the C ABI that a browser or a Node host calls, kept out of the `pmxforge` facade because it
## only makes sense in an Emscripten build.

import ../format/errors
import ../format/limits
import ../format/model
import ../format/validation
import ../format/io/reader
import ../format/io/writer

const
  PmxForgeWasmVersion = "1.0.0" ## Bridge version reported to the host.

type
  WasmStatus = enum ## Result codes shared with the JavaScript host.
    wsOk = 0 ## Success.
    wsFormat = 1 ## Malformed PMX data.
    wsTruncated = 2 ## The input ended before the model did.
    wsLimit = 3 ## A configured budget was exceeded.
    wsInvalid = 4 ## The model parsed but failed validation.
    wsInternal = 5 ## An unexpected internal failure.

const
  MinWasmAllocationBytes = 256 * 1024 ## Floor so a tiny source cap still parses the model object.

var
  lastStatus: cint = 0 ## Status recorded by the most recent public call.
  lastMessage: ptr UncheckedArray[char] = nil ## Last diagnostic message, owned by this module.
  emptyMessage: array[1, char] = ['\0'] ## Stable empty C string for a clean state.
  readLimits = SafePmxReadLimits ## Active read budget; the host may widen it.
  writeLimits = SafePmxWriteLimits ## Active write budget; the host may widen it.
  busy = false ## True while validate, roundtrip, or set_limits is running.

proc requireEmscripten() {.raises: [ValueError].} =
  ## Fails clearly when the bridge is used outside an Emscripten build.
  ## `-d:pmxforgeWasmHostTest` lets the native ABI suite exercise the same procs.
  when defined(emscripten) or defined(pmxforgeWasmHostTest):
    discard
  else:
    raise newException(
      ValueError,
      "the PMX Forge WebAssembly bridge only works in an Emscripten build; run 'nimble wasm' to produce it.")

proc clearLastMessage() =
  ## Releases the previous diagnostic message before a new one is stored.
  if lastMessage != nil:
    dealloc(lastMessage)
    lastMessage = nil

proc record(status: WasmStatus, message: string) =
  ## Stores the outcome for `pmxforge_last_status` and `pmxforge_last_message`.
  lastStatus = cint(status)
  clearLastMessage()
  if message.len == 0:
    return
  let buffer = cast[ptr UncheckedArray[char]](alloc(message.len + 1))
  if buffer == nil:
    return
  copyMem(addr buffer[0], unsafeAddr message[0], message.len)
  buffer[message.len] = '\0'
  lastMessage = buffer

proc enterCall(): bool =
  ## Marks the ABI busy. A nested call is refused without touching `lastStatus`,
  ## so the in-flight call still owns the diagnostic.
  if busy:
    return false
  busy = true
  true

proc leaveCall() =
  ## Clears the ABI busy flag after a public call returns.
  busy = false

proc bytesFromPointer(data: pointer; length: cint; label: string): seq[byte] =
  ## Copies a host buffer into a sequence, refusing a length that is negative or over the
  ## configured budget.
  if length < 0:
    raise newException(PmxFormatError, label & ": negative byte length " & $length & ".")
  if int64(length) > readLimits.maxSourceBytes:
    raise newException(PmxLimitError, label & ": input exceeds maxSourceBytes.")
  if length == 0:
    return @[]
  if data == nil:
    raise newException(PmxFormatError, label & ": nil data pointer with " & $length & " bytes.")
  result = newSeq[byte](int(length))
  copyMem(addr result[0], data, int(length))

proc parseStrict(bytes: seq[byte]): PmxModel =
  ## Reads and validates a model with the budget the reader was configured with.
  result = readPmx(bytes, readLimits)
  validate(result, readLimits.maxStringBytes)

proc pmxforge_set_limits*(
  maxElements: cint;
  maxSourceBytes: cint;
  maxStringBytes: cint;
  maxOutputBytes: cint
) {.exportc, cdecl.} =
  ## Sets the budgets the bridge uses. The host must not call this while another ABI call
  ## is running.
  if not enterCall():
    return
  try:
    requireEmscripten()
    if maxElements < 1 or int(maxElements) > MaxElementCount:
      record(wsInternal, "pmxforge_set_limits: maxElements must be in [1, " & $MaxElementCount & "].")
      return
    if maxSourceBytes < 0:
      record(wsInternal, "pmxforge_set_limits: maxSourceBytes must not be negative.")
      return
    if maxStringBytes < 0 or int64(maxStringBytes) > int64(MaxPmxStringBytes):
      record(wsInternal, "pmxforge_set_limits: maxStringBytes must be in [0, " & $MaxPmxStringBytes & "].")
      return
    if maxOutputBytes < 0:
      record(wsInternal, "pmxforge_set_limits: maxOutputBytes must not be negative.")
      return
    readLimits.maxElementCount = maxElements
    readLimits.maxSourceBytes = int64(maxSourceBytes)
    readLimits.maxStringBytes = maxStringBytes
    readLimits.maxTotalAllocationBytes = max(int64(maxSourceBytes), MinWasmAllocationBytes)
    writeLimits.maxOutputBytes = int64(maxOutputBytes)
    writeLimits.maxStringBytes = int(maxStringBytes)
    record(wsOk, "ok")
  finally:
    leaveCall()

proc pmxforge_version*(): cstring {.exportc, cdecl.} =
  ## Returns the bridge version; the host may display it or log it.
  result = cstring(PmxForgeWasmVersion)

proc pmxforge_validate*(data: pointer; length: cint): cint {.exportc, cdecl.} =
  ## Parses and strictly validates one PMX file held in host memory.
  if not enterCall():
    return cint(wsInternal)
  try:
    requireEmscripten()
    let model = parseStrict(bytesFromPointer(data, length, "pmxforge_validate"))
    discard model
    record(wsOk, "ok")
    cint(wsOk)
  except PmxLimitError as exc:
    record(wsLimit, exc.msg)
    cint(wsLimit)
  except PmxTruncatedError as exc:
    record(wsTruncated, exc.msg)
    cint(wsTruncated)
  except PmxFormatError as exc:
    record(wsFormat, exc.msg)
    cint(wsFormat)
  except ValueError as exc:
    record(wsInvalid, exc.msg)
    cint(wsInvalid)
  except IOError as exc:
    record(wsInternal, exc.msg)
    cint(wsInternal)
  except OSError as exc:
    record(wsInternal, exc.msg)
    cint(wsInternal)
  except CatchableError as exc:
    record(wsInternal, "internal error: " & exc.msg)
    cint(wsInternal)
  finally:
    leaveCall()

proc pmxforge_roundtrip*(
  data: pointer;
  length: cint;
  outLength: ptr cint
): pointer {.exportc, cdecl.} =
  ## Reads, validates and re-serializes a model; free the result with `pmxforge_free`.
  if outLength == nil:
    record(wsInternal, "pmxforge_roundtrip: outLength must not be nil.")
    return nil
  outLength[] = 0
  if not enterCall():
    return nil
  try:
    requireEmscripten()
    let model = parseStrict(bytesFromPointer(data, length, "pmxforge_roundtrip"))
    let output = writePmx(model, writeLimits)
    if output.len == 0:
      record(wsInternal, "pmxforge_roundtrip: the writer produced no bytes.")
      return nil
    if output.len > int(high(cint)):
      record(wsLimit, "pmxforge_roundtrip: output exceeds the 32-bit host length field.")
      return nil
    let buffer = alloc(output.len)
    if buffer == nil:
      record(wsInternal, "pmxforge_roundtrip: out of memory for " & $output.len & " bytes.")
      return nil
    copyMem(buffer, unsafeAddr output[0], output.len)
    outLength[] = cint(output.len)
    record(wsOk, "ok")
    buffer
  except PmxLimitError as exc:
    record(wsLimit, exc.msg)
    nil
  except PmxTruncatedError as exc:
    record(wsTruncated, exc.msg)
    nil
  except PmxFormatError as exc:
    record(wsFormat, exc.msg)
    nil
  except ValueError as exc:
    record(wsInvalid, exc.msg)
    nil
  except IOError as exc:
    record(wsInternal, exc.msg)
    nil
  except OSError as exc:
    record(wsInternal, exc.msg)
    nil
  except CatchableError as exc:
    record(wsInternal, "internal error: " & exc.msg)
    nil
  finally:
    leaveCall()

proc pmxforge_last_status*(): cint {.exportc, cdecl.} =
  ## Returns the status code of the most recent call.
  lastStatus

proc pmxforge_last_message*(): cstring {.exportc, cdecl.} =
  ## Returns the last diagnostic; valid until the next call.
  if lastMessage == nil:
    return cast[cstring](addr emptyMessage[0])
  cast[cstring](addr lastMessage[0])

proc pmxforge_free*(memory: pointer) {.exportc, cdecl.} =
  ## Releases a buffer returned by `pmxforge_roundtrip`.
  if memory != nil:
    dealloc(memory)

when defined(pmxforgeWasmHostTest):
  proc withBusyForTest*(body: proc()) =
    ## Holds the ABI busy flag so a nested call can be refused.
    if not enterCall():
      raise newException(ValueError, "the WebAssembly bridge is already busy.")
    try:
      body()
    finally:
      leaveCall()
