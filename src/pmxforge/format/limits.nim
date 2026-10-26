## Hard format limits.
##
## Provides `MaxStringBytes`, `MaxPmxStringBytes`, and `MaxElementCount`, shared by the reader, the
## writer, and the validators.

import strformat

const
  MaxStringBytes* = 65_536 ## Default cap for one text field (64 KiB).
  MaxPmxStringBytes* = high(int32) ## Largest payload the PMX int32 length field can describe.
  MaxElementCount* = 4_000_000 ## Cap on entries in any single PMX collection.

proc checkElementCount*(count: int, label: string) {.raises: [ValueError].} =
  ## Raises ValueError if `count` exceeds `MaxElementCount`.
  if count > MaxElementCount:
    raise newException(ValueError, fmt"{label} count {count} exceeds the hard limit of {MaxElementCount}.")
