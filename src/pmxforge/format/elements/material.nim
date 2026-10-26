## Material records.
##
## Provides `Material` with its colors, render flags, outline settings, and diffuse, sphere,
## and toon texture references.

import ../../core/colors
import ../internal/copy_helpers
import ../internal/preconditions
import ../flags

type
  SphereBlendMode* {.size: sizeof(int32).} = enum ## Sphere map blending mode.
    sbmDisabled = 0 ## No sphere map.
    sbmMultiply = 1 ## Multiply (standard sphere map).
    sbmAdd = 2 ## Additive blending.
    sbmSubTexture = 3 ## Sub-texture (extra texture with separate UVs).

  Material* = ref object ## PMX material properties and texture references.
    nameJA*: string ## Japanese material name.
    nameEN*: string ## English / universal material name.
    diffuseColor*: RGB ## Diffuse surface color.
    alpha*: float32 ## Opacity in [0.0, 1.0].
    specularColor*: RGB ## Specular highlight color.
    specularStrength*: float32 ## Specular shininess power.
    ambientColor*: RGB ## Ambient lighting color.
    flags*: MaterialFlags ## Rendering flags (double-sided, edges, shadows).
    edgeColor*: RGBA ## Outline edge color and alpha.
    edgeScale*: float32 ## Outline edge thickness scale factor.
    textureIndex*: int32 ## Diffuse texture index (-1 if none).
    sphereTextureIndex*: int32 ## Sphere map texture index (-1 if none).
    sphereBlendMode*: SphereBlendMode ## Sphere map blending mode.
    internalToon*: bool ## If true, uses shared system toon texture.
    toonTextureIndex*: int32 ## Toon texture index (0-9 for system, or texture index).
    comment*: string ## Free-form material comment.
    faceCount*: int32 ## Triangles drawn by this material.

