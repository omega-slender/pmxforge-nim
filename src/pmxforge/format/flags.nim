## Boolean flag views.
##
## Provides `BoneFlags`, `MaterialFlags`, `SoftBodyFlags`, and `CollisionMask`, plus conversion to and
## from their wire bit fields.

type
  BoneFlags* = object ## Bone capabilities and transform flags.
    connection*: bool ## Connects to a target bone instead of an offset.
    rotatable*: bool ## Bone can be rotated.
    translatable*: bool ## Bone can be translated.
    visible*: bool ## Bone is displayed in UI / editor.
    manipulatable*: bool ## Bone can be selected and manipulated by user.
    ik*: bool ## Bone is an inverse kinematics controller.
    inheritLocal*: bool ## Transform inheritance uses local coordinate space.
    inheritRotation*: bool ## Inherits rotation from parent bone.
    inheritTranslation*: bool ## Inherits translation from parent bone.
    fixedAxis*: bool ## Rotation is locked to a fixed directional axis.
    localCoordinate*: bool ## Uses custom local X and Z coordinate axes.
    afterPhysicsDeform*: bool ## Evaluated after physics simulation completes.
    externalParentDeform*: bool ## Inherits transform from an external model bone.

  MaterialFlags* = object ## Material render and shading flags.
    bothFace*: bool ## Disables backface culling (renders both sides).
    groundShadow*: bool ## Casts shadow onto ground plane.
    selfShadowMap*: bool ## Renders into shadow map for self-shadowing.
    selfShadow*: bool ## Receives self-shadows from the model.
    edge*: bool ## Renders pencil/toon outline around geometry.
    vertexColor*: bool ## Uses vertex color (PMX 2.1).
    pointDraw*: bool ## Renders primitives as point cloud (PMX 2.1).
    lineDraw*: bool ## Renders primitives as wireframe lines (PMX 2.1).

  SoftBodyFlags* = object ## Soft body generation flags.
    bLink*: bool ## Generates bending links between vertices.
    cluster*: bool ## Generates cluster constraints.
    hybridLink*: bool ## Links soft body nodes with rigid body anchors.

  CollisionMask* = object ## Collision group disable flags (groups 1 to 16).
    group1*: bool ## Disables collisions with group 1.
    group2*: bool ## Disables collisions with group 2.
    group3*: bool ## Disables collisions with group 3.
    group4*: bool ## Disables collisions with group 4.
    group5*: bool ## Disables collisions with group 5.
    group6*: bool ## Disables collisions with group 6.
    group7*: bool ## Disables collisions with group 7.
    group8*: bool ## Disables collisions with group 8.
    group9*: bool ## Disables collisions with group 9.
    group10*: bool ## Disables collisions with group 10.
    group11*: bool ## Disables collisions with group 11.
    group12*: bool ## Disables collisions with group 12.
    group13*: bool ## Disables collisions with group 13.
    group14*: bool ## Disables collisions with group 14.
    group15*: bool ## Disables collisions with group 15.
    group16*: bool ## Disables collisions with group 16.

