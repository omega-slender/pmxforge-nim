## Binary PMX serializer.
##
## Provides `writePmx` and `PmxWriteLimits` to serialize a model to a path, a stream, or a byte sequence in
## strict, lenient, or repair mode.

import streams
import math
import strformat

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  import os
  import std/tempfiles
  import std/syncio

  proc c_fflush(file: File): cint {.importc: "fflush", header: "<stdio.h>", cdecl.}
  proc c_ferror(file: File): cint {.importc: "ferror", header: "<stdio.h>", cdecl.}
  proc c_clearerr(file: File) {.importc: "clearerr", header: "<stdio.h>", cdecl.}

  proc checkedFlushFile(file: File) {.raises: [IOError].} =
    ## Flushes the stdio buffer and raises when the flush fails.
    if file == nil:
      raise newException(IOError, "Cannot flush a closed file stream.")
    if c_ferror(file) != 0:
      raise newException(IOError, "The PMX output stream is already in an error state.")
    if c_fflush(file) != 0 or c_ferror(file) != 0:
      raise newException(IOError, "Cannot flush the PMX output stream to disk.")

  when defined(windows):
    import std/winlean
    import std/widestrs
    proc replaceFileW(
      replacedFileName,
      replacementFileName,
      backupFileName: WideCString,
      replaceFlags: winlean.DWORD,
      exclude,
      reserved: pointer
    ): winlean.WINBOOL {. stdcall, dynlib: "kernel32", importc: "ReplaceFileW", sideEffect.}
    proc setEndOfFile(
      hFile: winlean.Handle
    ): winlean.WINBOOL {. stdcall, dynlib: "kernel32", importc: "SetEndOfFile", sideEffect.}
  elif defined(posix):
    import std/posix

  when defined(linux) or defined(macosx) or defined(freebsd) or defined(dragonfly) or defined(netbsd):
    import ./file_metadata

import ../model
import ../errors
import ../limits
import ../validation
import ./binary
import ../internal/preconditions
import ../internal/copy_helpers

type ByteSinkStream = ref object of StreamObj ## Append-only binary sink stream.
  maxBytes: int64 ## Maximum allowed output size in bytes.
  data: seq[byte] ## Backing storage; `len` is the allocated capacity, not the payload size.
  count: int ## Bytes actually written into `data`.

const SinkInitialCapacity = 64 * 1024 ## First allocation for the in-memory output sink.

type
  PmxWriteLimits* = object ## Resource limits for serializing PMX data.
    maxOutputBytes*: int64 ## Maximum allowed size of serialized output in bytes.
    maxStringBytes*: int ## Maximum text field size; zero means `MaxStringBytes`.

  PmxWriteMode* = enum ## Serialization validation and repair mode.
    pwmStrict ## Enforce all PMX semantic invariants (default).
    pwmLenient ## Write as-is if wire-safe, preserving dangling references.
    pwmRepair ## Automatically repair a copy before writing.

const
  SafePmxWriteLimits* = PmxWriteLimits(
    maxOutputBytes: 64 * 1024 * 1024,
    maxStringBytes: MaxStringBytes
  ) ## Default output budget for untrusted models (64 MB).

  DesktopPmxWriteLimits* = PmxWriteLimits(
    maxOutputBytes: 256 * 1024 * 1024,
    maxStringBytes: MaxStringBytes
  ) ## Standard budget for desktop models (256 MB).

  TrustedLargePmxWriteLimits* = PmxWriteLimits(
    maxOutputBytes: 1024 * 1024 * 1024,
    maxStringBytes: MaxStringBytes
  ) ## High budget for large trusted models (1 GB).

  UnboundedPmxWriteLimits* = PmxWriteLimits(
    maxOutputBytes: high(int64),
    maxStringBytes: MaxStringBytes
  ) ## No output size limit.

type PmxWriteLimitIoError = object of IOError ## Internal error when output exceeds write limits.

