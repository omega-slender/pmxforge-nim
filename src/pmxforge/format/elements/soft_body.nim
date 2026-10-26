## Soft body records.
##
## Provides `SoftBody` with its Bullet parameters, clusters, anchors, and pinned vertices for PMX 2.1 models.

import ../internal/copy_helpers
import ../internal/preconditions
import ../flags

type
  SoftBodyShape* {.size: sizeof(int32).} = enum ## Mesh shape representation for soft body.
    sbshTriMesh = 0 ## Triangle mesh.
    sbshRope = 1 ## Rope / line.

  AerodynamicsModel* {.size: sizeof(int32).} = enum ## Aerodynamic interaction model.
    amVPoint = 0 ## Vertex two-sided lift/drag.
    amVTwoSided = 1 ## Vertex two-sided.
    amVOneSided = 2 ## Vertex one-sided.
    amFTwoSided = 3 ## Face two-sided.
    amFOneSided = 4 ## Face one-sided.

  SoftBodyConfig* = object ## Bullet physics soft body coefficients.
    vcf*: float32 ## Velocities correction factor.
    dp*: float32 ## Damping coefficient.
    dg*: float32 ## Drag coefficient.
    lf*: float32 ## Lift coefficient.
    pr*: float32 ## Pressure coefficient.
    vc*: float32 ## Volume conservation coefficient.
    df*: float32 ## Dynamic friction coefficient.
    mt*: float32 ## Pose matching coefficient.
    chr*: float32 ## Rigid contacts hardness.
    khr*: float32 ## Kinetic contacts hardness.
    `shr`*: float32 ## Soft contacts hardness.
    ahr*: float32 ## Anchors hardness.

  SoftBodyCluster* = object ## Cluster and splitting parameters.
    srhrCl*: float32 ## Soft vs rigid hardness.
    skhrCl*: float32 ## Soft vs kinetic hardness.
    sshrCl*: float32 ## Soft vs soft hardness.
    srSpltCl*: float32 ## Soft vs rigid impulse split.
    skSpltCl*: float32 ## Soft vs kinetic impulse split.
    ssSpltCl*: float32 ## Soft vs soft impulse split.

  SoftBodyIteration* = object ## Solver iteration counts per simulation phase.
    vIt*: int32 ## Velocities solver iterations.
    pIt*: int32 ## Positions solver iterations.
    dIt*: int32 ## Drift solver iterations.
    cIt*: int32 ## Cluster solver iterations.

  SoftBodyMaterial* = object ## Linear, angular, and volume stiffness parameters.
    lst*: float32 ## Linear stiffness coefficient.
    ast*: float32 ## Area/angular stiffness coefficient.
    vst*: float32 ## Volume stiffness coefficient.

  AnchorRigidBody* = object ## Anchor connecting a rigid body to a soft body vertex.
    rigidBodyIndex*: int32 ## Target rigid body index.
    vertexIndex*: int32 ## Target vertex index.
    nearMode*: bool ## Uses the near collision mode for this anchor.

  SoftBody* = ref object ## PMX 2.1 soft body simulation record.
    nameJA*: string ## Japanese soft body name.
    nameEN*: string ## English / universal soft body name.
    shape*: SoftBodyShape ## Mesh shape (tri-mesh or rope).
    materialIndex*: int32 ## Target material index (-1 if none).
    groupId*: int32 ## Collision group ID (1 to 16).
    nonCollisionMask*: CollisionMask ## Mask disabling collisions with other groups.
    flags*: SoftBodyFlags ## Generation flags (B-link, cluster, hybrid).
    bLinkCreateDistance*: int32 ## B-link generation distance.
    numberOfClusters*: int32 ## Cluster count.
    totalMass*: float32 ## Total mass in kilograms.
    collisionMargin*: float32 ## Collision margin distance.
    aerodynamicsModel*: AerodynamicsModel ## Aerodynamics interaction model.
    config*: SoftBodyConfig ## Bullet configuration parameters.
    cluster*: SoftBodyCluster ## Cluster parameters.
    iteration*: SoftBodyIteration ## Solver iterations.
    material*: SoftBodyMaterial ## Material stiffness parameters.
    anchorRigidBodies*: seq[AnchorRigidBody] ## Attached rigid body anchors.
    vertexPins*: seq[int32] ## Pinned vertex indices.

