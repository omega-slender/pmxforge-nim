## Model container behavior.
##
## Provides checks for construction defaults, deep copies, comparison, the PMX 2.1 feature probe,
## and the in-place repair pass.

import std/unittest
import pmxforge
import ./support

proc parentsTerminate(model: PmxModel): bool =
  ## Returns true when every parent chain reaches the -1 root sentinel.
  for i in 0 ..< model.bones.len:
    var current = model.bones[i].parentBoneIndex
    var steps = 0
    while current >= 0 and steps <= model.bones.len:
      current = model.bones[int(current)].parentBoneIndex
      inc steps
    if steps > model.bones.len:
      return false
  result = true

suite "construction":
  test "defaults describe an empty PMX 2.1 model":
    ## A new container starts on the modern version with UTF-8 text.
    let model = newPmxModel(nameJA = "empty")
    check model.version == pmx21
    check model.textEncoding == teUTF8
    check model.nameEN == "empty"
    check model.additionalUvCount == 0'i32
    check model.vertices.len == 0
    check model.softBodies.len == 0

  test "the English name follows the Japanese name":
    ## A single name is enough for a usable model.
    let model = newPmxModel(nameJA = "モデル")
    check model.nameEN == "モデル"
    check newPmxModel(nameJA = "a", nameEN = "b").nameEN == "b"

  test "unknown versions and encodings are refused":
    ## Both fields are wire values with a fixed set of legal ordinals.
    expect ValueError:
      discard newPmxModel(nameJA = "bad", version = cast[PmxVersion](7))
    expect ValueError:
      discard newPmxModel(nameJA = "bad", textEncoding = cast[TextEncoding](5))

  test "the additional UV count stays between zero and four":
    ## The header stores it in a single byte.
    expect ValueError:
      discard newPmxModel(nameJA = "bad", additionalUvCount = 5'i32)
    expect ValueError:
      discard newPmxModel(nameJA = "bad", additionalUvCount = -1'i32)
    check newPmxModel(nameJA = "ok", additionalUvCount = 4'i32).additionalUvCount == 4'i32

  test "element lists are copied on the way in":
    ## The container must not alias caller-owned elements.
    let vertex = newVertex()
    let model = newPmxModel(nameJA = "copy", vertices = @[vertex])
    vertex.position.x = 5.0'f32
    check model.vertices[0].position.x == 0.0'f32

suite "copying and comparison":
  test "copy detaches every element":
    ## Editing a copy leaves the original untouched, storage included.
    let original = sampleModel()
    let clone = original.copy()
    clone.nameJA = "clone"
    clone.directory = "/tmp/elsewhere"
    clone.vertices[0].position.x = 9.0'f32
    clone.bones[0].nameJA = "renamed"
    clone.faces[0].vertexIndex1 = 3'i32
    clone.morphs[0].offsetData[0].vertex.translation.y = 4.0'f32
    clone.displayFrames[0].frames[0].targetIndex = 2'i32
    clone.rigidBodies[0].mass = 12.0'f32
    check original.nameJA == "sample"
    check original.directory.len == 0
    check original.vertices[0].position.x == -0.5'f32
    check original.bones[0].nameJA == "root"
    check original.faces[0].vertexIndex1 == 0'i32
    check original.morphs[0].offsetData[0].vertex.translation.y == 0.1'f32
    check original.displayFrames[0].frames[0].targetIndex == 0'i32
    check original.rigidBodies[0].mass == 1.0'f32

  test "copying nil stays nil":
    ## The helpers are nil-safe so callers can chain them.
    let empty: PmxModel = nil
    check empty.copy() == nil
    check copy(Vertex(nil)) == nil
    check copy(Material(nil)) == nil

  test "samePmxContent ignores the runtime directory":
    ## Only the directory differs, and that field never reaches the wire.
    let original = sampleModel()
    let moved = original.copy()
    moved.directory = "C:\\models"
    check original.samePmxContent(moved)
    check not (original == moved)

  test "samePmxContent notices real differences":
    ## A single changed element is enough to break the comparison.
    let original = sampleModel()
    let edited = original.copy()
    edited.vertices[0].uv.x = 0.5'f32
    check not original.samePmxContent(edited)

  test "nil models compare equal to each other only":
    ## Comparison never dereferences a nil reference.
    let empty: PmxModel = nil
    let model = sampleModel()
    check empty == PmxModel(nil)
    check not (empty == model)
    check samePmxContent(empty, PmxModel(nil))
    check not samePmxContent(empty, model)

suite "PMX 2.1 features":
  test "a plain model needs only PMX 2.0":
    ## Vertices, faces, and a material fit the older version.
    let model = newPmxModel(nameJA = "plain", version = pmx20, vertices = @[newVertex()])
    check not isPmx21Only(model)

  test "soft bodies, QDEF, and 2.1 joints promote the model":
    ## Any of these features forces the newer version.
    let withSoftBody = sampleModel()
    check isPmx21Only(withSoftBody)

    let withQdef = newPmxModel(
      nameJA = "qdef",
      version = pmx20,
      vertices = @[newVertex(weightDeform = newQDEF(0'i32, 1'i32, 2'i32, 3'i32))]
    )
    check isPmx21Only(withQdef)

    let withHinge = newPmxModel(
      nameJA = "hinge",
      version = pmx20,
      joints = @[newJoint(nameJA = "hinge", jointType = jtHinge)]
    )
    check isPmx21Only(withHinge)

  test "2.1 morphs and material flags promote the model":
    ## Flip morphs and the newer render flags are version-gated too.
    let withFlip = newPmxModel(
      nameJA = "flip",
      version = pmx20,
      morphs = @[newMorph(nameJA = "flip", morphType = mtFlip)]
    )
    check isPmx21Only(withFlip)

    let withVertexColor = newPmxModel(
      nameJA = "tint",
      version = pmx20,
      materials = @[newMaterial(nameJA = "m", flags = MaterialFlags(vertexColor: true))]
    )
    check isPmx21Only(withVertexColor)

  test "a nil model has no 2.1 features":
    ## The probe tolerates a nil reference.
    let empty: PmxModel = nil
    check not isPmx21Only(empty)

suite "repair":
  test "repair fixes dangling references and values":
    ## The damaged fixture fails validation until it is repaired.
    let model = damagedModel()
    check not model.isValid()
    model.repair()
    check model.isValid()
    check model.bones[0].parentBoneIndex == -1'i32
    check model.materials[0].textureIndex == -1'i32
    check model.vertices[0].edgeScale >= 0.0'f32

  test "repair breaks parent cycles":
    ## A loop in the bone hierarchy cannot survive the pass.
    let model = sampleModel()
    model.bones[0].parentBoneIndex = 2'i32
    check not parentsTerminate(model)
    model.repair()
    check parentsTerminate(model)

  test "repair drops self-referencing group morphs":
    ## A morph that controls itself is a cycle with no useful meaning.
    let model = sampleModel()
    model.morphs[1].offsetData[0].group.morphIndex = 1'i32
    model.repair()
    check model.morphs[1].offsetData.len == 0

  test "repair refuses nil elements instead of crashing":
    ## A nil entry cannot be repaired safely, so the caller hears about it.
    let model = sampleModel()
    model.vertices.add(Vertex(nil))
    expect ValueError:
      model.repair()

  test "repairing nil is a no-op":
    ## Nothing to do, nothing to raise.
    let empty: PmxModel = nil
    repair(empty)

suite "format limits":
  test "the published caps keep their meaning":
    ## Callers compare against these values when sizing their own buffers.
    check MaxStringBytes == 65_536
    check MaxPmxStringBytes == high(int32)
    check MaxElementCount == 4_000_000

  test "checkElementCount rejects oversized collections":
    ## One entry past the cap is already too many.
    checkElementCount(MaxElementCount, "Vertex")
    expect ValueError:
      checkElementCount(MaxElementCount + 1, "Vertex")

  test "file versions map to their header floats":
    ## The version is written as 2.0 or 2.1, not as an ordinal.
    check toFileVersion(pmx20) == 2.0'f32
    check toFileVersion(pmx21) == 2.1'f32
    expect ValueError:
      discard toFileVersion(cast[PmxVersion](9))
