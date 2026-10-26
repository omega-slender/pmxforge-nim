## Independent PMX fixtures.
##
## The files under `tests/fixtures/` are encoded by `tools/make_fixtures.nim` with primitive writes, not
## by this library, so these tests exercise the reader against bytes produced independently of the writer.

import std/[os, unittest]
import pmxforge

proc fixturePath(name: string): string =
  ## Returns the absolute path of a committed fixture.
  currentSourcePath().parentDir / "fixtures" / name

suite "independent fixtures":
  test "a PMX 2.0 sub-texture file validates and keeps sphere mode 3":
    ## The base 2.0 material block already carries `sbmSubTexture`; only UV1 is required.
    let model = readPmx(fixturePath("pmx20-subtexture.pmx"))
    validate(model)
    check model.version == pmx20
    check model.additionalUvCount == 1
    check model.vertices.len == 1
    check model.vertices[0].additionalUv.len == 1
    check model.vertices[0].additionalUv[0] == Vector4(x: 0.1'f32, y: 0.2'f32, z: 0.3'f32, w: 0.4'f32)
    check model.materials[0].sphereBlendMode == sbmSubTexture
    let again = readPmx(writePmx(model))
    check again.version == pmx20
    check again.materials[0].sphereBlendMode == sbmSubTexture
    check again.isValid()

  test "a PMX 2.1 ConeTwist file keeps its repurposed limit fields":
    ## The lower vectors hold damping, thresholds, motor flags, and span angles, not min/max pairs.
    let model = readPmx(fixturePath("pmx21-conetwist.pmx"))
    validate(model)
    check model.version == pmx21
    check model.joints.len == 1
    check model.joints[0].jointType == jtConeTwist
    check model.joints[0].positionMinimum == Vector3(x: 1.5'f32, y: 2.5'f32, z: 1.0'f32)
    check model.joints[0].positionMaximum == Vector3(x: 0.0'f32, y: 0.0'f32, z: 3.0'f32)
    check model.joints[0].rotationMinimum == Vector3(x: 0.5'f32, y: 0.25'f32, z: 0.75'f32)
    let again = readPmx(writePmx(model))
    check again.joints[0].rotationMinimum == model.joints[0].rotationMinimum
    check again.joints[0].positionMaximum == model.joints[0].positionMaximum

  test "a PMX 2.1 flip file may reference itself":
    ## The specification allows self-registration; the staged evaluation is not a group recursion.
    let model = readPmx(fixturePath("pmx21-flip-self.pmx"))
    validate(model)
    check model.version == pmx21
    check model.morphs.len == 1
    check model.morphs[0].morphType == mtFlip
    check model.morphs[0].offsetData.len == 1
    check model.morphs[0].offsetData[0].flip.morphIndex == 0'i32
    model.repair()
    check model.morphs[0].offsetData.len == 1
    let again = readPmx(writePmx(model))
    check again.morphs[0].offsetData[0].flip.morphIndex == 0'i32
