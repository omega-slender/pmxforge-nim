## Internal copying helpers.
##
## Provides `copyString`, `copySeq`, and `copyRefSeq` to detach storage instead of sharing it
## between a model and its copies.

proc copyString*(value: string): string =
  ## Returns a detached copy of `value`.
  result = newString(value.len)
  if value.len > 0:
    when defined(js):
      for i, ch in value:
        result[i] = ch
    else:
      copyMem(addr result[0], unsafeAddr value[0], value.len)

proc copySeq*[T](value: seq[T]): seq[T] =
  ## Returns a shallow copy of a sequence.
  result = newSeq[T](value.len)
  for i, item in value:
    result[i] = item

proc copyRefSeq*[T](value: seq[T]): seq[T] =
  ## Deep-copies each ref element with its own `.copy`.
  result = newSeq[T](value.len)
  for i, item in value:
    result[i] = item.copy()