proc validateWriteLimits(limits: PmxWriteLimits) {.raises: [ValueError].} =
  ## Validates that write limits are within their allowed ranges.
  if limits.maxOutputBytes < 0:
    raise newException(ValueError, "maxOutputBytes must be non-negative.")
  if limits.maxStringBytes < 0 or int64(limits.maxStringBytes) > int64(MaxPmxStringBytes):
    raise newException(
      ValueError,
      fmt"maxStringBytes must be in [0, {MaxPmxStringBytes}], got {limits.maxStringBytes}.")

proc effectiveStringLimit(limits: PmxWriteLimits, requested: int): int {.raises: [ValueError].} =
  ## Resolves the per-call override: a negative `requested` uses the limits object, and a
  ## zero `maxStringBytes` uses the library default.
  result =
    if requested >= 0:
      requested
    elif limits.maxStringBytes > 0:
      limits.maxStringBytes
    else:
      MaxStringBytes
  if result < 0 or int64(result) > int64(MaxPmxStringBytes):
    raise newException(
      ValueError, fmt"String byte limit {result} is outside [0, {MaxPmxStringBytes}].")

proc byteSinkWrite(s: Stream, buffer: pointer, bufferLength: int) {.nimcall, raises: [IOError], gcsafe.} =
  ## Appends data to the byte sink stream buffer up to the configured limit.
  if bufferLength < 0:
    raise newException(IOError, "Negative binary sink write length.")
  if bufferLength == 0:
    return
  let sink = ByteSinkStream(s)
  if int64(bufferLength) > sink.maxBytes - int64(sink.count):
    raise newException(
      PmxWriteLimitIoError, fmt"PMX output exceeds the configured limit of {sink.maxBytes} bytes.")
  if sink.count > high(int) - bufferLength:
    raise newException(IOError, "Binary output exceeds addressable memory.")
  let needed = sink.count + bufferLength
  if needed > sink.data.len:
    var newCapacity = max(SinkInitialCapacity, sink.data.len)
    while newCapacity < needed:
      if newCapacity > high(int) div 2:
        newCapacity = needed
        break
      newCapacity *= 2
    sink.data.setLen(newCapacity)
  when defined(js):
    let source = cast[ptr string](buffer)[]
    if source.len != bufferLength:
      raise newException(
        IOError,
        fmt"Binary sink received a {source.len}-byte buffer for a {bufferLength}-byte write.")
    for i in 0 ..< bufferLength:
      sink.data[sink.count + i] = byte(ord(source[i]))
  else:
    copyMem(addr sink.data[sink.count], buffer, bufferLength)
  sink.count = needed

proc byteSinkPosition(s: Stream): int {.nimcall, raises: [], gcsafe.} =
  ## Returns how many bytes the sink has written.
  ByteSinkStream(s).count

proc finish(sink: ByteSinkStream): seq[byte] =
  ## Trims the backing storage to the payload and hands it over.
  sink.data.setLen(sink.count)
  result = sink.data

proc newByteSinkStream(maxBytes: int64): ByteSinkStream =
  ## Creates an append-only in-memory byte sink with a byte limit.
  new(result)
  result.maxBytes = maxBytes
  result.writeDataImpl = byteSinkWrite
  result.getPositionImpl = byteSinkPosition

proc writeStagedBytes(stream: Stream, data: seq[byte]) {.raises: [IOError, OSError].} =
  ## Writes the staged bytes to the destination stream.
  if data.len == 0:
    return
  when defined(js):
    var raw = newString(data.len)
    for i, value in data:
      raw[i] = char(value)
    stream.write(raw)
  else:
    stream.writeData(unsafeAddr data[0], data.len)

