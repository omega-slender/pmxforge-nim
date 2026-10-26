## Convert the text encoding.
##
## Rewrites the strings as UTF-8 or UTF-16LE. MMD usually writes UTF-16LE, while most other tools and version
## control systems prefer UTF-8.

import std/[strformat, strutils]
import pmxforge

when isMainModule:
  import std/os

proc encodingName(encoding: TextEncoding): string =
  ## Returns the name of a text encoding for the report.
  if encoding == teUTF8: "UTF-8" else: "UTF-16LE"

proc parseEncoding*(name: string): TextEncoding =
  ## Returns the encoding a command line word asks for.
  case name.toLowerAscii
  of "utf8", "utf-8":
    teUTF8
  of "utf16", "utf-16", "utf16le", "utf-16le":
    teUTF16LE
  else:
    raise newException(ValueError, fmt"Unknown encoding: {name}. Use utf8 or utf16.")

when isMainModule:
  if paramCount() < 1:
    quit(
      "usage: convert_encoding <model.pmx> [model-utf8.pmx] [utf8|utf16]\n" &
        "Generate a sample first: nim c -r examples/make_sample.nim",
      1)
  let input = paramStr(1)
  if not fileExists(input):
    quit(fmt"No such file: {input}", 1)
  let (directory, name, _) = splitFile(input)
  let output =
    if paramCount() >= 2:
      paramStr(2)
    else:
      directory / (name & "-utf8.pmx")
  let wanted =
    if paramCount() >= 3:
      try:
        parseEncoding(paramStr(3))
      except ValueError as error:
        quit(error.msg, 1)
    else:
      teUTF8

  let model = readPmx(input, DesktopPmxReadLimits)
  let previous = model.textEncoding
  model.textEncoding = wanted

  validate(model)
  writePmx(model, output)

  let reloaded = readPmx(output)
  echo fmt"encoding {encodingName(previous)} to {encodingName(reloaded.textEncoding)}"
  echo fmt"name reads back as '{reloaded.nameJA}', comments '{reloaded.commentsEN}'"
  echo fmt"content preserved: {samePmxContent(model, reloaded)}"
  echo fmt"wrote {output}"
