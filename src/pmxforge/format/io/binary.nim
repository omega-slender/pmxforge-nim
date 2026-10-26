## Buffered binary primitives.
##
## Provides `BinaryReader` and `BinaryWriter`, the little-endian layer that checks widths, text lengths, and
## floats before allocating or converting.

import streams
import strformat
import math
import ../errors
import ../limits
import ../internal/preconditions
import ./text_codec

const BinaryBufferBytes = 64 * 1024 ## Buffer size in bytes for binary stream I/O.

type
  BinaryReader* = object ## Buffered little-endian reader over a caller-owned stream.
    stream: Stream ## Underlying readable stream.
    buffer: string ## Internal byte buffer.
    bufferPosition: int ## Current read offset within `buffer`.
    consumedBytes: int64 ## Bytes handed to the caller, counted here instead of asking the stream.
    acceptNonFiniteFloats: bool ## Whether to permit NaN and infinite floats.

  BinaryWriter* = object ## Buffered little-endian writer over a caller-owned stream.
    stream: Stream ## Underlying writable stream.
    buffer: string ## Internal write buffer.

proc refill(reader: var BinaryReader): bool {.raises: [IOError, OSError].} =
  ## Refills the internal buffer from the underlying stream.
  reader.bufferPosition = 0
  when defined(js):
    reader.buffer = reader.stream.readStr(BinaryBufferBytes)
  else:
    reader.buffer.setLen(BinaryBufferBytes)
    let count = reader.stream.readDataStr(reader.buffer, 0 ..< BinaryBufferBytes)
    if count < 0 or count > BinaryBufferBytes:
      raise newException(IOError, "Stream returned an invalid binary read length.")
    reader.buffer.setLen(count)
  reader.buffer.len > 0

proc readRaw(reader: var BinaryReader, byteLength: int): string {.raises: [IOError, OSError, ValueError].} =
  ## Reads exact raw bytes from the buffered reader into a string.
  if byteLength < 0:
    raise newException(ValueError, "Binary read length must not be negative.")
  if byteLength == 0:
    return ""
  result = newString(byteLength)
  var written = 0
  while written < byteLength:
    if reader.bufferPosition >= reader.buffer.len and not reader.refill():
      raise newException(PmxTruncatedError, "Stream truncated while reading binary data.")
    let available = min(byteLength - written, reader.buffer.len - reader.bufferPosition)
    when defined(js):
      for i in 0 ..< available:
        result[written + i] = reader.buffer[reader.bufferPosition + i]
    else:
      copyMem(addr result[written], unsafeAddr reader.buffer[reader.bufferPosition], available)
    written += available
    reader.bufferPosition += available
    reader.consumedBytes += int64(available)

proc flush*(writer: var BinaryWriter) {.raises: [IOError, OSError].} =
  ## Flushes pending bytes without closing the underlying stream.
  if writer.buffer.len > 0:
    writer.stream.write(writer.buffer)
    writer.buffer.setLen(0)

proc appendByte(writer: var BinaryWriter, value: uint8) {.raises: [IOError, OSError].} =
  ## Appends a single byte to the output buffer, flushing if full.
  if writer.buffer.len == BinaryBufferBytes:
    writer.flush()
  writer.buffer.add(char(value))

when defined(js):
  proc float32FromBits(bits: uint32): float32
      {.importjs: "(function(v){var b=new ArrayBuffer(4),d=new DataView(b);d.setUint32(0,v,true);return d.getFloat32(0,true)})(#)".}

  proc float32ToBits(value: float32): uint32
      {.importjs: "(function(v){var b=new ArrayBuffer(4),d=new DataView(b);d.setFloat32(0,v,true);return d.getUint32(0,true)})(#)".}

proc newBinaryReader*(stream: Stream, acceptNonFiniteFloats = false): BinaryReader {.raises: [ValueError].} =
  ## Creates a reader over `stream`; the caller keeps ownership. Non-finite floats are
  ## refused unless `acceptNonFiniteFloats` is set.
  if stream == nil:
    raise newException(ValueError, "Stream is nil.")
  result.stream = stream
  result.acceptNonFiniteFloats = acceptNonFiniteFloats

