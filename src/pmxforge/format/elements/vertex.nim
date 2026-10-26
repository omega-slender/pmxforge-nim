## Vertex records and skinning.
##
## Provides `Vertex` and the `BDEF1`, `BDEF2`, `BDEF4`, `SDEF`, and `QDEF` payloads that
## bind it to one or more bones.

import ../../core/vectors
import ../internal/preconditions
import ../internal/copy_helpers

type
  BDEF1* = object ## Single-bone vertex skinning.
    boneIndex1*: int32 ## Target bone index (-1 for unbound).

  BDEF2* = object ## Two-bone linear blend skinning.
    boneIndex1*: int32 ## First bone index.
    boneIndex2*: int32 ## Second bone index.
    boneWeight1*: float32 ## Weight of bone 1 in [0, 1] (bone 2 weight is 1 - weight1).

  BDEF4* = object ## Four-bone linear blend skinning.
    boneIndex1*, boneIndex2*, boneIndex3*, boneIndex4*: int32 ## Target bone indices.
    boneWeight1*, boneWeight2*, boneWeight3*, boneWeight4*: float32 ## Skinning weights.

  SDEF* = object ## Spherical deformation skinning (two bones).
    boneIndex1*, boneIndex2*: int32 ## Target bone indices.
    boneWeight1*: float32 ## Weight of bone 1; bone 2 takes the rest.
    c*, r0*, r1*: Vector3 ## SDEF blending center and correction vectors.

  QDEF* = object ## Dual-quaternion skinning (four bones, PMX 2.1).
    boneIndex1*, boneIndex2*, boneIndex3*, boneIndex4*: int32 ## Target bone indices.
    boneWeight1*, boneWeight2*, boneWeight3*, boneWeight4*: float32 ## Skinning weights.

  DeformKind* {.size: sizeof(int32).} = enum ## Vertex skinning deformation type.
    dkBDEF1 = 0 ## Single bone (rigid).
    dkBDEF2 = 1 ## Two bones (linear blend).
    dkBDEF4 = 2 ## Four bones (linear blend).
    dkSDEF = 3 ## Spherical deformation (two bones with SDEF parameters).
    dkQDEF = 4 ## Dual quaternion deformation (PMX 2.1).

  DeformData* = object ## Tagged union for vertex skinning data.
    case kind*: DeformKind ## Active skinning variant.
    of dkBDEF1:
      bdef1*: BDEF1 ## Single-bone payload.
    of dkBDEF2:
      bdef2*: BDEF2 ## Two-bone linear blend payload.
    of dkBDEF4:
      bdef4*: BDEF4 ## Four-bone linear blend payload.
    of dkSDEF:
      sdef*: SDEF ## Spherical deformation payload.
    of dkQDEF:
      qdef*: QDEF ## Dual-quaternion payload.

  Vertex* = ref object ## PMX vertex containing geometry, UVs, skinning, and edge scale.
    position*: Vector3 ## 3D position vector.
    normal*: Vector3 ## Surface normal vector.
    uv*: Vector2 ## Primary UV texture coordinates.
    additionalUv*: seq[Vector4] ## Up to 4 extra UV channels.
    weightDeform*: DeformData ## Skinning deformation and weights.
    edgeScale*: float32 ## Outline edge scale factor.

proc validateDeform*(deform: DeformData) {.raises: [ValueError].} =
  ## Raises ValueError when the bone indices, weights, or vectors are invalid.
  requireValidEnum(deform.kind, "Deform kind")
  case deform.kind
  of dkBDEF1:
    if deform.bdef1.boneIndex1 < -1:
      raise newException(ValueError, "BDEF1 bone index must be -1 or non-negative.")
  of dkBDEF2:
    if deform.bdef2.boneIndex1 < -1 or deform.bdef2.boneIndex2 < -1:
      raise newException(ValueError, "BDEF2 bone indices must be -1 or non-negative.")
    checkUnitRange(deform.bdef2.boneWeight1, "BDEF2 weight")
  of dkBDEF4:
    for index in
      [deform.bdef4.boneIndex1, deform.bdef4.boneIndex2, deform.bdef4.boneIndex3, deform.bdef4.boneIndex4]:
      if index < -1:
        raise newException(ValueError, "BDEF4 bone indices must be -1 or non-negative.")
    for i, weight in
      [
        deform.bdef4.boneWeight1,
        deform.bdef4.boneWeight2,
        deform.bdef4.boneWeight3,
        deform.bdef4.boneWeight4
      ]:
      checkUnitRange(weight, "BDEF4 weight[" & $i & "]")
  of dkSDEF:
    if deform.sdef.boneIndex1 < -1 or deform.sdef.boneIndex2 < -1:
      raise newException(ValueError, "SDEF bone indices must be -1 or non-negative.")
    checkUnitRange(deform.sdef.boneWeight1, "SDEF weight")
    checkFinite(deform.sdef.c, "SDEF c")
    checkFinite(deform.sdef.r0, "SDEF r0")
    checkFinite(deform.sdef.r1, "SDEF r1")
  of dkQDEF:
    for index in
      [deform.qdef.boneIndex1, deform.qdef.boneIndex2, deform.qdef.boneIndex3, deform.qdef.boneIndex4]:
      if index < -1:
        raise newException(ValueError, "QDEF bone indices must be -1 or non-negative.")
    for i, weight in
      [deform.qdef.boneWeight1, deform.qdef.boneWeight2, deform.qdef.boneWeight3, deform.qdef.boneWeight4]:
      checkUnitRange(weight, "QDEF weight[" & $i & "]")

