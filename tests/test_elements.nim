## Element constructors and invariants.
##
## Provides checks that every constructor rejects bad input, that copies stay independent, and that repair
## normalizes broken references.

import std/unittest
import pmxforge

suite "vertex":
  test "newVertex fills in usable defaults":
    ## A bare vertex must already be valid and unbound.
    let vertex = newVertex()
    check vertex.isValid()
    check vertex.weightDeform.kind == dkBDEF1
    check vertex.weightDeform.bdef1.boneIndex1 == -1'i32
    check vertex.edgeScale == 1.0'f32

  test "newVertex binds to a single bone":
    ## The four-argument overload builds BDEF1 skinning.
    let vertex = newVertex(
      Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32), Vector3.up, Vector2(x: 0.25'f32, y: 0.75'f32), 2'i32)
    check vertex.position == Vector3(x: 1.0'f32, y: 2.0'f32, z: 3.0'f32)
    check vertex.uv == Vector2(x: 0.25'f32, y: 0.75'f32)
    check vertex.weightDeform.getBoneIndices() == @[2'i32]

  test "newVertex refuses non-finite values":
    ## A NaN position cannot be encoded, so construction fails early.
    expect ValueError:
      discard newVertex(position = Vector3(x: NaN, y: 0.0'f32, z: 0.0'f32))

  test "newVertex refuses more than four UV channels":
    ## The header stores the extra UV count in a single byte.
    expect ValueError:
      discard newVertex(
        additionalUv = @[Vector4.zero, Vector4.zero, Vector4.zero, Vector4.zero, Vector4.zero]
      )

suite "skinning":
  test "weights always add up to one":
    ## BDEF2 stores the first weight and derives the second.
    let deform = newBDEF2(boneIndex1 = 0'i32, boneIndex2 = 1'i32, boneWeight1 = 0.25'f32)
    let weights = deform.getWeights()
    check weights.len == 2
    check abs(weights[0] - 0.25'f32) < 1.0e-6'f32
    check abs(weights[1] - 0.75'f32) < 1.0e-6'f32

  test "BDEF2 rejects weights above one":
    ## Out-of-range weights are a constructor error, not a silent clamp.
    expect ValueError:
      discard newBDEF2(boneIndex1 = 0'i32, boneIndex2 = 1'i32, boneWeight1 = 1.5'f32)

  test "QDEF is marked as PMX 2.1 only":
    ## Dual-quaternion skinning does not exist in PMX 2.0.
    check newQDEF(0'i32, 1'i32, 2'i32, 3'i32).isPmx21Only
    check not newSDEF(0'i32, 1'i32).isPmx21Only

  test "SDEF keeps its correction vectors":
    ## The three SDEF vectors travel with the deform payload.
    let deform = newSDEF(
      boneIndex1 = 0'i32,
      boneIndex2 = 1'i32,
      c = Vector3.up,
      r0 = Vector3.right,
      r1 = Vector3.forward
    )
    check deform.sdef.c == Vector3.up
    check deform.sdef.r0 == Vector3.right
    check deform.sdef.r1 == Vector3.forward

  test "repair resets out-of-range bone indices":
    ## Repairing against one bone drops references that no longer fit.
    let vertex = newVertex(Vector3.zero, Vector3.up, Vector2.zero, 7'i32)
    check not vertex.isValid(boneCount = 1'i32)
    vertex.repair(boneCount = 1'i32)
    check vertex.weightDeform.bdef1.boneIndex1 == -1'i32
    check vertex.isValid(boneCount = 1'i32)

suite "faces":
  test "newFace keeps the winding order":
    ## Indices are stored as given, without reordering.
    let face = newFace(2'i32, 1'i32, 0'i32)
    check face.getIndices() == [2'i32, 1'i32, 0'i32]
    check face.containsVertex(1'i32)
    check not face.containsVertex(3'i32)

  test "newFace rejects negative indices":
    ## Vertex references are unsigned in the file format.
    expect ValueError:
      discard newFace(-1'i32, 0'i32, 0'i32)

  test "repair clamps negative indices to zero, not a tombstone":
    ## Vertex indices are unsigned on the wire; -1 is not a legal corner.
    let face = Face(vertexIndex1: -1'i32, vertexIndex2: 1'i32, vertexIndex3: 2'i32)
    face.repair(vertexCount = 3'i32)
    check face.vertexIndex1 == 0'i32
    check face.vertexIndex2 == 1'i32
    check face.vertexIndex3 == 2'i32
    check face.isValid(vertexCount = 3'i32)

  test "repair leaves out-of-range corners encodable":
    ## Isolated repair must not produce a face the writer rejects.
    let face = newFace(0'i32, 1'i32, 9'i32)
    check not face.isValid(vertexCount = 3'i32)
    face.repair(vertexCount = 3'i32)
    check face.vertexIndex3 == 9'i32
    check not face.isValid(vertexCount = 3'i32)

suite "materials":
  test "newMaterial starts opaque and untextured":
    ## Defaults match a plain diffuse material.
    let material = newMaterial(nameJA = "skin")
    check material.isValid()
    check material.alpha == 1.0'f32
    check material.textureIndex == -1'i32
    check material.sphereBlendMode == sbmDisabled

  test "copy does not share state with the original":
    ## Editing a copy must leave the source untouched.
    let original = newMaterial(nameJA = "skin", alpha = 1.0'f32)
    let clone = original.copy()
    clone.nameJA = "armor"
    clone.alpha = 0.5'f32
    clone.flags.edge = true
    check original.nameJA == "skin"
    check original.alpha == 1.0'f32
    check not original.flags.edge
    check clone.nameJA == "armor"

suite "bones":
  test "newBone defaults to a visible root":
    ## The default flags keep the bone selectable in an editor.
    let bone = newBone(nameJA = "root")
    check bone.isValid()
    check bone.parentBoneIndex == -1'i32
    check bone.flags.rotatable
    check bone.flags.visible
    check not bone.hasParent()

  test "newBone rejects parents below the null sentinel":
    ## -1 means no parent; anything smaller is meaningless.
    expect ValueError:
      discard newBone(nameJA = "root", parentBoneIndex = -2'i32)

  test "newBoneTail connects to another bone":
    ## The connection flag switches the tail from an offset to an index.
    let bone = newBoneTail(nameJA = "spine", tailIndex = 0'i32)
    check bone.flags.connection
    check bone.hasTailBone()

  test "IK links reject inverted limits":
    ## Minimums above maximums cannot be stored.
    expect ValueError:
      discard newLimitedIKLink(
        boneIndex = 0'i32,
        limitMin = Vector3(x: 1.0'f32, y: 0.0'f32, z: 0.0'f32),
        limitMax = Vector3(x: 0.0'f32, y: 0.0'f32, z: 0.0'f32)
      )

  test "newBoneIK rejects a non-positive loop count":
    ## The solver must run at least once per frame.
    expect ValueError:
      discard newBoneIK(targetIndex = 1'i32, loopCount = 0'i32)

suite "morphs":
  test "newMorph keeps the panel and offset kind in step":
    ## A morph type maps onto exactly one offset variant.
    let morph = newMorph(nameJA = "smile", morphType = mtVertex, panelType = mptMouth)
    check morph.isValid()
    check getExpectedMorphOffsetKind(mtVertex) == moVertex
    check getExpectedMorphOffsetKind(mtUVExt2) == moUV
    check getExpectedMorphOffsetKind(mtFlip) == moFlip

  test "unknown morph types are refused":
    ## Enum fields are part of the wire format and must stay in range.
    expect ValueError:
      discard newMorph(nameJA = "broken", morphType = cast[MorphType](99))

  test "only flip and impulse morphs need PMX 2.1":
    ## Everything else exists in version 2.0 as well.
    check newMorph(nameJA = "flip", morphType = mtFlip).isPmx21Only
    check newMorph(nameJA = "impulse", morphType = mtImpulse).isPmx21Only
    check not newMorph(nameJA = "smile", morphType = mtVertex).isPmx21Only

suite "flags":
  test "bone flags survive a round trip through the wire mask":
    ## Packing and unpacking must be lossless.
    let flags = BoneFlags(
      connection: true,
      rotatable: true,
      ik: true,
      inheritRotation: true,
      afterPhysicsDeform: true
    )
    check toBoneFlags(flags.toMask) == flags

  test "material flags survive a round trip through the wire mask":
    ## The same holds for the material render flags.
    let flags = MaterialFlags(bothFace: true, edge: true, vertexColor: true)
    check toMaterialFlags(flags.toMask) == flags

  test "collision masks survive a round trip through the wire mask":
    ## Group 1 and 16 sit at the ends of a 16-bit field.
    var mask = CollisionMask()
    mask.group1 = true
    mask.group16 = true
    check toCollisionMask(mask.toMask) == mask

  test "reserved bits are dropped, not guessed":
    ## Bit 6 has no meaning in a PMX bone flag field.
    let flags = toBoneFlags(1 shl 6)
    check not flags.rotatable
    check not flags.visible
    check flags.toMask == 0

  test "values that do not fit the field are rejected":
    ## The flag fields are 16, 8, and 16 bits wide.
    expect ValueError:
      discard toBoneFlags(0x10000)
    expect ValueError:
      discard toBoneFlags(-1)
    expect ValueError:
      discard toMaterialFlags(0x100)
    expect ValueError:
      discard toCollisionMask(-1)

suite "display slots":
  test "frames carry their target type":
    ## Bone and morph frames stay distinguishable.
    check newBoneDisplayFrame(3'i32).frameType == dftBone
    check newMorphDisplayFrame(3'i32).frameType == dftMorph
    check newBoneDisplayFrame(3'i32).targetIndex == 3'i32

  test "newDisplayFrame rejects targets below the null sentinel":
    ## -1 is the unbound marker, so -2 is invalid.
    expect ValueError:
      discard newDisplayFrame(dftBone, -2'i32)

suite "physics":
  test "newRigidBody validates its target bone":
    ## A body must either be unbound or point at a real bone.
    expect ValueError:
      discard newRigidBody(nameJA = "body", relatedBoneIndex = -2'i32)

  test "newJoint validates both body indices":
    ## Joints connect two rigid bodies, and -1 is the null sentinel.
    expect ValueError:
      discard newJoint(nameJA = "joint", rigidBodyIndexA = -2'i32)
    expect ValueError:
      discard newJoint(nameJA = "joint", rigidBodyIndexB = -2'i32)

  test "only the spring joint exists in PMX 2.0":
    ## Every other constraint type arrived with version 2.1.
    check not isPmx21Only(jtSpring6DOF)
    check isPmx21Only(jtHinge)
    check isPmx21Only(newJoint(nameJA = "hinge", jointType = jtHinge))

  test "newSoftBody validates its material index":
    ## Soft bodies without a material use the -1 sentinel.
    expect ValueError:
      discard newSoftBody(nameJA = "cloth", materialIndex = -2'i32)

  test "soft-body defaults are finite":
    ## The Bullet coefficients come from a validated factory.
    let config = newSoftBodyConfig()
    check config.vcf == 1.0'f32
    check config.df == 1.0'f32
    expect ValueError:
      discard newSoftBodyConfig(dp = NaN)

suite "textures":
  test "newTexture stores the path as given":
    ## Paths are kept verbatim so relative references survive.
    let texture = newTexture("textures\\skin.png")
    check not texture.isEmpty()
    check texture.path == "textures\\skin.png"
    check newTexture("").isEmpty()