when not (defined(js) or defined(pmxforgeNoFileSystem)):
  type
    FileStreamFileViewObj = object of Stream
      ## Layout copy of `FileStreamObj`, whose file handle is private.
      f: File
    FileStreamFileView = ref FileStreamFileViewObj

  when sizeof(FileStreamObj) != sizeof(FileStreamFileViewObj):
    {.error: "std/streams FileStream layout changed; update FileStreamFileViewObj.".}

  proc fileStreamFile(stream: Stream): File =
    ## Extracts the `File` handle from a `FileStream` through a checked layout view.
    if stream.isNil or not (stream of FileStream):
      raise newException(IOError, "Cannot truncate a closed file stream.")
    result = cast[FileStreamFileView](stream).f
    if result == nil:
      raise newException(IOError, "Cannot truncate a closed file stream.")
    try:
      if getFilePos(result) != int64(stream.getPosition()):
        raise newException(
          IOError,
          "FileStream handle does not match the stream cursor; refusing to truncate.")
    except IOError:
      raise
    except CatchableError as exc:
      raise newException(IOError, "Cannot inspect the FileStream handle: " & exc.msg)

  proc truncateOpenFile(file: File, length: int64) {.raises: [IOError].} =
    ## Truncates an open file to the specified byte length.
    if file == nil:
      raise newException(IOError, "Cannot truncate a closed file stream.")
    if length < 0:
      raise newException(IOError, "Cannot truncate a file stream to a negative length.")
    when defined(windows):
      setFilePos(file, length)
      if setEndOfFile(winlean.Handle(getOsFileHandle(file))) == 0:
        raise newException(IOError, "Cannot truncate the destination file stream.")
    elif defined(posix):
      if posix.ftruncate(cint(getOsFileHandle(file)), Off(length)) != 0:
        raise newException(IOError, "Cannot truncate the destination file stream.")
    else:
      raise newException(IOError, "Cannot truncate the destination file stream on this target.")

  proc truncateFileStream(stream: Stream, length: int64) {.raises: [IOError].} =
    ## Truncates the file, raising instead of leaving old tail bytes.
    if not (stream of FileStream):
      return
    truncateOpenFile(fileStreamFile(stream), length)

  type
    FileSnapshot = object ## Original prefix of a FileStream, captured for rollback.
      available: bool ## True when the original bytes could be read.
      length: int64 ## Original file length in bytes.
      bytes: seq[byte] ## Original content from offset zero, up to the overwritten prefix.

  proc takeFileSnapshot(stream: Stream, maxBytes: int): FileSnapshot {.raises: [IOError].} =
    ## Saves the destination bytes a write can overwrite, so a failed commit can put them
    ## back.
    let file = fileStreamFile(stream)
    if file == nil:
      return
    try:
      result.length = getFileSize(file)
    except CatchableError:
      return
    if result.length <= 0:
      result.available = true
      return
    let count = int(min(int64(maxBytes), result.length))
    try:
      setFilePos(file, 0)
      result.bytes = newSeq[byte](count)
      let read = readBuffer(file, addr result.bytes[0], count)
      if read == count:
        result.available = true
      else:
        result.bytes.setLen(0)
      setFilePos(file, 0)
    except CatchableError:
      result.available = false
      result.bytes.setLen(0)
      try:
        setFilePos(file, 0)
      except CatchableError:
        discard

  proc restoreFileSnapshot(stream: Stream, snapshot: FileSnapshot) {.raises: [IOError].} =
    ## Rewrites the captured prefix and restores the original length.
    let file = fileStreamFile(stream)
    c_clearerr(file)
    setFilePos(file, 0)
    if snapshot.bytes.len > 0:
      let written = writeBuffer(file, unsafeAddr snapshot.bytes[0], snapshot.bytes.len)
      if written != snapshot.bytes.len:
        raise newException(IOError, "Short write while restoring the original file stream.")
    checkedFlushFile(file)
    truncateOpenFile(file, snapshot.length)
    setFilePos(file, 0)