const
  bfConnection: int32 = 1 shl 0 ## Bone points at a tail bone instead of an offset.
  bfRotatable: int32 = 1 shl 1 ## Bone can be rotated.
  bfTranslatable: int32 = 1 shl 2 ## Bone can be moved.
  bfVisible: int32 = 1 shl 3 ## Bone is shown in the editor.
  bfManipulatable: int32 = 1 shl 4 ## Bone can be picked and edited.
  bfIK: int32 = 1 shl 5 ## Bone drives an IK chain.
  bfInheritLocal: int32 = 1 shl 7 ## Inheritance works in local axes.
  bfInheritRotation: int32 = 1 shl 8 ## Inherits rotation from another bone.
  bfInheritTranslation: int32 = 1 shl 9 ## Inherits translation from another bone.
  bfFixedAxis: int32 = 1 shl 10 ## Rotation is locked to a fixed axis.
  bfLocalCoordinate: int32 = 1 shl 11 ## Bone uses its own X/Z axes.
  bfAfterPhysicsDeform: int32 = 1 shl 12 ## Deforms after the physics step.
  bfExternalParentDeform: int32 = 1 shl 13 ## Follows a bone from another model.
  validBoneFlags: int32 = 0x3FBF ## Bits this library understands.

  mfBothFace: int32 = 1 shl 0 ## Renders back faces too.
  mfGroundShadow: int32 = 1 shl 1 ## Casts a shadow on the ground.
  mfSelfShadowMap: int32 = 1 shl 2 ## Writes into the shadow map.
  mfSelfShadow: int32 = 1 shl 3 ## Receives the model's own shadows.
  mfEdge: int32 = 1 shl 4 ## Draws the outline edge.
  mfVertexColor: int32 = 1 shl 5 ## Uses vertex colors.
  mfPointDraw: int32 = 1 shl 6 ## Draws vertices as points.
  mfLineDraw: int32 = 1 shl 7 ## Draws faces as wireframe.
  validMaterialFlags: int32 = 0xFF ## Bits this library understands.

  sfBLink: int32 = 1 shl 0 ## Builds distance-preserving links.
  sfCluster: int32 = 1 shl 1 ## Builds cluster constraints.
  sfHybridLink: int32 = 1 shl 2 ## Builds hybrid rigid/soft links.
  validSoftBodyFlags: int32 = 0x07 ## Bits this library understands.

  cgGroup1: int32 = 1 shl 0 ## Collision group 1.
  cgGroup2: int32 = 1 shl 1 ## Collision group 2.
  cgGroup3: int32 = 1 shl 2 ## Collision group 3.
  cgGroup4: int32 = 1 shl 3 ## Collision group 4.
  cgGroup5: int32 = 1 shl 4 ## Collision group 5.
  cgGroup6: int32 = 1 shl 5 ## Collision group 6.
  cgGroup7: int32 = 1 shl 6 ## Collision group 7.
  cgGroup8: int32 = 1 shl 7 ## Collision group 8.
  cgGroup9: int32 = 1 shl 8 ## Collision group 9.
  cgGroup10: int32 = 1 shl 9 ## Collision group 10.
  cgGroup11: int32 = 1 shl 10 ## Collision group 11.
  cgGroup12: int32 = 1 shl 11 ## Collision group 12.
  cgGroup13: int32 = 1 shl 12 ## Collision group 13.
  cgGroup14: int32 = 1 shl 13 ## Collision group 14.
  cgGroup15: int32 = 1 shl 14 ## Collision group 15.
  cgGroup16: int32 = 1 shl 15 ## Collision group 16.
  validCollisionMask: int32 = 0xFFFF ## Bits this library understands.

func toMask*(flags: BoneFlags): int32 =
  ## Packs bone flags into a 16-bit wire integer.
  (if flags.connection: bfConnection else: 0) or
  (if flags.rotatable: bfRotatable else: 0) or
  (if flags.translatable: bfTranslatable else: 0) or
  (if flags.visible: bfVisible else: 0) or
  (if flags.manipulatable: bfManipulatable else: 0) or
  (if flags.ik: bfIK else: 0) or
  (if flags.inheritLocal: bfInheritLocal else: 0) or
  (if flags.inheritRotation: bfInheritRotation else: 0) or
  (if flags.inheritTranslation: bfInheritTranslation else: 0) or
  (if flags.fixedAxis: bfFixedAxis else: 0) or
  (if flags.localCoordinate: bfLocalCoordinate else: 0) or
  (if flags.afterPhysicsDeform: bfAfterPhysicsDeform else: 0) or
  (if flags.externalParentDeform: bfExternalParentDeform else: 0)

func toMask*(flags: MaterialFlags): int32 =
  ## Packs material flags into an 8-bit wire integer.
  (if flags.bothFace: mfBothFace else: 0) or
  (if flags.groundShadow: mfGroundShadow else: 0) or
  (if flags.selfShadowMap: mfSelfShadowMap else: 0) or
  (if flags.selfShadow: mfSelfShadow else: 0) or
  (if flags.edge: mfEdge else: 0) or
  (if flags.vertexColor: mfVertexColor else: 0) or
  (if flags.pointDraw: mfPointDraw else: 0) or
  (if flags.lineDraw: mfLineDraw else: 0)

func toMask*(flags: SoftBodyFlags): int32 =
  ## Packs soft-body flags into an 8-bit wire integer.
  (if flags.bLink: sfBLink else: 0) or
  (if flags.cluster: sfCluster else: 0) or
  (if flags.hybridLink: sfHybridLink else: 0)