proc isValid*(material: Material, textureCount = -1'i32): bool {.raises: [].}
  ## Returns true when colors, flags, and textures are valid.

proc newMaterial*(
  nameJA = "",
  nameEN = nameJA,
  diffuseColor = RGB.white,
  alpha = 1.0'f32,
  specularColor = RGB.black,
  specularStrength = 0.0'f32,
  ambientColor = RGB(r: 0.5'f32, g: 0.5'f32, b: 0.5'f32),
  flags = MaterialFlags(),
  edgeColor = RGBA.black,
  edgeScale = 1.0'f32,
  textureIndex = -1'i32,
  sphereTextureIndex = -1'i32,
  sphereBlendMode = sbmDisabled,
  internalToon = true,
  toonTextureIndex = 0'i32,
  comment = "",
  faceCount = 0'i32
): Material {.raises: [ValueError].} =
  ## Creates a material with the given colors, flags, and textures.
  result = Material(
    nameJA: nameJA,
    nameEN: nameEN,
    diffuseColor: diffuseColor,
    alpha: alpha,
    specularColor: specularColor,
    specularStrength: specularStrength,
    ambientColor: ambientColor,
    flags: flags,
    edgeColor: edgeColor,
    edgeScale: edgeScale,
    textureIndex: textureIndex,
    sphereTextureIndex: sphereTextureIndex,
    sphereBlendMode: sphereBlendMode,
    internalToon: internalToon,
    toonTextureIndex: toonTextureIndex,
    comment: comment,
    faceCount: faceCount
  )
  if not result.isValid():
    raise newException(ValueError, "Material contains invalid local values.")

proc `==`*(a, b: Material): bool =
  ## Compares two materials for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.nameJA == b.nameJA and a.nameEN == b.nameEN and a.diffuseColor == b.diffuseColor and
    a.alpha == b.alpha and a.specularColor == b.specularColor and a.specularStrength == b.specularStrength and
    a.ambientColor == b.ambientColor and a.flags == b.flags and a.edgeColor == b.edgeColor and
    a.edgeScale == b.edgeScale and a.textureIndex == b.textureIndex and
    a.sphereTextureIndex == b.sphereTextureIndex and a.sphereBlendMode == b.sphereBlendMode and
    a.internalToon == b.internalToon and a.toonTextureIndex == b.toonTextureIndex and
    a.comment == b.comment and a.faceCount == b.faceCount

proc copy*(obj: Material): Material =
  ## Returns a deep copy of the material.
  if isNil(obj):
    return nil
  Material(
    nameJA: copyString(obj.nameJA),
    nameEN: copyString(obj.nameEN),
    diffuseColor: obj.diffuseColor,
    alpha: obj.alpha,
    specularColor: obj.specularColor,
    specularStrength: obj.specularStrength,
    ambientColor: obj.ambientColor,
    flags: obj.flags,
    edgeColor: obj.edgeColor,
    edgeScale: obj.edgeScale,
    textureIndex: obj.textureIndex,
    sphereTextureIndex: obj.sphereTextureIndex,
    sphereBlendMode: obj.sphereBlendMode,
    internalToon: obj.internalToon,
    toonTextureIndex: obj.toonTextureIndex,
    comment: copyString(obj.comment),
    faceCount: obj.faceCount
  )

proc isValid*(material: Material, textureCount: int32): bool =
  if not isValidOptionalCount(textureCount):
    return false
  if material == nil:
    return false
  try:
    requireValidEnum(material.sphereBlendMode, "Sphere blend mode")
    checkFinite(material.diffuseColor, "Material diffuse color")
    checkUnitRange(material.alpha, "Material alpha")
    checkFinite(material.specularColor, "Material specular color")
    checkNonNegativeFinite(material.specularStrength, "Material specular strength")
    checkFinite(material.ambientColor, "Material ambient color")
    checkFinite(material.edgeColor, "Material edge color")
    checkNonNegativeFinite(material.edgeScale, "Material edge scale")
    if material.faceCount < 0 or material.faceCount > high(int32) div 3:
      return false
    if material.textureIndex < -1 or material.sphereTextureIndex < -1:
      return false
    if material.internalToon:
      if material.toonTextureIndex < 0 or material.toonTextureIndex > 9:
        return false
    else:
      if material.toonTextureIndex < -1:
        return false
      if textureCount >= 0 and material.toonTextureIndex >= textureCount:
        return false
    if textureCount >= 0 and
        (material.textureIndex >= textureCount or material.sphereTextureIndex >= textureCount):
      return false
    true
  except ValueError:
    false

proc repair*(material: Material, textureCount = -1'i32) {.raises: [ValueError].} =
  ## Clamps colors and resets bad texture references to -1.
  requireValidOptionalCount(textureCount, "Material textureCount")
  if material == nil:
    return
  material.diffuseColor = repairFinite(material.diffuseColor)
  material.alpha = min(1.0'f32, max(0.0'f32, repairFinite(material.alpha, 1.0'f32)))
  material.specularColor = repairFinite(material.specularColor)
  material.specularStrength = repairNonNegative(material.specularStrength)
  material.ambientColor = repairFinite(material.ambientColor)
  material.edgeColor = repairFinite(material.edgeColor)
  material.edgeScale = repairNonNegative(material.edgeScale, 1.0'f32)
  if int(material.sphereBlendMode) < 0 or int(material.sphereBlendMode) > 3:
    material.sphereBlendMode = sbmDisabled
  if material.textureIndex < -1 or (textureCount >= 0 and material.textureIndex >= textureCount):
    material.textureIndex = -1
  if material.sphereTextureIndex < -1 or (textureCount >= 0 and material.sphereTextureIndex >= textureCount):
    material.sphereTextureIndex = -1
  if not material.internalToon and
      (material.toonTextureIndex < -1 or (textureCount >= 0 and material.toonTextureIndex >= textureCount)):
    material.toonTextureIndex = -1
  if material.internalToon:
    material.toonTextureIndex = min(9'i32, max(0'i32, material.toonTextureIndex))
  if material.faceCount < 0:
    material.faceCount = 0
  elif material.faceCount > high(int32) div 3:
    material.faceCount = high(int32) div 3