proc isEnd*(reader: BinaryReader): bool {.raises: [IOError, OSError].} =
  ## Returns true when no bytes are left, buffered or not.
  if reader.bufferPosition < reader.buffer.len:
    return false
  reader.stream.atEnd()

proc logicalPosition*(reader: BinaryReader): int64 =
  ## Returns how many bytes this reader has handed to the caller.
  ## The count is kept here because `std/streams` does not check `getPositionImpl` for nil.
  reader.consumedBytes

proc readUInt8*(reader: var BinaryReader): uint8 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads one unsigned byte.
  if reader.bufferPosition >= reader.buffer.len and not reader.refill():
    raise newException(PmxTruncatedError, "Stream truncated while reading a byte.")
  result = uint8(ord(reader.buffer[reader.bufferPosition]))
  inc reader.bufferPosition
  inc reader.consumedBytes

proc readUInt16*(reader: var BinaryReader): uint16 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads an unsigned little-endian 16-bit value.
  let b0 = uint16(reader.readUInt8())
  let b1 = uint16(reader.readUInt8())
  b0 or (b1 shl 8)

proc readUInt32*(reader: var BinaryReader): uint32 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads an unsigned little-endian 32-bit value.
  let b0 = uint32(reader.readUInt8())
  let b1 = uint32(reader.readUInt8())
  let b2 = uint32(reader.readUInt8())
  let b3 = uint32(reader.readUInt8())
  b0 or (b1 shl 8) or (b2 shl 16) or (b3 shl 24)

proc readInt8*(reader: var BinaryReader): int8 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads a signed little-endian 8-bit value.
  cast[int8](reader.readUInt8())

proc readInt16*(reader: var BinaryReader): int16 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads a signed little-endian 16-bit value.
  cast[int16](reader.readUInt16())

proc readInt32*(reader: var BinaryReader): int32 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads a signed little-endian 32-bit value.
  cast[int32](reader.readUInt32())

proc readInt*(reader: var BinaryReader, size: int): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed PMX integer whose width is 1, 2, or 4 bytes.
  case size
  of 1:
    int32(reader.readInt8())
  of 2:
    int32(reader.readInt16())
  of 4:
    reader.readInt32()
  else:
    raise newException(ValueError, fmt"Invalid integer size {size}.")

proc readIndex*(reader: var BinaryReader, size: int): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a signed PMX reference. Only `-1` may represent a null reference.
  result = reader.readInt(size)
  if result < -1:
    raise newException(PmxFormatError, fmt"PMX index {result} is below the null sentinel -1.")

proc readVertexIndex*(reader: var BinaryReader, size: int): int32 {.raises: [IOError, OSError, ValueError].} =
  ## Reads a vertex reference, the only unsigned index type in PMX.
  case size
  of 1:
    result = int32(reader.readUInt8())
  of 2:
    result = int32(reader.readUInt16())
  of 4:
    let raw = reader.readUInt32()
    if raw > uint32(high(int32)):
      raise newException(PmxFormatError, "4-byte vertex index exceeds the library's int32 index range.")
    result = int32(raw)
  else:
    raise newException(ValueError, fmt"Invalid vertex index size {size}.")

proc readFloat32*(reader: var BinaryReader): float32 {.raises: [IOError, OSError, PmxFormatError].} =
  ## Reads a little-endian `float32`. NaN and infinity are rejected unless the reader
  ## accepts non-finite values.
  when defined(js):
    result = float32FromBits(reader.readUInt32())
  else:
    result = cast[float32](reader.readUInt32())
  if not reader.acceptNonFiniteFloats and classify(result) in {fcNan, fcInf, fcNegInf}:
    raise newException(PmxFormatError, fmt"Float32 value must be finite, got {result}.")

