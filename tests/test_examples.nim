## Behavioral tests for the examples that transform geometry.
##
## Compiling an example only proves that it builds. These checks import the transformation procs and
## verify what they do to SDEF data, mirrored attributes, and refusals (F08 and F09).

import std/[os, strutils, tables, unittest]
import pmxforge
import ./support
import ../examples/transform_vertices
import ../examples/mirror_mesh
import ../examples/downgrade_20
import ../examples/fix_texture_paths
import ../examples/export_obj
import ../examples/inspect
import ../examples/add_box
import ../examples/add_bone_chain
import ../examples/add_morphs
import ../examples/add_physics
import ../examples/batch_repair
import ../examples/build_ik
import ../examples/convert_encoding
import ../examples/convert_skinning
import ../examples/fill_names
import ../examples/flip_faces
import ../examples/make_sample
import ../examples/recompute_normals
import ../examples/rename_model
import ../examples/retint_materials
import ../examples/sanitize_bytes
import ../examples/setup_soft_body
import ../examples/soften_weights
import ../examples/split_material
import ../examples/stats_csv
import ../examples/strip_physics

proc staticModel(): PmxModel =
  ## Builds a one-triangle static mesh with an extra UV channel and a non-default edge scale.
  let a = newVertex(
    position = Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.0'f32),
    normal = Vector3.up,
    uv = Vector2(x: 0.25'f32, y: 0.5'f32),
    additionalUv = @[Vector4(x: 0.1'f32, y: 0.2'f32, z: 0.3'f32, w: 0.4'f32)],
    edgeScale = 0.25'f32
  )
  let b = newVertex(
    position = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
    normal = Vector3.up,
    uv = Vector2(x: 0.75'f32, y: 0.5'f32),
    additionalUv = @[Vector4(x: 0.1'f32, y: 0.2'f32, z: 0.3'f32, w: 0.4'f32)],
    edgeScale = 0.25'f32
  )
  let c = newVertex(
    position = Vector3(x: 0.0'f32, y: 1.0'f32, z: 0.0'f32),
    normal = Vector3.up,
    uv = Vector2(x: 0.5'f32, y: 1.0'f32),
    additionalUv = @[Vector4(x: 0.1'f32, y: 0.2'f32, z: 0.3'f32, w: 0.4'f32)],
    edgeScale = 0.25'f32
  )
  result = newPmxModel(
    nameJA = "static",
    additionalUvCount = 1'i32,
    vertices = @[a, b, c],
    faces = @[newFace(0'i32, 1'i32, 2'i32)],
    materials = @[newMaterial(nameJA = "skin", faceCount = 1'i32)]
  )

suite "F08 transform_vertices":
  test "the SDEF correction vectors scale with the position":
    ## c/r0/r1 are model-space coordinates; leaving them behind changes the deformation.
    let model = newPmxModel(
      nameJA = "sdef",
      vertices = @[
        newVertex(
          position = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32),
          weightDeform = newSDEF(
            boneIndex1 = 0'i32,
            boneIndex2 = 1'i32,
            c = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32),
            r0 = Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.5'f32),
            r1 = Vector3(x: 2.0'f32, y: 1.0'f32, z: -0.5'f32)
          )
        )
      ],
      bones = @[newBone(nameJA = "a"), newBone(nameJA = "b")]
    )
    scaleVertices(model, 2.0'f32)
    let vertex = model.vertices[0]
    check vertex.position == Vector3(x: 2.0'f32, y: 4.0'f32, z: 6.0'f32)
    check vertex.weightDeform.sdef.c == Vector3(x: 2.0'f32, y: 4.0'f32, z: 6.0'f32)
    check vertex.weightDeform.sdef.r0 == Vector3(x: -2.0'f32, y: 0.0'f32, z: 1.0'f32)
    check vertex.weightDeform.sdef.r1 == Vector3(x: 4.0'f32, y: 2.0'f32, z: -1.0'f32)
    validate(model)

  test "a non-positive or non-finite factor is refused":
    ## A negative factor would mirror the model while claiming to convert units.
    let model = newPmxModel(
      nameJA = "guard",
      vertices = @[newVertex(position = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32))]
    )
    expect ValueError:
      scaleVertices(model, -1.0'f32)
    expect ValueError:
      scaleVertices(model, 0.0'f32)
    check model.vertices[0].position.x == 1.0'f32

  test "a non-SDEF vertex is untouched beyond its position":
    let model = newPmxModel(
      nameJA = "bdef",
      vertices = @[newVertex(position = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32))],
      bones = @[newBone(nameJA = "root")]
    )
    scaleVertices(model, 0.5'f32)
    check model.vertices[0].position == Vector3(x: 0.5'f32, y: 1.0'f32, z: 1.5'f32)
    check model.vertices[0].weightDeform.kind == dkBDEF1

  test "physics scaling follows the joint-type limit layout":
    ## ConeTwist stores damping and span angles in the limit block; those are not lengths.
    let model = sampleModel()
    model.joints = @[
      newJoint(
        nameJA = "cone",
        jointType = jtConeTwist,
        rigidBodyIndexA = 0'i32,
        rigidBodyIndexB = 1'i32,
        position = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
        positionMinimum = Vector3(x: 1.0'f32, y: 2.0'f32, z: 1.0'f32),
        positionMaximum = Vector3(x: 3.0'f32, y: 4.0'f32, z: 5.0'f32)
      ),
      newJoint(
        nameJA = "six",
        jointType = jtSpring6DOF,
        rigidBodyIndexA = 0'i32,
        rigidBodyIndexB = 1'i32,
        position = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
        positionMinimum = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32),
        positionMaximum = Vector3(x: 4.0'f32, y: 5.0'f32, z: 6.0'f32)
      )
    ]
    scalePhysics(model, 2.0'f32)
    check model.joints[0].position == Vector3(x: 2.0'f32, y: 0.0'f32, z: 0.0'f32)
    check model.joints[0].positionMinimum == Vector3(x: 1.0'f32, y: 2.0'f32, z: 1.0'f32)
    check model.joints[0].positionMaximum == Vector3(x: 3.0'f32, y: 4.0'f32, z: 5.0'f32)
    check model.joints[1].positionMinimum == Vector3(x: 2.0'f32, y: 4.0'f32, z: 6.0'f32)
    check model.joints[1].positionMaximum == Vector3(x: 8.0'f32, y: 10.0'f32, z: 12.0'f32)

suite "F09 mirror_mesh":
  test "mirroredVertex keeps edge scale, extra UVs, and reflects SDEF":
    let source = newVertex(
      position = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32),
      normal = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
      uv = Vector2(x: 0.25'f32, y: 0.5'f32),
      additionalUv = @[Vector4(x: 0.1'f32, y: 0.2'f32, z: 0.3'f32, w: 0.4'f32)],
      weightDeform = newSDEF(
        boneIndex1 = 0'i32,
        boneIndex2 = 1'i32,
        c = Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32),
        r0 = Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.5'f32),
        r1 = Vector3(x: 2.0'f32, y: 1.0'f32, z: -0.5'f32)
      ),
      edgeScale = 0.25'f32
    )
    let mirrored = mirroredVertex(source)
    check mirrored.edgeScale == 0.25'f32
    check mirrored.additionalUv == source.additionalUv
    check mirrored.position == Vector3(x: -1.0'f32, y: 2.0'f32, z: 3.0'f32)
    check mirrored.normal == Vector3(x: -1.0'f32, y: 0.0'f32, z: 0.0'f32)
    check mirrored.uv == Vector2(x: 0.75'f32, y: 0.5'f32)
    check mirrored.weightDeform.sdef.c == Vector3(x: -1.0'f32, y: 2.0'f32, z: 3.0'f32)
    check mirrored.weightDeform.sdef.r0 == Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.5'f32)
    check mirrored.weightDeform.sdef.r1 == Vector3(x: -2.0'f32, y: 1.0'f32, z: -0.5'f32)

  test "a static model mirrors into a valid file":
    let model = staticModel()
    mirrorMesh(model)
    check model.vertices.len == 6
    check model.faces.len == 2
    check model.materials.len == 2
    check model.faces[1].vertexIndex1 == model.faces[0].vertexIndex3 + 3'i32
    check model.faces[1].vertexIndex3 == model.faces[0].vertexIndex1 + 3'i32
    let appended = model.vertices[3]
    check appended.edgeScale == 0.25'f32
    check appended.additionalUv.len == 1
    check appended.position.x == 1.0'f32
    validate(model)
    check readPmx(writePmx(model)).vertices.len == 6

  test "a rigged model is refused before anything is appended":
    let model = newPmxModel(
      nameJA = "rigged",
      vertices = @[newVertex(position = Vector3.zero)],
      bones = @[newBone(nameJA = "root")]
    )
    expect ValueError:
      mirrorMesh(model)
    check model.vertices.len == 1

suite "R05 downgrade material modes":
  test "sub-texture sphere blending survives a 2.1 to 2.0 conversion":
    ## `sbmSubTexture` is part of PMX 2.0 (it needs one extra UV channel), so the
    ## downgrade must not clear it.
    let model = newPmxModel(
      version = pmx21,
      additionalUvCount = 1'i32,
      materials = @[newMaterial(sphereBlendMode = sbmSubTexture)]
    )
    var changes: seq[Change] = @[]
    convertMaterials(model, changes)
    check model.materials[0].sphereBlendMode == sbmSubTexture
    check changes.len == 0

  test "PMX 2.1-only material flags are still cleared":
    let model = newPmxModel(
      materials = @[newMaterial(flags = MaterialFlags(vertexColor: true, pointDraw: true))]
    )
    var changes: seq[Change] = @[]
    convertMaterials(model, changes)
    check not model.materials[0].flags.vertexColor
    check not model.materials[0].flags.pointDraw
    check changes.len == 1

suite "R06 downgrade joints":
  test "a ConeTwist joint is reported instead of being silently retagged":
    ## Retagging would reinterpret span angles as lower/upper bounds.
    let model = newPmxModel(
      joints = @[
        newJoint(
          nameJA = "cone",
          jointType = jtConeTwist,
          rotationMinimum = Vector3(x: 0.5'f32, y: 0.5'f32, z: 0.5'f32)
        )
      ]
    )
    var changes: seq[Change] = @[]
    let blocked = convertJoints(model, changes, false)
    check blocked.len == 1
    check "cone" in blocked[0]
    check model.joints[0].jointType == jtConeTwist
    check changes.len == 0

  test "dropping unsupported joints is explicit and reported":
    let model = newPmxModel(
      joints = @[newJoint(nameJA = "hinge", jointType = jtHinge)]
    )
    var changes: seq[Change] = @[]
    let blocked = convertJoints(model, changes, true)
    check blocked.len == 0
    check model.joints.len == 0
    check changes.len == 1

  test "a spring 6DOF joint needs no conversion":
    let model = newPmxModel(joints = @[newJoint(nameJA = "spring")])
    var changes: seq[Change] = @[]
    check convertJoints(model, changes, false).len == 0
    check model.joints.len == 1
    check changes.len == 0

suite "R07 export material identifiers":
  test "distinct PMX names stay distinct after sanitizing":
    let first = newMaterial(nameJA = "a b")
    let second = newMaterial(nameJA = "a_b")
    check materialName(0, first) != materialName(1, second)
    check materialName(0, first).startsWith("material_0_")
    check materialName(1, second).startsWith("material_1_")

  test "duplicate PMX names still produce unique identifiers":
    let first = newMaterial(nameJA = "skin")
    let second = newMaterial(nameJA = "skin")
    check materialName(0, first) != materialName(1, second)

suite "R10 texture pruning":
  test "unused textures are removed and references remapped":
    let model = newPmxModel(
      textures = @[newTexture("unused.png"), newTexture("skin.png")],
      materials = @[newMaterial(textureIndex = 1'i32)]
    )
    let summary = fixPaths(model)
    check summary.removed == 1
    check summary.merged == 0
    check model.textures.len == 1
    check model.textures[0].path == "skin.png"
    check model.materials[0].textureIndex == 0

  test "duplicates are merged and every reference follows":
    let model = newPmxModel(
      textures = @[newTexture("a\\skin.png"), newTexture("a/skin.png")],
      materials = @[newMaterial(textureIndex = 0'i32, sphereTextureIndex = 1'i32)]
    )
    let summary = fixPaths(model)
    check summary.merged == 1
    check summary.removed == 0
    check model.textures.len == 1
    check model.textures[0].path == "a/skin.png"
    check model.materials[0].textureIndex == 0
    check model.materials[0].sphereTextureIndex == 0

  test "a duplicate that is still referenced keeps the merged texture alive":
    ## Usage is resolved through the deduplication map, so referencing only the second
    ## copy must not leave the merged texture unused.
    let model = newPmxModel(
      textures = @[newTexture("skin.png"), newTexture("skin.png")],
      materials = @[newMaterial(textureIndex = 1'i32)]
    )
    let summary = fixPaths(model)
    check summary.merged == 1
    check summary.removed == 0
    check model.textures.len == 1
    check model.materials[0].textureIndex == 0

suite "inspect texture paths":
  test "a relative texture next to the model is accepted":
    let model = newPmxModel()
    model.directory = getTempDir()
    let resolved = resolveTexture(model, "skin.png")
    check resolved.len > 0
    check resolved.endsWith("skin.png")

  test "parent-directory and absolute textures are refused":
    let model = newPmxModel()
    model.directory = getTempDir()
    check resolveTexture(model, "../secret.png").len == 0
    check resolveTexture(model, "tex/../../secret.png").len == 0
    check resolveTexture(model, "/etc/passwd").len == 0
    check resolveTexture(model, "C:\\Windows\\win.ini").len == 0

suite "export_obj material paths":
  test "control characters cannot break an MTL line":
    check mtlTexturePath("skin.png") == "skin.png"
    check '\n' notin mtlTexturePath("a\nb")
    check '\r' notin mtlTexturePath("a\rb")
    check '\t' notin mtlTexturePath("a\tb")
    check '\x00' notin mtlTexturePath("a\x00b")

suite "add_box":
  test "an empty model gets 24 vertices, 12 triangles, and a material":
    let model = newPmxModel(nameJA = "empty")
    let index = appendBox(model, Vector3.zero, 1.0'f32, -1'i32)
    check index == 0
    check model.vertices.len == 24
    check model.faces.len == 12
    check model.materials.len == 1
    check model.materials[0].faceCount == 12
    check model.vertices[0].weightDeform.bdef1.boneIndex1 == -1
    validate(model)

  test "a boxed sample stays valid and keeps the original mesh":
    let model = sampleModel()
    let verts = model.vertices.len
    let faces = model.faces.len
    discard appendBox(model, meshCenter(model), 0.25'f32, 0'i32)
    check model.vertices.len == verts + 24
    check model.faces.len == faces + 12
    validate(model)

suite "add_bone_chain":
  test "bones stack from the mesh top and parent in order":
    let model = sampleModel()
    let first = model.bones.len
    let added = addChain(model, 3, 0.1'f32)
    check added == @[int32(first), int32(first + 1), int32(first + 2)]
    check model.bones[first].parentBoneIndex == 0
    check model.bones[first + 1].parentBoneIndex == int32(first)
    check model.bones[first + 2].parentBoneIndex == int32(first + 1)
    check model.bones[first + 1].position.y > model.bones[first].position.y
    validate(model)

suite "add_morphs":
  test "blink and tint morphs register on the Expressions slot":
    let model = sampleModel()
    let first = model.morphs.len
    model.morphs.add blinkMorph(2'i32, 3'i32, 0.05'f32)
    model.morphs.add tintMorph(0'i32)
    register(model, first, 2)
    check model.morphs[first].morphType == mtVertex
    check model.morphs[first].offsetData.len == 2
    check model.morphs[first + 1].morphType == mtMaterial
    var found = false
    for slot in model.displayFrames:
      if slot.nameJA.toLowerAscii == "expressions":
        check slot.frames[^1].targetIndex == int32(first + 1)
        found = true
    check found
    validate(model)

suite "add_physics":
  test "one body per remaining bone and a joint between neighbours":
    let model = sampleModel()
    let bodies = model.rigidBodies.len
    let joints = model.joints.len
    let added = addPhysics(model, int32(model.bones.len - 2))
    check added.bodies == 2
    check added.joints == 1
    check model.rigidBodies.len == bodies + 2
    check model.joints.len == joints + 1
    check model.joints[^1].rigidBodyIndexB == int32(model.rigidBodies.len - 1)
    validate(model)

suite "batch_repair":
  test "a valid file is left alone and a broken file is repaired":
    let folder = getTempDir() / ("pmxforge-batch-" & $getCurrentProcessId())
    createDir(folder)
    let output = folder / "out"
    createDir(output)
    let goodPath = folder / "good.pmx"
    let badPath = folder / "bad.pmx"
    writePmx(sampleModel(), goodPath)
    writeFile(badPath, "not a pmx")
    let good = repairOne(goodPath, output)
    let bad = repairOne(badPath, output)
    check good.outcome == outcomeValid
    check bad.outcome == outcomeUnreadable
    check not fileExists(output / "good.pmx")

  test "dangling references are repaired onto disk":
    let folder = getTempDir() / ("pmxforge-batch-fix-" & $getCurrentProcessId())
    createDir(folder)
    let output = folder / "out"
    createDir(output)
    let path = folder / "broken.pmx"
    writePmx(damagedModel(), path, mode = pwmLenient)
    let report = repairOne(path, output)
    check report.outcome == outcomeRepaired
    check fileExists(output / "broken.pmx")
    check readPmx(output / "broken.pmx").isValid()

suite "build_ik":
  test "the driver bone gets one limited link to the effector":
    let model = sampleModel()
    buildIk(model, 0'i32, 2'i32, 0.5'f32, 40'i32)
    check model.bones[0].flags.ik
    check model.bones[0].ik.targetIndex == 2
    check model.bones[0].ik.links.len == 1
    check model.bones[0].ik.links[0].boneIndex == 1
    check model.bones[0].ik.loopCount == 40
    validate(model)

suite "convert_encoding":
  test "utf8 and utf16 names parse, junk is refused":
    check parseEncoding("utf-8") == teUTF8
    check parseEncoding("UTF16LE") == teUTF16LE
    expect ValueError:
      discard parseEncoding("latin1")

  test "switching encoding keeps names after a write round trip":
    let model = sampleModel()
    model.textEncoding = teUTF16LE
    let utf16 = writePmx(model)
    model.textEncoding = teUTF8
    let utf8 = writePmx(model)
    check readPmx(utf16).textEncoding == teUTF16LE
    check readPmx(utf8).textEncoding == teUTF8
    check readPmx(utf8).nameJA == readPmx(utf16).nameJA

suite "convert_skinning":
  test "SDEF vertices become BDEF2 with the same bones and weight":
    let model = newPmxModel(
      vertices = @[
        newVertex(
          weightDeform = newSDEF(
            boneIndex1 = 0'i32,
            boneIndex2 = 1'i32,
            boneWeight1 = 0.7'f32,
            c = Vector3.zero
          )
        )
      ],
      bones = @[newBone(nameJA = "a"), newBone(nameJA = "b")]
    )
    check convertSdef(model) == 1
    check model.vertices[0].weightDeform.kind == dkBDEF2
    check model.vertices[0].weightDeform.bdef2.boneIndex1 == 0
    check model.vertices[0].weightDeform.bdef2.boneIndex2 == 1
    check model.vertices[0].weightDeform.bdef2.boneWeight1 == 0.7'f32
    validate(model)

suite "fill_names":
  test "empty English fields copy Japanese, filled ones stay":
    let model = newPmxModel(nameJA = "モデル", nameEN = "")
    model.materials.add newMaterial(nameJA = "肌", nameEN = "skin")
    let changes = fillNames(model)
    check model.nameEN == "モデル"
    check model.materials[0].nameEN == "skin"
    check changes["model name"] == 1
    check not ("material" in changes)

suite "flip_faces":
  test "every triangle reverses its first and third corners":
    let model = staticModel()
    check flipFaces(model) == 1
    check model.faces[0].vertexIndex1 == 2
    check model.faces[0].vertexIndex2 == 1
    check model.faces[0].vertexIndex3 == 0
    validate(model)

suite "make_sample":
  test "the generated cloth plane is a valid PMX 2.1 document":
    let model = makeModel()
    check model.vertices.len == 25
    check model.faces.len == 32
    check model.bones.len == 4
    check isPmx21Only(model)
    validate(model)

suite "recompute_normals":
  test "a triangle on the XY plane gets a +Z normal":
    let model = staticModel()
    for vertex in model.vertices:
      vertex.normal = Vector3.up
    let summary = recompute(model)
    check summary.changed == 3
    for vertex in model.vertices:
      check vertex.normal.z > 0.9'f32
    validate(model)

suite "rename_model":
  test "an empty name is refused":
    let model = sampleModel()
    expect ValueError:
      discard renameModel(model, "")
    check model.nameJA == sampleModel().nameJA

  test "Japanese and English names follow the new title":
    let model = sampleModel()
    let previous = renameModel(model, "prop")
    check previous.len > 0
    check model.nameJA == "prop"
    check model.nameEN == "prop"
    check "Renamed from" in model.commentsEN
    validate(model)

suite "retint_materials":
  test "colours scale, alpha is set, and a zero edge turns the outline off":
    let model = sampleModel()
    model.materials[0].diffuseColor = RGB(r: 1.0'f32, g: 1.0'f32, b: 1.0'f32)
    check retint(model, 0.5'f32, 0.8'f32, 0.0'f32) == 1
    check model.materials[0].diffuseColor.r == 0.5'f32
    check model.materials[0].alpha == 0.8'f32
    check model.materials[0].edgeScale == 0.0'f32
    check not model.materials[0].flags.edge
    validate(model)

suite "sanitize_bytes":
  test "dangling references come back as a valid buffer":
    let received = damagedBytes()
    check not isValid(readPmx(received))
    let cleaned = sanitize(received)
    check cleaned.clean.len > 0
    check "repaired" in cleaned.problem
    check isValid(readPmx(cleaned.clean))

suite "setup_soft_body":
  test "the first grid row is pinned and anchored to the first rigid body":
    let model = sampleModel()
    let pins = rowVertices(model, 0, 1)
    check pins.len == 2
    model.softBodies = @[buildSoftBody(model, pins)]
    check model.softBodies[0].vertexPins == pins
    check model.softBodies[0].anchorRigidBodies.len == pins.len
    check model.softBodies[0].anchorRigidBodies[0].rigidBodyIndex == 0
    validate(model)

suite "soften_weights":
  test "a BDEF1 vertex blends with its parent bone":
    let model = newPmxModel(
      vertices = @[newVertex(weightDeform = newBDEF1(1'i32))],
      bones = @[newBone(nameJA = "root"), newBone(nameJA = "child", parentBoneIndex = 0'i32)]
    )
    check soften(model, 0.25'f32) == 1
    check model.vertices[0].weightDeform.kind == dkBDEF2
    check model.vertices[0].weightDeform.bdef2.boneIndex1 == 1
    check model.vertices[0].weightDeform.bdef2.boneIndex2 == 0
    check model.vertices[0].weightDeform.bdef2.boneWeight1 == 0.75'f32
    validate(model)

suite "split_material":
  test "face counts split in half and later material morphs shift":
    let model = sampleModel()
    model.materials[0].faceCount = 2
    model.morphs.add tintMorph(0'i32)
    let inserted = splitMaterial(model, 0, 0'i32)
    check model.materials.len == 2
    check model.materials[0].faceCount + inserted.faceCount == 2
    check model.materials[1].nameJA.endsWith("_b")
    check model.morphs[^1].offsetData[0].material.materialIndex == 0
    validate(model)

  test "a morph aimed at the next material moves with the insert":
    let model = newPmxModel(
      faces = @[newFace(0'i32, 1'i32, 2'i32), newFace(0'i32, 2'i32, 3'i32)],
      vertices = @[newVertex(), newVertex(), newVertex(), newVertex()],
      materials = @[
        newMaterial(nameJA = "a", faceCount = 2'i32),
        newMaterial(nameJA = "b", faceCount = 0'i32)
      ],
      morphs = @[tintMorph(1'i32)]
    )
    discard splitMaterial(model, 0, -1'i32)
    check model.materials.len == 3
    check model.morphs[0].offsetData[0].material.materialIndex == 2
    validate(model)

suite "stats_csv":
  test "a quoted filename survives commas and the valid flag is present":
    let model = sampleModel()
    let line = row(model, "dir/a,b.pmx")
    check line.startsWith("\"a,b.pmx\",")
    check line.endsWith(",true")
    check Header.startsWith("file,version")

suite "strip_physics":
  test "rigid bodies, joints, and soft bodies are cleared":
    let model = sampleModel()
    check model.rigidBodies.len > 0
    let removed = stripPhysics(model)
    check removed.bodies > 0
    check model.rigidBodies.len == 0
    check model.joints.len == 0
    check model.softBodies.len == 0
    validate(model)
