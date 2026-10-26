## Shared fixtures for the test suites.
##
## Provides one complete PMX 2.1 model, a damaged variant of it, and the byte-level helpers the
## malformed-input suites need.

import pmxforge

proc sampleModel*(): PmxModel =
  ## Builds a fresh model that touches every element section of the format.
  let bottomLeft = newVertex(
    Vector3(x: -0.5'f32, y: 0.0'f32, z: 0.0'f32), Vector3.up, Vector2(x: 0.0'f32, y: 0.0'f32), 0'i32)
  let bottomRight = newVertex(
    Vector3(x: 0.5'f32, y: 0.0'f32, z: 0.0'f32), Vector3.up, Vector2(x: 1.0'f32, y: 0.0'f32), 0'i32)
  let topRight = newVertex(
    Vector3(x: 0.5'f32, y: 1.0'f32, z: 0.0'f32), Vector3.up, Vector2(x: 1.0'f32, y: 1.0'f32), 0'i32)
  let topLeft = newVertex(
    Vector3(x: -0.5'f32, y: 1.0'f32, z: 0.0'f32), Vector3.up, Vector2(x: 0.0'f32, y: 1.0'f32), 0'i32)

  let skin = newMaterial(
    nameJA = "skin",
    nameEN = "skin",
    diffuseColor = RGB.white,
    flags = MaterialFlags(bothFace: true, groundShadow: true, edge: true),
    edgeColor = RGBA.black,
    textureIndex = 0'i32,
    faceCount = 2'i32
  )

  let root = newBone(nameJA = "root", nameEN = "root")
  let spine = newBone(
    nameJA = "spine",
    nameEN = "spine",
    position = Vector3(x: 0.0'f32, y: 0.5'f32, z: 0.0'f32),
    parentBoneIndex = 0'i32
  )
  let hand = newBone(
    nameJA = "hand",
    nameEN = "hand",
    position = Vector3(x: 0.5'f32, y: 1.0'f32, z: 0.0'f32),
    parentBoneIndex = 1'i32
  )

  let smile = newMorph(
    nameJA = "smile",
    nameEN = "smile",
    morphType = mtVertex,
    panelType = mptMouth,
    offsetData = @[
      MorphOffset(
        kind: moVertex,
        vertex: VertexMorphOffset(
          vertexIndex: 2'i32,
          translation: Vector3(x: 0.0'f32, y: 0.1'f32, z: 0.0'f32)
        )
      )
    ]
  )
  let smileGroup = newMorph(
    nameJA = "smile group",
    nameEN = "smile group",
    morphType = mtGroup,
    panelType = mptOther,
    offsetData = @[
      MorphOffset(kind: moGroup, group: GroupMorphOffset(morphIndex: 0'i32, influence: 0.5'f32))
    ]
  )
  let tint = newMorph(
    nameJA = "tint",
    nameEN = "tint",
    morphType = mtMaterial,
    panelType = mptOther,
    offsetData = @[
      MorphOffset(
        kind: moMaterial,
        material: MaterialMorphOffset(
          materialIndex: 0'i32,
          blendMode: mmbMultiply,
          diffuseColor: RGBA.white
        )
      )
    ]
  )
  let pose = newMorph(
    nameJA = "pose",
    nameEN = "pose",
    morphType = mtBone,
    panelType = mptOther,
    offsetData = @[
      MorphOffset(
        kind: moBone,
        bone: BoneMorphOffset(
          boneIndex: 1'i32,
          translation: Vector3(x: 0.0'f32, y: 0.1'f32, z: 0.0'f32),
          rotation: Quaternion.identity
        )
      )
    ]
  )
  let shift = newMorph(
    nameJA = "shift",
    nameEN = "shift",
    morphType = mtUV,
    panelType = mptOther,
    offsetData = @[
      MorphOffset(
        kind: moUV,
        uv: UVMorphOffset(
          vertexIndex: 0'i32,
          floats: Vector4(x: 0.1'f32, y: 0.0'f32, z: 0.0'f32, w: 0.0'f32)
        )
      )
    ]
  )

  let rootSlot = newDisplaySlot(
    nameJA = "Root",
    specialFlag = true,
    frames = @[newBoneDisplayFrame(0'i32), newBoneDisplayFrame(1'i32), newBoneDisplayFrame(2'i32)]
  )
  let expressionSlot = newDisplaySlot(
    nameJA = "Expressions",
    frames = @[
      newMorphDisplayFrame(0'i32),
      newMorphDisplayFrame(1'i32),
      newMorphDisplayFrame(2'i32),
      newMorphDisplayFrame(3'i32),
      newMorphDisplayFrame(4'i32)
    ]
  )

  let body0 = newRigidBody(
    nameJA = "body",
    nameEN = "body",
    relatedBoneIndex = 0'i32,
    shape = rbsBox,
    shapeSize = Vector3(x: 0.5'f32, y: 0.5'f32, z: 0.1'f32),
    physicsMode = pmFollowBone
  )
  let body1 = newRigidBody(
    nameJA = "hand",
    nameEN = "hand",
    relatedBoneIndex = 2'i32,
    groupId = 2'i32,
    shape = rbsCapsule,
    shapeSize = Vector3(x: 0.1'f32, y: 0.4'f32, z: 0.0'f32),
    mass = 0.5'f32,
    physicsMode = pmPhysics
  )

  let joint0 = newJoint(
    nameJA = "hand joint",
    nameEN = "hand joint",
    rigidBodyIndexA = 0'i32,
    rigidBodyIndexB = 1'i32,
    position = Vector3(x: 0.0'f32, y: 0.5'f32, z: 0.0'f32),
    positionSpring = Vector3(x: 1.0'f32, y: 1.0'f32, z: 1.0'f32)
  )

  let cloth = newSoftBody(
    nameJA = "cloth",
    nameEN = "cloth",
    materialIndex = 0'i32,
    numberOfClusters = 1'i32,
    totalMass = 1.0'f32,
    anchorRigidBodies = @[AnchorRigidBody(rigidBodyIndex: 0'i32, vertexIndex: 3'i32)],
    vertexPins = @[0'i32, 3'i32]
  )

  result = newPmxModel(
    nameJA = "sample",
    nameEN = "sample",
    commentsJA = "テスト用モデル",
    commentsEN = "A model used by the PMX Forge test suites.",
    version = pmx21,
    textEncoding = teUTF8,
    directory = "",
    vertices = @[bottomLeft, bottomRight, topRight, topLeft],
    faces = @[newFace(0'i32, 1'i32, 2'i32), newFace(0'i32, 2'i32, 3'i32)],
    textures = @[newTexture("textures/skin.png")],
    materials = @[skin],
    bones = @[root, spine, hand],
    morphs = @[smile, smileGroup, tint, pose, shift],
    displayFrames = @[rootSlot, expressionSlot],
    rigidBodies = @[body0, body1],
    joints = @[joint0],
    softBodies = @[cloth]
  )

proc damagedModel*(): PmxModel =
  ## Returns the sample model with dangling references and a negative edge scale.
  result = sampleModel()
  result.bones[0].parentBoneIndex = 42'i32
  result.materials[0].textureIndex = 9'i32
  result.vertices[0].edgeScale = -1.0'f32

proc tinyModel*(position: Vector3): PmxModel =
  ## Returns a one-vertex model, which is enough to locate a float on the wire.
  result = newPmxModel(
    nameJA = "tiny",
    vertices = @[newVertex(position = position)],
    bones = @[newBone(nameJA = "root")]
  )

proc modelBytes*(model: PmxModel): seq[byte] =
  ## Serializes a model with the default write limits.
  result = writePmx(model)

proc patched*(data: seq[byte], offset: int, value: byte): seq[byte] =
  ## Returns a copy of `data` with a single byte replaced.
  result = data
  result[offset] = value

proc patched*(data: seq[byte], offset: int, values: openArray[byte]): seq[byte] =
  ## Returns a copy of `data` with a run of bytes replaced.
  result = data
  for i, value in values:
    result[offset + i] = value

proc cropped*(data: seq[byte], count: int): seq[byte] =
  ## Returns a copy of `data` without its last `count` bytes.
  result = data[0 ..< data.len - count]

proc appendU8(data: var seq[byte], value: int) =
  ## Appends one byte to a byte builder.
  data.add byte(value)

proc appendU32(data: var seq[byte], value: uint32) =
  ## Appends one little-endian 32-bit value to a byte builder.
  for shift in [0'u32, 8'u32, 16'u32, 24'u32]:
    data.add byte((value shr shift) and 0xFF'u32)

proc appendZeros(data: var seq[byte], count: int) =
  ## Appends `count` zero bytes to a byte builder.
  for _ in 0 ..< count:
    data.add byte(0)

proc overflowingIkAnglePmx*(): seq[byte] =
  ## Builds a minimal PMX 2.0 file whose only bone has an IK limit angle at the largest
  ## finite float32 radian value. Converting that to degrees exceeds float32, so every
  ## backend has to reject it instead of keeping a wider JavaScript double.
  for character in "PMX ":
    result.add byte(ord(character))
  appendU32(result, 0x40000000'u32)
  for value in [8, 1, 0, 1, 1, 1, 1, 1, 1]:
    appendU8(result, value)
  appendZeros(result, 16)
  appendZeros(result, 16)
  appendU32(result, 1)
  appendZeros(result, 8)
  appendZeros(result, 12)
  appendU8(result, 255)
  appendU32(result, 0)
  appendU8(result, 32)
  appendU8(result, 0)
  appendZeros(result, 12)
  appendU8(result, 255)
  appendU32(result, 1)
  appendU32(result, 0x7F7FFFFF'u32)
  appendU32(result, 0)
  appendZeros(result, 16)
