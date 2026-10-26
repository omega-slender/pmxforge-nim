## Validation rules.
##
## Provides checks that the strict validator catches semantic mistakes and that the wire-safe one stays
## permissive, both reporting through ValueError.

import std/unittest
import pmxforge
import ./support

suite "strict validation":
  test "the sample model passes":
    ## A well-formed model has nothing to report.
    let model = sampleModel()
    validate(model)
    check model.isValid()

  test "a nil model is an error, not a crash":
    ## Validation always reports through ValueError.
    let empty: PmxModel = nil
    expect ValueError:
      validate(empty)
    check not empty.isValid()

  test "the material face counts must cover every face":
    ## The sum of the per-material ranges has to match the face list.
    let model = sampleModel()
    model.materials[0].faceCount = 5'i32
    expect ValueError:
      validate(model)

  test "faces without a material are rejected":
    ## Nothing would render them, so the model is inconsistent.
    let model = sampleModel()
    model.materials = @[]
    expect ValueError:
      validate(model)

  test "dangling references are rejected":
    ## Every index must land inside its target list.
    let model = damagedModel()
    expect ValueError:
      validate(model)
    check not model.isValid()

  test "out-of-range values are rejected":
    ## Scalar ranges are part of the contract.
    let model = sampleModel()
    model.materials[0].alpha = 2.0'f32
    expect ValueError:
      validate(model)

  test "additional UV counts must match the header":
    ## The header and the vertex payloads have to agree.
    let model = sampleModel()
    model.additionalUvCount = 1'i32
    expect ValueError:
      validate(model)

  test "text can be capped by the caller":
    ## Services reading untrusted input pass their own byte budget.
    let model = sampleModel()
    validate(model, maxStringBytes = 1024)
    expect ValueError:
      validate(model, maxStringBytes = 2)

  test "enum fields are checked before they are used":
    ## A corrupted enum ordinal never reaches a case branch.
    let model = sampleModel()
    model.morphs[0].morphType = cast[MorphType](42)
    expect ValueError:
      validate(model)

suite "wire-safe validation":
  test "dangling but encodable references pass":
    ## Lenient writing keeps defects that still fit the wire.
    let model = damagedModel()
    check isValid(model, strict = false)

  test "values that cannot be encoded are still rejected":
    ## A negative index sits below the -1 sentinel and cannot be stored.
    let model = sampleModel()
    model.bones[0].parentBoneIndex = -5'i32
    check not isValid(model, strict = false)

  test "non-finite floats are still rejected":
    ## NaN has no wire representation the reader would accept.
    let model = sampleModel()
    model.vertices[0].position.x = NaN
    check not isValid(model, strict = false)

suite "write preparation":
  test "a nil model cannot be prepared":
    ## The writer needs an object to inspect.
    let empty: PmxModel = nil
    expect ValueError:
      validateWritePreparation(empty)

  test "the string budget is range checked":
    ## The field is an int32 length, so the cap has to fit one.
    let model = sampleModel()
    validateWritePreparation(model, maxStringBytes = 1024)
    expect ValueError:
      validateWritePreparation(model, maxStringBytes = -1)
    expect ValueError:
      validateWritePreparation(model, maxStringBytes = int(high(int32)) + 1)

  test "nil elements are caught before the writer copies them":
    ## Copying a nil element would be a crash, so it is refused here.
    let model = sampleModel()
    model.textures.add(Texture(nil))
    expect ValueError:
      validateWritePreparation(model)

  test "valid models prepare cleanly":
    ## The happy path returns without raising.
    validateWritePreparation(sampleModel())
    check true