proc writeStagedBytesTransactional(stream: Stream, data: seq[byte]) {.raises: [IOError, OSError].} =
  ## Commits staged bytes and rolls the destination back on failure.
  if data.len == 0:
    return

  let canGetPosition = stream.getPositionImpl != nil
  let canSetPosition = stream.setPositionImpl != nil
  let originalPosition = if canGetPosition: stream.getPosition() else: -1
  let isStringStream = stream of StringStream
  let originalStringData =
    if isStringStream: copyString(StringStream(stream).data) else: ""

  when not (defined(js) or defined(pmxforgeNoFileSystem)):
    var snapshot: FileSnapshot
    if originalPosition == 0 and canSetPosition and (stream of FileStream):
      snapshot = takeFileSnapshot(stream, data.len)

  template recoverDestination(): string =
    ## Restores the destination and returns "" on success or the recovery error message.
    block:
      var message = ""
      if isStringStream:
        let destination = StringStream(stream)
        destination.data = originalStringData
        if canSetPosition:
          try:
            destination.setPosition(originalPosition)
          except CatchableError as positionExc:
            message = positionExc.msg
      else:
        when not (defined(js) or defined(pmxforgeNoFileSystem)):
          if snapshot.available:
            try:
              restoreFileSnapshot(stream, snapshot)
            except CatchableError as recoveryExc:
              message = recoveryExc.msg
        if message.len == 0 and canSetPosition and originalPosition >= 0:
          try:
            stream.setPosition(originalPosition)
          except CatchableError as positionExc:
            message = positionExc.msg
      message

  try:
    writeStagedBytes(stream, data)
  except IOError as exc:
    let recoveryMessage = recoverDestination()
    if recoveryMessage.len > 0:
      raise newException(IOError, exc.msg & " Recovery also failed: " & recoveryMessage, exc)
    raise exc
  except OSError as exc:
    let recoveryMessage = recoverDestination()
    if recoveryMessage.len > 0:
      raise newException(IOError, exc.msg & " Recovery also failed: " & recoveryMessage, exc)
    raise exc

  if isStringStream and originalPosition == 0:
    StringStream(stream).data.setLen(data.len)
  when not (defined(js) or defined(pmxforgeNoFileSystem)):
    if originalPosition == 0 and canSetPosition and (stream of FileStream):
      try:
        checkedFlushFile(fileStreamFile(stream))
        truncateFileStream(stream, int64(data.len))
      except IOError as exc:
        let recoveryMessage = recoverDestination()
        if recoveryMessage.len > 0:
          raise newException(IOError, exc.msg & " Recovery also failed: " & recoveryMessage, exc)
        raise exc

include ./writer_wire
include ./writer_fs

proc writePmx*(
  model: PmxModel,
  s: Stream,
  limits: PmxWriteLimits,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].} =
  ## Writes `model` to an open stream using the specified limits, with an optional
  ## `maxStringBytes` override.
  if s == nil:
    raise newException(ValueError, "Stream is nil.")
  validateWriteLimits(limits)
  let stringLimit = effectiveStringLimit(limits, maxStringBytes)
  let writeModel = prepareWriteModel(model, autoUpgradeVersion, mode, stringLimit)
  validateWritableModel(writeModel, mode, stringLimit)
  let staging = newByteSinkStream(limits.maxOutputBytes)
  try:
    writePmxValidated(writeModel, staging, mode, stringLimit)
  except PmxWriteLimitIoError as exc:
    raise newException(PmxLimitError, exc.msg, exc)
  writeStagedBytesTransactional(s, staging.finish())

proc writePmx*(
  model: PmxModel,
  s: Stream,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
) {.raises: [IOError, OSError, ValueError].} =
  ## Writes `model` to an open stream using SafePmxWriteLimits.
  if s == nil:
    raise newException(ValueError, "Stream is nil.")
  writePmx(model, s, SafePmxWriteLimits, autoUpgradeVersion, mode, maxStringBytes)

proc writePmx*(
  model: PmxModel,
  limits: PmxWriteLimits,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
): seq[byte] {.raises: [IOError, OSError, ValueError].} =
  ## Serializes `model` to a byte sequence using the specified limits.
  validateWriteLimits(limits)
  let stringLimit = effectiveStringLimit(limits, maxStringBytes)
  let writeModel = prepareWriteModel(model, autoUpgradeVersion, mode, stringLimit)
  validateWritableModel(writeModel, mode, stringLimit)
  let s = newByteSinkStream(limits.maxOutputBytes)
  try:
    writePmxValidated(writeModel, s, mode, stringLimit)
  except PmxWriteLimitIoError as exc:
    raise newException(PmxLimitError, exc.msg, exc)
  result = s.finish()

proc writePmx*(
  model: PmxModel,
  autoUpgradeVersion = true,
  mode = pwmStrict,
  maxStringBytes = -1
): seq[byte] {.raises: [IOError, OSError, ValueError].} =
  ## Serializes `model` to a byte sequence using SafePmxWriteLimits.
  writePmx(model, SafePmxWriteLimits, autoUpgradeVersion, mode, maxStringBytes)
