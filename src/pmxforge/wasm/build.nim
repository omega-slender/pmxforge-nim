## WebAssembly bridge build driver.
##
## Provides the driver behind `nimble wasm`, which finds the Emscripten SDK and compiles the bridge.

import std/[os, osproc, strformat, strutils]

proc manifestVersion(text: string): string =
  ## Returns the `version` field a package manifest declares.
  for line in text.splitLines:
    let trimmed = line.strip
    if trimmed.startsWith("version"):
      let parts = trimmed.split('"')
      if parts.len >= 2:
        return parts[1]
  raise newException(ValueError, "the package manifest has no version field")

const
  EmsdkPathOverride {.strdefine: "pmxforgeEmsdkPath".} = "" ## Toolchain path from `-d:pmxforgeEmsdkPath`, unset by default.
  ThisFile = currentSourcePath() ## Absolute path of this file, known at compile time.
  PackageSrc = parentDir(parentDir(parentDir(ThisFile))) ## `<package>/src`.
  PackageRoot = parentDir(PackageSrc) ## `<package>`.
  BridgeModule = PackageSrc / "pmxforge" / "wasm" / "bridge.nim" ## Module compiled into wasm.
  DefaultOutDir = "build/wasm" ## Output directory, relative to the package root.
  BridgeVersion = manifestVersion(staticRead(PackageRoot / "pmxforge.nimble")) ## Read from the manifest, so it cannot drift.

var
  runtimeEmsdk = "" ## SDK path passed as a program argument instead of a define.

type
  Location = tuple[path: string, source: string]

  Toolchain = object
    root: string ## emsdk checkout holding the toolchain, empty when `emcc` comes from `PATH`.
    emcc: string ## Absolute path of the `emcc` launcher to run.
    fromEmsdk: bool ## True when `root` is an emsdk checkout that needs its environment.

proc fatal(message: string) {.noreturn.} =
  ## Reports a configuration problem and exits without building.
  stderr.writeLine fmt"error: {message}"
  quit(1)

proc findEmccIn(directory: string): string =
  ## Returns the `emcc` launcher inside `directory`, or "" when there is none.
  if directory.len == 0 or not dirExists(directory):
    return ""
  for name in ["emcc.exe", "emcc.cmd", "emcc.bat", "emcc"]:
    let candidate = directory / name
    if fileExists(candidate):
      return candidate

proc isEmsdk(path: string): bool =
  ## Returns true when `path` looks like an emsdk checkout.
  path.len > 0 and dirExists(path / "upstream" / "emscripten")

proc toolchainFrom(location: Location): Toolchain =
  ## Resolves one explicit location: an emsdk checkout, a directory holding `emcc`, or a prefix.
  if isEmsdk(location.path):
    let launcher = findEmccIn(location.path / "upstream" / "emscripten")
    if launcher.len == 0:
      fatal(fmt"'{location.path}' has upstream/emscripten but no emcc. Run 'emsdk install latest' " &
        "and 'emsdk activate latest' in that checkout.")
    return Toolchain(root: absolutePath(location.path), emcc: launcher, fromEmsdk: true)
  let direct = findEmccIn(location.path)
  if direct.len > 0:
    return Toolchain(root: "", emcc: direct, fromEmsdk: false)
  let prefixed = findEmccIn(location.path / "bin")
  if prefixed.len > 0:
    return Toolchain(root: "", emcc: prefixed, fromEmsdk: false)
  fatal(fmt"No Emscripten toolchain at '{location.path}' (from {location.source}). Point it at an emsdk " &
    "checkout, at a directory that holds emcc, or at a prefix whose bin/ holds it.")

proc commonLocations(): seq[Location] =
  ## Returns the usual emsdk install directories.
  result = @[
    (PackageRoot / ".." / "emsdk", "a sibling of the package"),
    (getHomeDir() / "emsdk", "the home directory"),
    ("/opt/emsdk", "a common POSIX location"),
    ("/usr/local/emsdk", "a common POSIX location")
  ]
  when defined(windows):
    result.add ("C:\\emsdk", "a common Windows location")

proc resolveToolchain(): Toolchain =
  ## Picks the toolchain: `-d:pmxforgeEmsdkPath`, then `PMXFORGE_EMSDK` or `EMSDK`, then
  ## the usual install directories, then `emcc` on `PATH`.
  if runtimeEmsdk.len > 0:
    return toolchainFrom((runtimeEmsdk, "-d:pmxforgeEmsdkPath"))
  if EmsdkPathOverride.len > 0:
    return toolchainFrom((EmsdkPathOverride, "-d:pmxforgeEmsdkPath"))
  for variable in ["PMXFORGE_EMSDK", "EMSDK"]:
    let value = getEnv(variable)
    if value.len > 0:
      return toolchainFrom((value, variable))
  for candidate in commonLocations():
    if isEmsdk(candidate.path):
      return toolchainFrom(candidate)
  let onPath = findExe("emcc")
  if onPath.len > 0:
    return Toolchain(root: "", emcc: onPath, fromEmsdk: false)
  fatal "Emscripten not found. Install the emsdk, run 'emsdk install latest' and " &
    "'emsdk activate latest', then pass -d:pmxforgeEmsdkPath:<path>, set PMXFORGE_EMSDK, or put " &
    "emcc on PATH."

