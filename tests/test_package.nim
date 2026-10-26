## Package metadata tests.
##
## The version is declared in the manifest, repeated in the README badge, read by the
## documentation generator, and reported by the WebAssembly ABI. A release bumps one and
## forgets another, so this suite fails when they disagree.

import std/[os, strutils, unittest]
import pmxforge/wasm/bridge

const
  PackageRoot = parentDir(parentDir(currentSourcePath()))
  ManifestPath = PackageRoot / "pmxforge.nimble"
  ReadmePath = PackageRoot / "README.md"
  ApiDocsPath = PackageRoot / "docs" / "API.md"

proc manifestVersion(text: string): string =
  ## Returns the `version` field the manifest declares.
  for line in text.splitLines:
    let trimmed = line.strip
    if trimmed.startsWith("version"):
      let parts = trimmed.split('"')
      if parts.len >= 2:
        return parts[1]
  raise newException(ValueError, "the package manifest has no version field")

suite "package metadata":
  test "the version agrees across the manifest, the README, the docs and the bridge":
    ## `pmxforge_version` is what a JavaScript host reads, so it has to match the package.
    if not fileExists(ManifestPath):
      skip()
    let version = manifestVersion(readFile(ManifestPath))
    check version.len > 0
    check $pmxforge_version() == version
    check ("version-" & version) in readFile(ReadmePath)
    check ("**Version " & version & "**") in readFile(ApiDocsPath)