proc newSoftBodyConfig*(
  vcf = 1.0'f32,
  dp = 0.0'f32,
  dg = 0.0'f32,
  lf = 0.05'f32,
  pr = 0.0'f32,
  vc = 0.5'f32,
  df = 1.0'f32,
  mt = 0.0'f32,
  chr = 1.0'f32,
  khr = 0.5'f32,
  `shr` = 1.0'f32,
  ahr = 1.0'f32
): SoftBodyConfig {.raises: [ValueError].} =
  ## Creates Bullet soft-body coefficients.
  checkFinite(vcf, "Soft-body config vcf")
  checkFinite(dp, "Soft-body config dp")
  checkFinite(dg, "Soft-body config dg")
  checkFinite(lf, "Soft-body config lf")
  checkFinite(pr, "Soft-body config pr")
  checkFinite(vc, "Soft-body config vc")
  checkFinite(df, "Soft-body config df")
  checkFinite(mt, "Soft-body config mt")
  checkFinite(chr, "Soft-body config chr")
  checkFinite(khr, "Soft-body config khr")
  checkFinite(`shr`, "Soft-body config shr")
  checkFinite(ahr, "Soft-body config ahr")
  SoftBodyConfig(
    vcf: vcf,
    dp: dp,
    dg: dg,
    lf: lf,
    pr: pr,
    vc: vc,
    df: df,
    mt: mt,
    chr: chr,
    khr: khr,
    `shr`: `shr`,
    ahr: ahr
  )

proc isValid*(
  body: SoftBody,
  materialCount = -1'i32,
  rigidBodyCount = -1'i32,
  vertexCount = -1'i32
): bool {.raises: [].}
  ## Returns true when coefficients and references are valid.

proc newSoftBody*(
  nameJA = "",
  materialIndex = 0'i32,
  shape = sbshTriMesh,
  groupId = 1'i32,
  nonCollisionMask = CollisionMask(),
  flags = SoftBodyFlags(),
  bLinkCreateDistance = 0'i32,
  numberOfClusters = 0'i32,
  totalMass = 1.0'f32,
  collisionMargin = 0.0'f32,
  aerodynamicsModel = amVPoint,
  config = newSoftBodyConfig(),
  cluster = SoftBodyCluster(),
  iteration = SoftBodyIteration(),
  material = SoftBodyMaterial(),
  anchorRigidBodies: seq[AnchorRigidBody] = @[],
  vertexPins: seq[int32] = @[],
  nameEN = nameJA
): SoftBody {.raises: [ValueError].} =
  ## Creates a soft body; -1 means no material is bound.
  if materialIndex < -1:
    raise newException(ValueError, "Material index must be -1 or non-negative.")
  requireValidEnum(shape, "Soft-body shape")
  requireValidEnum(aerodynamicsModel, "Aerodynamics model")
  result = SoftBody(
    nameJA: nameJA,
    nameEN: nameEN,
    shape: shape,
    materialIndex: materialIndex,
    groupId: groupId,
    nonCollisionMask: nonCollisionMask,
    flags: flags,
    bLinkCreateDistance: bLinkCreateDistance,
    numberOfClusters: numberOfClusters,
    totalMass: totalMass,
    collisionMargin: collisionMargin,
    aerodynamicsModel: aerodynamicsModel,
    config: config,
    cluster: cluster,
    iteration: iteration,
    material: material,
    anchorRigidBodies: copySeq(anchorRigidBodies),
    vertexPins: copySeq(vertexPins)
  )
  if not result.isValid():
    raise newException(ValueError, "Soft body contains invalid local values.")