proc readStringLength*(
  reader: var BinaryReader,
  maxBytes = MaxStringBytes
): int {.raises: [IOError, OSError, ValueError].} =
  ## Reads a string length and applies the configured limit before allocation.
  if maxBytes < 0 or int64(maxBytes) > int64(MaxPmxStringBytes):
    raise newException(ValueError, fmt"String byte limit {maxBytes} is outside [0, {MaxPmxStringBytes}].")
  let length = reader.readInt32()
  if length < 0:
    raise newException(PmxFormatError, fmt"String length {length} is negative.")
  if length > int32(maxBytes):
    raise newException(PmxLimitError, fmt"String length {length} exceeds the limit of {maxBytes} bytes.")
  int(length)

proc readStringPayload*(
  reader: var BinaryReader,
  byteLength: int,
  textEncoding: int32,
  maxBytes = MaxStringBytes
): string {.raises: [IOError, OSError, ValueError].} =
  ## Reads and decodes a payload after its length has been checked.
  if maxBytes < 0 or int64(maxBytes) > int64(MaxPmxStringBytes):
    raise newException(ValueError, fmt"String byte limit {maxBytes} is outside [0, {MaxPmxStringBytes}].")
  if byteLength < 0 or byteLength > maxBytes:
    raise newException(ValueError, fmt"String payload length {byteLength} is outside [0, {maxBytes}].")
  if textEncoding != 0'i32 and textEncoding != 1'i32:
    raise newException(PmxFormatError, fmt"Unknown PMX text encoding {textEncoding}.")
  if byteLength == 0:
    return ""
  if textEncoding == 0 and (byteLength mod 2 != 0):
    raise newException(PmxFormatError, fmt"UTF-16LE string length must be even, got {byteLength}.")
  let buffer = reader.readRaw(byteLength)
  try:
    case textEncoding
    of 0:
      result = decodeUtf16Le(buffer)
    of 1:
      validateUtf8(buffer)
      result = buffer
    else:
      raise newException(PmxFormatError, fmt"Unknown PMX text encoding {textEncoding}.")
  except PmxFormatError:
    raise
  except ValueError as exc:
    raise newException(PmxFormatError, exc.msg, exc)

proc readString*(
  reader: var BinaryReader,
  textEncoding: int32,
  maxBytes = MaxStringBytes
): string {.raises: [IOError, OSError, ValueError].} =
  ## Reads a length-prefixed PMX string using the selected encoding.
  let byteLength = reader.readStringLength(maxBytes)
  reader.readStringPayload(byteLength, textEncoding, maxBytes)

proc newBinaryWriter*(stream: Stream): BinaryWriter {.raises: [ValueError].} =
  ## Creates a writer over `stream`; ownership stays with the caller.
  if stream == nil:
    raise newException(ValueError, "Stream is nil.")
  result.stream = stream

proc writeUInt8*(writer: var BinaryWriter, val: uint8) {.raises: [IOError, OSError].} =
  ## Writes one unsigned byte.
  writer.appendByte(val)

