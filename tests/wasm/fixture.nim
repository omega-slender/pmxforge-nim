## WebAssembly smoke fixtures.
##
## Provides the two PMX files the Node smoke test feeds to the bridge: one valid model and one that
## parses but fails validation.

import std/os
import pmxforge
import ../support

let targetDir = if paramCount() >= 1: paramStr(1) else: "build/wasm"
createDir(targetDir)

let validPath = targetDir / "fixture.pmx"
writePmx(sampleModel(), validPath)
echo "wrote ", validPath, " (", getFileSize(validPath), " bytes)"

let damagedPath = targetDir / "damaged.pmx"
writePmx(damagedModel(), damagedPath, mode = pwmLenient)
echo "wrote ", damagedPath, " (", getFileSize(damagedPath), " bytes)"