proc `==`*(a, b: SoftBody): bool =
  ## Compares two soft bodies for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.shape == b.shape and
    a.materialIndex == b.materialIndex and a.groupId == b.groupId and
    a.nonCollisionMask == b.nonCollisionMask and a.flags == b.flags and
    a.bLinkCreateDistance == b.bLinkCreateDistance and a.numberOfClusters == b.numberOfClusters and
    a.totalMass == b.totalMass and a.collisionMargin == b.collisionMargin and
    a.aerodynamicsModel == b.aerodynamicsModel and a.config == b.config and a.cluster == b.cluster and
    a.iteration == b.iteration and a.material == b.material and a.anchorRigidBodies == b.anchorRigidBodies and
    a.vertexPins == b.vertexPins

proc copy*(obj: SoftBody): SoftBody =
  ## Returns a deep copy of the soft body.
  if isNil(obj):
    return nil
  SoftBody(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    shape: obj.shape,
    materialIndex: obj.materialIndex,
    groupId: obj.groupId,
    nonCollisionMask: obj.nonCollisionMask,
    flags: obj.flags,
    bLinkCreateDistance: obj.bLinkCreateDistance,
    numberOfClusters: obj.numberOfClusters,
    totalMass: obj.totalMass,
    collisionMargin: obj.collisionMargin,
    aerodynamicsModel: obj.aerodynamicsModel,
    config: obj.config,
    cluster: obj.cluster,
    iteration: obj.iteration,
    material: obj.material,
    anchorRigidBodies: copySeq(obj.anchorRigidBodies),
    vertexPins: copySeq(obj.vertexPins)
  )

proc isValid*(body: SoftBody, materialCount: int32, rigidBodyCount: int32, vertexCount: int32): bool =
  if not isValidOptionalCount(materialCount) or not isValidOptionalCount(rigidBodyCount) or
      not isValidOptionalCount(vertexCount):
    return false
  if body == nil:
    return false
  try:
    requireValidEnum(body.shape, "Soft-body shape")
    requireValidEnum(body.aerodynamicsModel, "Aerodynamics model")
    if body.groupId < 1 or body.groupId > 16:
      return false
    if body.materialIndex < -1 or (materialCount >= 0 and body.materialIndex >= materialCount):
      return false
    if body.bLinkCreateDistance < 0 or body.numberOfClusters < 0:
      return false
    if body.iteration.vIt < 0 or body.iteration.pIt < 0 or body.iteration.dIt < 0 or body.iteration.cIt < 0:
      return false
    checkNonNegativeFinite(body.totalMass, "Soft-body total mass")
    checkNonNegativeFinite(body.collisionMargin, "Soft-body collision margin")
    for value in
      [
        body.config.vcf,
        body.config.dp,
        body.config.dg,
        body.config.lf,
        body.config.pr,
        body.config.vc,
        body.config.df,
        body.config.mt,
        body.config.chr,
        body.config.khr,
        body.config.`shr`,
        body.config.ahr,
        body.cluster.srhrCl,
        body.cluster.skhrCl,
        body.cluster.sshrCl,
        body.cluster.srSpltCl,
        body.cluster.skSpltCl,
        body.cluster.ssSpltCl
      ]:
      checkFinite(value, "Soft-body parameter")
    checkNonNegativeFinite(body.material.lst, "Soft-body material lst")
    checkNonNegativeFinite(body.material.ast, "Soft-body material ast")
    checkNonNegativeFinite(body.material.vst, "Soft-body material vst")
    for anchor in body.anchorRigidBodies:
      if anchor.rigidBodyIndex < -1 or anchor.vertexIndex < 0 or
          (rigidBodyCount >= 0 and anchor.rigidBodyIndex >= rigidBodyCount) or
          (vertexCount >= 0 and anchor.vertexIndex >= vertexCount):
        return false
    for pin in body.vertexPins:
      if pin < 0 or (vertexCount >= 0 and pin >= vertexCount):
        return false
    true
  except ValueError:
    false