proc writeUInt16*(writer: var BinaryWriter, val: uint16) {.raises: [IOError, OSError].} =
  ## Writes an unsigned little-endian 16-bit value.
  writer.writeUInt8(uint8(val and 0xFF'u16))
  writer.writeUInt8(uint8(val shr 8))

proc writeUInt32*(writer: var BinaryWriter, val: uint32) {.raises: [IOError, OSError].} =
  ## Writes an unsigned little-endian 32-bit value.
  writer.writeUInt8(uint8(val and 0xFF'u32))
  writer.writeUInt8(uint8((val shr 8) and 0xFF'u32))
  writer.writeUInt8(uint8((val shr 16) and 0xFF'u32))
  writer.writeUInt8(uint8(val shr 24))

proc writeInt8*(writer: var BinaryWriter, val: int8) {.raises: [IOError, OSError].} =
  ## Writes a signed little-endian 8-bit value.
  writer.writeUInt8(cast[uint8](val))

proc writeInt16*(writer: var BinaryWriter, val: int16) {.raises: [IOError, OSError].} =
  ## Writes a signed little-endian 16-bit value.
  writer.writeUInt16(cast[uint16](val))

proc writeInt32*(writer: var BinaryWriter, val: int32) {.raises: [IOError, OSError].} =
  ## Writes a signed little-endian 32-bit value.
  writer.writeUInt32(cast[uint32](val))

proc writeInt*(writer: var BinaryWriter, val: int32, size: int) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed PMX integer using a 1-, 2-, or 4-byte width.
  case size
  of 1:
    if val < int32(low(int8)) or val > int32(high(int8)):
      raise newException(ValueError, fmt"Value {val} exceeds the 1-byte signed range.")
    writer.writeInt8(int8(val))
  of 2:
    if val < int32(low(int16)) or val > int32(high(int16)):
      raise newException(ValueError, fmt"Value {val} exceeds the 2-byte signed range.")
    writer.writeInt16(int16(val))
  of 4:
    writer.writeInt32(val)
  else:
    raise newException(ValueError, fmt"Invalid integer size {size}.")

proc writeIndex*(writer: var BinaryWriter, val: int32, size: int) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a signed PMX reference, reserving only `-1` for null.
  if val < -1:
    raise newException(ValueError, fmt"PMX index {val} is below the null sentinel -1.")
  writer.writeInt(val, size)

proc writeVertexIndex*(
  writer: var BinaryWriter,
  val: int32,
  size: int
) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a non-negative unsigned PMX vertex reference.
  if val < 0:
    raise newException(ValueError, fmt"Vertex index {val} must not be negative.")
  case size
  of 1:
    if val > 0xFF:
      raise newException(ValueError, "Vertex index exceeds the 1-byte unsigned range.")
    writer.writeUInt8(uint8(val))
  of 2:
    if val > 0xFFFF:
      raise newException(ValueError, "Vertex index exceeds the 2-byte unsigned range.")
    writer.writeUInt16(uint16(val))
  of 4:
    writer.writeUInt32(uint32(val))
  else:
    raise newException(ValueError, fmt"Invalid vertex index size {size}.")

proc writeFloat32*(writer: var BinaryWriter, val: float32) {.raises: [IOError, OSError, ValueError].} =
  ## Writes a little-endian `float32`. A value that is not finite is refused, and on
  ## JavaScript one that would overflow the 32-bit range is refused as well.
  if not isFiniteFloat32(val):
    raise newException(ValueError, fmt"Float32 value must be finite and representable, got {val}.")
  when defined(js):
    writer.writeUInt32(float32ToBits(val))
  else:
    writer.writeUInt32(cast[uint32](val))

proc writeRawStr*(writer: var BinaryWriter, s: string) {.raises: [IOError, OSError].} =
  ## Flushes buffered bytes and writes raw bytes without a length prefix.
  writer.flush()
  writer.stream.write(s)

proc writeString*(
  writer: var BinaryWriter,
  text: string,
  textEncoding: int32,
  maxBytes = MaxStringBytes
) {.raises: [IOError, OSError, ValueError].} =
  ## Encodes and writes a length-prefixed PMX string within `maxBytes`.
  if maxBytes < 0 or int64(maxBytes) > int64(MaxPmxStringBytes):
    raise newException(ValueError, fmt"String byte limit {maxBytes} is outside [0, {MaxPmxStringBytes}].")
  case textEncoding
  of 0:
    let encoded = encodeUtf16Le(text, maxBytes)
    writer.writeInt32(int32(encoded.len))
    writer.writeRawStr(encoded)
  of 1:
    if text.len > maxBytes:
      raise newException(ValueError, fmt"String length {text.len} exceeds the limit of {maxBytes} bytes.")
    validateUtf8(text)
    writer.writeInt32(int32(text.len))
    writer.writeRawStr(text)
  else:
    raise newException(ValueError, fmt"Invalid text encoding {textEncoding}.")
