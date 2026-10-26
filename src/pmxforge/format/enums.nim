## Header enumerations.
##
## Provides `PmxVersion` and `TextEncoding`, whose ordinals are part of the wire format, plus the checked
## conversion used by the header.

import ./internal/preconditions

type
  PmxVersion* = enum ## PMX format version.
    pmx20 ## Original format, without soft bodies or QDEF.
    pmx21 ## PMX 2.1 (supports soft bodies, vertex QDEF, additional morphs).

  TextEncoding* {.size: sizeof(int32).} = enum ## Text encoding used across PMX strings.
    teUTF16LE = 0 ## UTF-16 little-endian.
    teUTF8 = 1 ## UTF-8.

proc toFileVersion*(version: PmxVersion): float32 {.inline, raises: [ValueError].} =
  ## Returns the float version (2.0 or 2.1) for the PMX header.
  requireValidEnum(version, "PMX version")
  case version
  of pmx20:
    2.0'f32
  of pmx21:
    2.1'f32