proc isValid*(deform: DeformData, boneCount = -1'i32): bool =
  ## Returns true when the deformation is valid and fits `boneCount`.
  if not isValidOptionalCount(boneCount):
    return false
  try:
    deform.validateDeform()
    case deform.kind
    of dkBDEF1:
      if boneCount >= 0 and (deform.bdef1.boneIndex1 >= boneCount):
        return false
    of dkBDEF2:
      if boneCount >= 0 and (deform.bdef2.boneIndex1 >= boneCount or deform.bdef2.boneIndex2 >= boneCount):
        return false
    of dkBDEF4:
      if boneCount >= 0 and
          (deform.bdef4.boneIndex1 >= boneCount or deform.bdef4.boneIndex2 >= boneCount or
            deform.bdef4.boneIndex3 >= boneCount or deform.bdef4.boneIndex4 >= boneCount):
        return false
    of dkSDEF:
      if boneCount >= 0 and (deform.sdef.boneIndex1 >= boneCount or deform.sdef.boneIndex2 >= boneCount):
        return false
    of dkQDEF:
      if boneCount >= 0 and
          (deform.qdef.boneIndex1 >= boneCount or deform.qdef.boneIndex2 >= boneCount or
            deform.qdef.boneIndex3 >= boneCount or deform.qdef.boneIndex4 >= boneCount):
        return false
    true
  except ValueError:
    false

proc repairedBoneIndex(value, boneCount: int32): int32 {.inline.} =
  ## Clamps an invalid bone index or out-of-range reference to -1.
  if value < -1 or (boneCount >= 0 and value >= boneCount): -1 else: value

proc repair*(deform: var DeformData, boneCount = -1'i32) {.raises: [ValueError].} =
  ## Clamps weights and resets bad bone indices to -1.
  requireValidOptionalCount(boneCount, "Deform boneCount")
  try:
    requireValidEnum(deform.kind, "Deform kind")
  except ValueError:
    deform = DeformData(kind: dkBDEF1, bdef1: BDEF1(boneIndex1: -1))
    return
  case deform.kind
  of dkBDEF1:
    deform.bdef1.boneIndex1 = repairedBoneIndex(deform.bdef1.boneIndex1, boneCount)
  of dkBDEF2:
    deform.bdef2.boneIndex1 = repairedBoneIndex(deform.bdef2.boneIndex1, boneCount)
    deform.bdef2.boneIndex2 = repairedBoneIndex(deform.bdef2.boneIndex2, boneCount)
    deform.bdef2.boneWeight1 = min(1.0'f32, max(0.0'f32, repairFinite(deform.bdef2.boneWeight1, 0.5'f32)))
  of dkBDEF4:
    deform.bdef4.boneIndex1 = repairedBoneIndex(deform.bdef4.boneIndex1, boneCount)
    deform.bdef4.boneIndex2 = repairedBoneIndex(deform.bdef4.boneIndex2, boneCount)
    deform.bdef4.boneIndex3 = repairedBoneIndex(deform.bdef4.boneIndex3, boneCount)
    deform.bdef4.boneIndex4 = repairedBoneIndex(deform.bdef4.boneIndex4, boneCount)
    deform.bdef4.boneWeight1 = min(1.0'f32, max(0.0'f32, repairFinite(deform.bdef4.boneWeight1, 0.25'f32)))
    deform.bdef4.boneWeight2 = min(1.0'f32, max(0.0'f32, repairFinite(deform.bdef4.boneWeight2, 0.25'f32)))
    deform.bdef4.boneWeight3 = min(1.0'f32, max(0.0'f32, repairFinite(deform.bdef4.boneWeight3, 0.25'f32)))
    deform.bdef4.boneWeight4 = min(1.0'f32, max(0.0'f32, repairFinite(deform.bdef4.boneWeight4, 0.25'f32)))
  of dkSDEF:
    deform.sdef.boneIndex1 = repairedBoneIndex(deform.sdef.boneIndex1, boneCount)
    deform.sdef.boneIndex2 = repairedBoneIndex(deform.sdef.boneIndex2, boneCount)
    deform.sdef.boneWeight1 = min(1.0'f32, max(0.0'f32, repairFinite(deform.sdef.boneWeight1, 0.5'f32)))
    deform.sdef.c.x = repairFinite(deform.sdef.c.x)
    deform.sdef.c.y = repairFinite(deform.sdef.c.y)
    deform.sdef.c.z = repairFinite(deform.sdef.c.z)
    deform.sdef.r0.x = repairFinite(deform.sdef.r0.x)
    deform.sdef.r0.y = repairFinite(deform.sdef.r0.y)
    deform.sdef.r0.z = repairFinite(deform.sdef.r0.z)
    deform.sdef.r1.x = repairFinite(deform.sdef.r1.x)
    deform.sdef.r1.y = repairFinite(deform.sdef.r1.y)
    deform.sdef.r1.z = repairFinite(deform.sdef.r1.z)
  of dkQDEF:
    deform.qdef.boneIndex1 = repairedBoneIndex(deform.qdef.boneIndex1, boneCount)
    deform.qdef.boneIndex2 = repairedBoneIndex(deform.qdef.boneIndex2, boneCount)
    deform.qdef.boneIndex3 = repairedBoneIndex(deform.qdef.boneIndex3, boneCount)
    deform.qdef.boneIndex4 = repairedBoneIndex(deform.qdef.boneIndex4, boneCount)
    deform.qdef.boneWeight1 = min(1.0'f32, max(0.0'f32, repairFinite(deform.qdef.boneWeight1, 0.25'f32)))
    deform.qdef.boneWeight2 = min(1.0'f32, max(0.0'f32, repairFinite(deform.qdef.boneWeight2, 0.25'f32)))
    deform.qdef.boneWeight3 = min(1.0'f32, max(0.0'f32, repairFinite(deform.qdef.boneWeight3, 0.25'f32)))
    deform.qdef.boneWeight4 = min(1.0'f32, max(0.0'f32, repairFinite(deform.qdef.boneWeight4, 0.25'f32)))

proc repair*(obj: Vertex, boneCount = -1'i32, additionalUvCount = -1'i32) {.raises: [ValueError].} =
  ## Fixes non-finite values and repairs skinning in place.
  requireValidOptionalCount(boneCount, "Vertex boneCount")
  requireValidOptionalCount(additionalUvCount, "Vertex additionalUvCount")
  if obj == nil:
    return
  obj.position.x = repairFinite(obj.position.x)
  obj.position.y = repairFinite(obj.position.y)
  obj.position.z = repairFinite(obj.position.z)
  obj.normal.x = repairFinite(obj.normal.x)
  obj.normal.y = repairFinite(obj.normal.y)
  obj.normal.z = repairFinite(obj.normal.z)
  obj.uv.x = repairFinite(obj.uv.x)
  obj.uv.y = repairFinite(obj.uv.y)
  obj.weightDeform.repair(boneCount)
  obj.edgeScale = max(0.0'f32, repairFinite(obj.edgeScale, 1.0'f32))
  var count = additionalUvCount
  if count < 0:
    count = min(4, obj.additionalUv.len).int32
  count = max(0'i32, min(4'i32, count))
  obj.additionalUv.setLen(count)
  for i in 0 ..< int(count):
    obj.additionalUv[i].x = repairFinite(obj.additionalUv[i].x)
    obj.additionalUv[i].y = repairFinite(obj.additionalUv[i].y)
    obj.additionalUv[i].z = repairFinite(obj.additionalUv[i].z)
    obj.additionalUv[i].w = repairFinite(obj.additionalUv[i].w)

proc isValid*(obj: Vertex, boneCount = -1'i32, additionalUvCount = -1'i32): bool =
  ## Returns true when positions, UVs, and skinning are valid.
  if not isValidOptionalCount(boneCount) or not isValidOptionalCount(additionalUvCount):
    return false
  if obj == nil:
    return false
  try:
    checkFinite(obj.position, "Vertex position")
    checkFinite(obj.normal, "Vertex normal")
    checkFinite(obj.uv, "Vertex UV")
    for value in obj.additionalUv:
      checkFinite(value, "Vertex additional UV")
    checkNonNegativeFinite(obj.edgeScale, "Vertex edge scale")
    if obj.additionalUv.len > 4:
      return false
    if additionalUvCount >= 0 and obj.additionalUv.len != int(additionalUvCount):
      return false
    obj.weightDeform.isValid(boneCount)
  except ValueError:
    false

proc newBDEF1*(boneIndex1 = -1'i32): DeformData {.raises: [ValueError].} =
  ## Creates single-bone (rigid) skinning data. Pass -1 for unbound.
  result = DeformData(kind: dkBDEF1, bdef1: BDEF1(boneIndex1: boneIndex1))
  validateDeform(result)

proc newBDEF2*(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneWeight1 = 0.5'f32
): DeformData {.raises: [ValueError].} =
  ## Creates two-bone linear blend skinning data.
  result = DeformData(
    kind: dkBDEF2,
    bdef2: BDEF2(boneIndex1: boneIndex1, boneIndex2: boneIndex2, boneWeight1: boneWeight1)
  )
  validateDeform(result)

proc newBDEF4*(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneIndex3 = -1'i32,
  boneIndex4 = -1'i32,
  boneWeight1 = 0.25'f32,
  boneWeight2 = 0.25'f32,
  boneWeight3 = 0.25'f32,
  boneWeight4 = 0.25'f32
): DeformData {.raises: [ValueError].} =
  ## Creates four-bone linear blend skinning data.
  result = DeformData(
    kind: dkBDEF4,
    bdef4: BDEF4(
      boneIndex1: boneIndex1,
      boneIndex2: boneIndex2,
      boneIndex3: boneIndex3,
      boneIndex4: boneIndex4,
      boneWeight1: boneWeight1,
      boneWeight2: boneWeight2,
      boneWeight3: boneWeight3,
      boneWeight4: boneWeight4
    )
  )
  validateDeform(result)

proc newSDEF*(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneWeight1 = 0.5'f32,
  c = Vector3.zero,
  r0 = Vector3.zero,
  r1 = Vector3.zero
): DeformData {.raises: [ValueError].} =
  ## Creates SDEF (spherical deformation) skinning data.
  result = DeformData(
    kind: dkSDEF,
    sdef: SDEF(
      boneIndex1: boneIndex1,
      boneIndex2: boneIndex2,
      boneWeight1: boneWeight1,
      c: c,
      r0: r0,
      r1: r1
    )
  )
  validateDeform(result)

proc newQDEF*(
  boneIndex1 = -1'i32,
  boneIndex2 = -1'i32,
  boneIndex3 = -1'i32,
  boneIndex4 = -1'i32,
  boneWeight1 = 0.25'f32,
  boneWeight2 = 0.25'f32,
  boneWeight3 = 0.25'f32,
  boneWeight4 = 0.25'f32
): DeformData {.raises: [ValueError].} =
  ## Creates four-bone dual-quaternion skinning data (PMX 2.1).
  result = DeformData(
    kind: dkQDEF,
    qdef: QDEF(
      boneIndex1: boneIndex1,
      boneIndex2: boneIndex2,
      boneIndex3: boneIndex3,
      boneIndex4: boneIndex4,
      boneWeight1: boneWeight1,
      boneWeight2: boneWeight2,
      boneWeight3: boneWeight3,
      boneWeight4: boneWeight4
    )
  )
  validateDeform(result)

proc newVertex*(
  position = Vector3.zero,
  normal = Vector3.up,
  uv = Vector2.zero,
  additionalUv: seq[Vector4] = @[],
  weightDeform = newBDEF1(-1'i32),
  edgeScale = 1.0'f32
): Vertex {.raises: [ValueError].} =
  ## Creates a vertex with the given geometry and skinning.
  checkFinite(position, "Vertex position")
  checkFinite(normal, "Vertex normal")
  checkFinite(uv, "Vertex UV")
  for i, value in additionalUv:
    checkFinite(value, "Vertex additional UV[" & $i & "]")
  if additionalUv.len > 4:
    raise newException(ValueError, "Vertex additional UV count must not exceed 4.")
  validateDeform(weightDeform)
  checkFinite(edgeScale, "Vertex edge scale")
  result = Vertex(
    position: position,
    normal: normal,
    uv: uv,
    additionalUv: copySeq(additionalUv),
    weightDeform: weightDeform,
    edgeScale: edgeScale
  )
  if not result.isValid(additionalUvCount = int32(additionalUv.len)):
    raise newException(ValueError, "Vertex contains invalid local values.")

proc newVertex*(
  position: Vector3,
  normal: Vector3,
  uv: Vector2,
  boneIndex: int32
): Vertex {.raises: [ValueError].} =
  ## Creates a vertex bound to a single bone.
  newVertex(position, normal, uv, @[], newBDEF1(boneIndex), 1.0'f32)

proc getBoneIndicesInto*(deform: DeformData, into: var seq[int32]) {.raises: [ValueError].} =
  ## Writes the bone indices into `into`, reusing its capacity.
  deform.validateDeform()
  case deform.kind
  of dkBDEF1:
    into.setLen(1)
    into[0] = deform.bdef1.boneIndex1
  of dkBDEF2:
    into.setLen(2)
    into[0] = deform.bdef2.boneIndex1
    into[1] = deform.bdef2.boneIndex2
  of dkBDEF4:
    into.setLen(4)
    into[0] = deform.bdef4.boneIndex1
    into[1] = deform.bdef4.boneIndex2
    into[2] = deform.bdef4.boneIndex3
    into[3] = deform.bdef4.boneIndex4
  of dkSDEF:
    into.setLen(2)
    into[0] = deform.sdef.boneIndex1
    into[1] = deform.sdef.boneIndex2
  of dkQDEF:
    into.setLen(4)
    into[0] = deform.qdef.boneIndex1
    into[1] = deform.qdef.boneIndex2
    into[2] = deform.qdef.boneIndex3
    into[3] = deform.qdef.boneIndex4

proc getBoneIndices*(deform: DeformData): seq[int32] {.raises: [ValueError].} =
  ## Returns the active bone indices for this deformation.
  deform.getBoneIndicesInto(result)

proc getWeights*(deform: DeformData): seq[float32] {.raises: [ValueError].} =
  ## Returns the skinning weights for this deformation.
  deform.validateDeform()
  case deform.kind
  of dkBDEF1:
    @[1.0'f32]
  of dkBDEF2:
    @[deform.bdef2.boneWeight1, 1 - deform.bdef2.boneWeight1]
  of dkBDEF4:
    @[deform.bdef4.boneWeight1, deform.bdef4.boneWeight2, deform.bdef4.boneWeight3, deform.bdef4.boneWeight4]
  of dkSDEF:
    @[deform.sdef.boneWeight1, 1 - deform.sdef.boneWeight1]
  of dkQDEF:
    @[deform.qdef.boneWeight1, deform.qdef.boneWeight2, deform.qdef.boneWeight3, deform.qdef.boneWeight4]

func isPmx21Only*(deform: DeformData): bool {.inline.} =
  ## Returns true if this deformation uses QDEF (PMX 2.1 only).
  deform.kind == dkQDEF

proc `==`*(a, b: DeformData): bool =
  ## Compares two deformation values for equality.
  if a.kind != b.kind:
    return false
  case a.kind
  of dkBDEF1:
    a.bdef1 == b.bdef1
  of dkBDEF2:
    a.bdef2 == b.bdef2
  of dkBDEF4:
    a.bdef4 == b.bdef4
  of dkSDEF:
    a.sdef == b.sdef
  of dkQDEF:
    a.qdef == b.qdef

proc `==`*(a, b: Vertex): bool =
  ## Compares two vertices for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.position == b.position and a.normal == b.normal and a.uv == b.uv and a.additionalUv == b.additionalUv and
    a.weightDeform == b.weightDeform and a.edgeScale == b.edgeScale

proc copy*(obj: Vertex): Vertex =
  ## Returns a deep copy of the vertex.
  if isNil(obj):
    return nil
  Vertex(
    position: obj.position,
    normal: obj.normal,
    uv: obj.uv,
    additionalUv: copySeq(obj.additionalUv),
    weightDeform: obj.weightDeform,
    edgeScale: obj.edgeScale
  )