proc versionKey(name: string): string =
  ## Pads every numeric run so plain string order matches version order.
  var i = 0
  while i < name.len:
    if name[i] in {'0'..'9'}:
      var j = i
      while j < name.len and name[j] in {'0'..'9'}:
        inc j
      let digits = name[i ..< j]
      result.add repeat('0', max(0, 8 - digits.len)) & digits
      i = j
    else:
      result.add name[i]
      inc i

proc newestSubdirectory(parent: string): string =
  ## Returns the newest version subdirectory of `parent`, or "" when there is none.
  if not dirExists(parent):
    return ""
  var bestKey = ""
  for kind, path in walkDir(parent):
    if kind != pcDir:
      continue
    let key = versionKey(extractFilename(path))
    if result.len == 0 or key > bestKey:
      bestKey = key
      result = path

proc prependPath(directory: string) =
  ## Adds `directory` to the front of `PATH` when it is not empty.
  if directory.len == 0:
    return
  let separator = when defined(windows): ";" else: ":"
  putEnv("PATH", directory & separator & getEnv("PATH"))

proc prepareToolchain(toolchain: Toolchain) =
  ## Puts `emcc` on `PATH` and, for an emsdk checkout, exports the variables it needs.
  prependPath(parentDir(toolchain.emcc))
  if not toolchain.fromEmsdk:
    return
  let emsdk = toolchain.root
  putEnv("EMSDK", emsdk)
  putEnv("EM_CONFIG", emsdk / ".emscripten")

  let pythonDir = newestSubdirectory(emsdk / "python")
  for candidate in [pythonDir / "python.exe", pythonDir / "bin" / "python3", pythonDir / "bin" / "python"]:
    if fileExists(candidate):
      putEnv("EMSDK_PYTHON", candidate)
      break

  let nodeDir = newestSubdirectory(emsdk / "node")
  for candidate in [nodeDir / "bin" / "node.exe", nodeDir / "bin" / "node"]:
    if fileExists(candidate):
      putEnv("EMSDK_NODE", candidate)
      break

  prependPath(nodeDir / "bin")
  prependPath(pythonDir / "bin")
  prependPath(pythonDir)
  prependPath(emsdk / "upstream" / "bin")

proc parseArguments(): tuple[outDir: string, debug: bool] =
  ## Parses `--out:`, `--debug`, and `-d:pmxforgeEmsdkPath:` from the arguments.
  result.outDir = PackageRoot / DefaultOutDir
  result.debug = false
  for argument in commandLineParams():
    if argument == "--" or argument.len == 0:
      continue
    if argument == "--debug":
      result.debug = true
    elif argument.startsWith("-d:pmxforgeEmsdkPath:") or argument.startsWith("-d:pmxforgeEmsdkPath="):
      let value = argument[("-d:pmxforgeEmsdkPath".len + 1) .. ^1]
      if value.len == 0:
        fatal "-d:pmxforgeEmsdkPath needs a path."
      runtimeEmsdk = value
    elif argument.startsWith("--out:"):
      let value = argument[6 .. ^1]
      if value.len == 0:
        fatal "--out: needs a directory."
      result.outDir = if isAbsolute(value): value else: PackageRoot / value
    else:
      fatal fmt"Unknown argument '{argument}'. Use --out:<dir> and --debug."

proc buildArguments(outDir: string, debug: bool): seq[string] =
  ## Returns the Nim arguments that compile the bridge.
  result = @[
    "c",
    "--hints:off",
    "-d:emscripten",
    "--os:linux",
    "--cpu:wasm32",
    "--threads:off",
    "-d:pmxforgeNoFileSystem"
  ]
  if not debug:
    result.add "-d:release"
  result.add "--nimcache:" & (outDir / "nimcache")
  result.add "--path:" & PackageSrc
  result.add "-o:" & (outDir / "pmxforge.mjs")
  for flag in [
    "-sEXPORTED_FUNCTIONS=_main,_pmxforge_validate,_pmxforge_roundtrip,_pmxforge_free," &
      "_pmxforge_last_message,_pmxforge_last_status,_pmxforge_version,_pmxforge_set_limits," &
      "_malloc,_free",
    "-sEXPORTED_RUNTIME_METHODS=HEAPU8,HEAP32,UTF8ToString",
    "-sMODULARIZE=1",
    "-sEXPORT_ES6=1",
    "-sEXPORT_NAME=createPmxForge",
    "-sENVIRONMENT=node,web",
    "-sALLOW_MEMORY_GROWTH=1",
    "-sSTACK_SIZE=1048576"
  ]:
    result.add "--passL:" & flag
  result.add BridgeModule

when isMainModule:
  let (outDir, debug) = parseArguments()
  let toolchain = resolveToolchain()
  prepareToolchain(toolchain)
  createDir(outDir)

  if toolchain.fromEmsdk:
    echo "Emscripten SDK: ", toolchain.root
  echo "emcc: ", toolchain.emcc
  echo "Bridge version: ", BridgeVersion
  echo "Building ", outDir / "pmxforge.mjs"

  var exitCode = 0
  try:
    let process = startProcess(
      getCurrentCompilerExe(),
      args = buildArguments(outDir, debug),
      options = {poUsePath, poParentStreams}
    )
    exitCode = waitForExit(process)
    close(process)
  except OSError as exc:
    fatal fmt"Cannot start the Nim compiler: {exc.msg}"
  if exitCode != 0:
    quit exitCode
  echo "Wrote ", outDir / "pmxforge.mjs"
  echo "Wrote ", outDir / "pmxforge.wasm"