proc repair*(
  body: SoftBody,
  materialCount = -1'i32,
  rigidBodyCount = -1'i32,
  vertexCount = -1'i32
) {.raises: [ValueError].} =
  ## Clamps parameters and drops dangling vertex anchors.
  requireValidOptionalCount(materialCount, "Soft body materialCount")
  requireValidOptionalCount(rigidBodyCount, "Soft body rigidBodyCount")
  requireValidOptionalCount(vertexCount, "Soft body vertexCount")
  if body == nil:
    return
  if int(body.shape) < 0 or int(body.shape) > 1:
    body.shape = sbshTriMesh
  if int(body.aerodynamicsModel) < 0 or int(body.aerodynamicsModel) > 4:
    body.aerodynamicsModel = amVPoint
  body.groupId = min(16'i32, max(1'i32, body.groupId))
  if body.materialIndex < -1 or (materialCount >= 0 and body.materialIndex >= materialCount):
    body.materialIndex = -1
  body.bLinkCreateDistance = max(0'i32, body.bLinkCreateDistance)
  body.numberOfClusters = max(0'i32, body.numberOfClusters)
  body.totalMass = repairNonNegative(body.totalMass, 1.0'f32)
  body.collisionMargin = repairNonNegative(body.collisionMargin)
  body.config.vcf = repairFinite(body.config.vcf)
  body.config.dp = repairFinite(body.config.dp)
  body.config.dg = repairFinite(body.config.dg)
  body.config.lf = repairFinite(body.config.lf)
  body.config.pr = repairFinite(body.config.pr)
  body.config.vc = repairFinite(body.config.vc)
  body.config.df = repairFinite(body.config.df)
  body.config.mt = repairFinite(body.config.mt)
  body.config.chr = repairFinite(body.config.chr)
  body.config.khr = repairFinite(body.config.khr)
  body.config.`shr` = repairFinite(body.config.`shr`)
  body.config.ahr = repairFinite(body.config.ahr)
  body.cluster.srhrCl = repairFinite(body.cluster.srhrCl)
  body.cluster.skhrCl = repairFinite(body.cluster.skhrCl)
  body.cluster.sshrCl = repairFinite(body.cluster.sshrCl)
  body.cluster.srSpltCl = repairFinite(body.cluster.srSpltCl)
  body.cluster.skSpltCl = repairFinite(body.cluster.skSpltCl)
  body.cluster.ssSpltCl = repairFinite(body.cluster.ssSpltCl)
  body.iteration.vIt = max(0'i32, body.iteration.vIt)
  body.iteration.pIt = max(0'i32, body.iteration.pIt)
  body.iteration.dIt = max(0'i32, body.iteration.dIt)
  body.iteration.cIt = max(0'i32, body.iteration.cIt)
  body.material.lst = repairNonNegative(body.material.lst)
  body.material.ast = repairNonNegative(body.material.ast)
  body.material.vst = repairNonNegative(body.material.vst)
  var anchorWriteIndex = 0
  for anchorReadIndex in 0 ..< body.anchorRigidBodies.len:
    var anchor = body.anchorRigidBodies[anchorReadIndex]
    if anchor.rigidBodyIndex < -1 or (rigidBodyCount >= 0 and anchor.rigidBodyIndex >= rigidBodyCount):
      anchor.rigidBodyIndex = -1
    if anchor.vertexIndex < 0 or (vertexCount >= 0 and anchor.vertexIndex >= vertexCount):
      continue
    body.anchorRigidBodies[anchorWriteIndex] = anchor
    inc anchorWriteIndex
  body.anchorRigidBodies.setLen(anchorWriteIndex)
  var writeIndex = 0
  for readIndex in 0 ..< body.vertexPins.len:
    let pin = body.vertexPins[readIndex]
    if pin >= 0 and (vertexCount < 0 or pin < vertexCount):
      body.vertexPins[writeIndex] = pin
      inc writeIndex
  body.vertexPins.setLen(writeIndex)
