## Format exceptions.
##
## Provides `PmxFormatError`, `PmxTruncatedError`, and `PmxLimitError` so every failure can be
## caught through `ValueError`.

type
  PmxFormatError* = object of ValueError ## Base exception for malformed PMX data or format violations.

  PmxTruncatedError* = object of PmxFormatError ## Stream or buffer ended unexpectedly before finishing a field.

  PmxLimitError* = object of PmxFormatError ## Input size or element count exceeded configured safety limits.
