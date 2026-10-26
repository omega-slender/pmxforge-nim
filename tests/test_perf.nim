## Performance regressions for diagnostic labels (F10 and S01).
##
## The old validator and writer copied a morph name into every offset label, so their time grew with
## `name.len * offsets.len`. This suite builds the same 250,000-offset morph with and without a 64 KiB
## name and compares the best of several runs on the same machine, for validation and for writing. A
## relative bound keeps the check meaningful on slow CI hosts; the old implementation was about 40x
## slower, while the capped context is within noise of the empty name.

import std/[strutils, times, unittest]
import pmxforge

const
  OffsetCount = 250_000
  LongNameBytes = 65_536

proc buildModel(name: string): PmxModel =
  ## Builds a model whose only work is validating a large group morph.
  var offsets = newSeq[MorphOffset](OffsetCount)
  for i in 0 ..< offsets.len:
    offsets[i] = MorphOffset(kind: moGroup, group: GroupMorphOffset(morphIndex: -1'i32))
  newPmxModel(
    nameJA = "perf",
    vertices = @[newVertex()],
    bones = @[newBone(nameJA = "root")],
    morphs = @[newMorph(nameJA = name, morphType = mtGroup, offsetData = offsets)]
  )

proc bestTime(model: PmxModel, runs = 3): float =
  ## Returns the fastest validation time; the minimum is robust to scheduler spikes.
  result = Inf
  for _ in 0 ..< runs:
    let start = cpuTime()
    validate(model)
    result = min(result, cpuTime() - start)

suite "F10 diagnostic context performance":
  test "a 64 KiB morph name does not multiply validation time by the offset count":
    let shortModel = buildModel("")
    discard shortModel.bestTime(1)
    let shortTime = shortModel.bestTime(3)
    let longModel = buildModel(repeat('x', LongNameBytes))
    discard longModel.bestTime(1)
    let longTime = longModel.bestTime(3)
    check longTime <= shortTime * 4.0 + 0.25

proc bestWriteTime(model: PmxModel, runs = 3): float =
  ## Returns the fastest serialization time; the minimum is robust to scheduler spikes.
  result = Inf
  for _ in 0 ..< runs:
    let start = cpuTime()
    discard writePmx(model)
    result = min(result, cpuTime() - start)

suite "S01 writer diagnostic context performance":
  test "a 64 KiB morph name does not multiply write time by the offset count":
    ## The writer formats diagnostics inside the offset loop. It has to bound the name
    ## just like the validator, or a valid file becomes quadratic formatting work.
    let shortModel = buildModel("")
    discard shortModel.bestWriteTime(1)
    let shortTime = shortModel.bestWriteTime(3)
    let longModel = buildModel(repeat('x', LongNameBytes))
    discard longModel.bestWriteTime(1)
    let longTime = longModel.bestWriteTime(3)
    check longTime <= shortTime * 4.0 + 0.25