func toMask*(mask: CollisionMask): int32 =
  ## Packs collision flags into a 16-bit wire integer.
  (if mask.group1: cgGroup1 else: 0) or
  (if mask.group2: cgGroup2 else: 0) or
  (if mask.group3: cgGroup3 else: 0) or
  (if mask.group4: cgGroup4 else: 0) or
  (if mask.group5: cgGroup5 else: 0) or
  (if mask.group6: cgGroup6 else: 0) or
  (if mask.group7: cgGroup7 else: 0) or
  (if mask.group8: cgGroup8 else: 0) or
  (if mask.group9: cgGroup9 else: 0) or
  (if mask.group10: cgGroup10 else: 0) or
  (if mask.group11: cgGroup11 else: 0) or
  (if mask.group12: cgGroup12 else: 0) or
  (if mask.group13: cgGroup13 else: 0) or
  (if mask.group14: cgGroup14 else: 0) or
  (if mask.group15: cgGroup15 else: 0) or
  (if mask.group16: cgGroup16 else: 0)

func toBoneFlags*(value: int32): BoneFlags {.raises: [ValueError].} =
  ## Unpacks a 16-bit wire integer into `BoneFlags`. Bits the format does not define are
  ## dropped, so a read and write pair is not byte identical for a file that carries them.
  if value < 0 or value > 0xFFFF:
    raise newException(ValueError, "Bone flags do not fit the PMX field.")
  let bits = value and validBoneFlags
  BoneFlags(
    connection: (bits and bfConnection) != 0,
    rotatable: (bits and bfRotatable) != 0,
    translatable: (bits and bfTranslatable) != 0,
    visible: (bits and bfVisible) != 0,
    manipulatable: (bits and bfManipulatable) != 0,
    ik: (bits and bfIK) != 0,
    inheritLocal: (bits and bfInheritLocal) != 0,
    inheritRotation: (bits and bfInheritRotation) != 0,
    inheritTranslation: (bits and bfInheritTranslation) != 0,
    fixedAxis: (bits and bfFixedAxis) != 0,
    localCoordinate: (bits and bfLocalCoordinate) != 0,
    afterPhysicsDeform: (bits and bfAfterPhysicsDeform) != 0,
    externalParentDeform: (bits and bfExternalParentDeform) != 0
  )

func toMaterialFlags*(value: int32): MaterialFlags {.raises: [ValueError].} =
  ## Unpacks an 8-bit wire integer into `MaterialFlags`.
  if value < 0 or value > 0xFF:
    raise newException(ValueError, "Material flags do not fit the PMX field.")
  let bits = value and validMaterialFlags
  MaterialFlags(
    bothFace: (bits and mfBothFace) != 0,
    groundShadow: (bits and mfGroundShadow) != 0,
    selfShadowMap: (bits and mfSelfShadowMap) != 0,
    selfShadow: (bits and mfSelfShadow) != 0,
    edge: (bits and mfEdge) != 0,
    vertexColor: (bits and mfVertexColor) != 0,
    pointDraw: (bits and mfPointDraw) != 0,
    lineDraw: (bits and mfLineDraw) != 0
  )

func toSoftBodyFlags*(value: int32): SoftBodyFlags {.raises: [ValueError].} =
  ## Unpacks an 8-bit wire integer into `SoftBodyFlags`. Bits the format does not define
  ## are dropped, so a read and write pair is not byte identical for a file that carries them.
  if value < 0 or value > 0xFF:
    raise newException(ValueError, "Soft-body flags do not fit the PMX field.")
  let bits = value and validSoftBodyFlags
  SoftBodyFlags(
    bLink: (bits and sfBLink) != 0,
    cluster: (bits and sfCluster) != 0,
    hybridLink: (bits and sfHybridLink) != 0
  )

func toCollisionMask*(value: int32): CollisionMask {.raises: [ValueError].} =
  ## Unpacks a 16-bit wire integer into `CollisionMask`.
  if value < 0 or value > 0xFFFF:
    raise newException(ValueError, "Collision mask does not fit the PMX field.")
  let bits = value and validCollisionMask
  CollisionMask(
    group1: (bits and cgGroup1) != 0,
    group2: (bits and cgGroup2) != 0,
    group3: (bits and cgGroup3) != 0,
    group4: (bits and cgGroup4) != 0,
    group5: (bits and cgGroup5) != 0,
    group6: (bits and cgGroup6) != 0,
    group7: (bits and cgGroup7) != 0,
    group8: (bits and cgGroup8) != 0,
    group9: (bits and cgGroup9) != 0,
    group10: (bits and cgGroup10) != 0,
    group11: (bits and cgGroup11) != 0,
    group12: (bits and cgGroup12) != 0,
    group13: (bits and cgGroup13) != 0,
    group14: (bits and cgGroup14) != 0,
    group15: (bits and cgGroup15) != 0,
    group16: (bits and cgGroup16) != 0
  )
