## Texture path entries.
##
## Provides `Texture`, a relative path owned by the model; the library never opens or
## validates the file itself.

import ../internal/copy_helpers

type
  Texture* = ref object ## Texture file path record.
    path*: string ## Relative file path to the texture asset.

proc newTexture*(path = ""): Texture =
  ## Creates a texture entry; an empty path is allowed.
  Texture(path: path)

func isEmpty*(texture: Texture): bool =
  ## Returns true when the texture is nil or its path is empty.
  texture == nil or texture.path.len == 0

proc `==`*(a, b: Texture): bool =
  ## Compares two textures for equality.
  if isNil(a) or isNil(b):
    return isNil(a) and isNil(b)
  a.path == b.path

proc copy*(obj: Texture): Texture =
  ## Returns a deep copy of the texture entry.
  if isNil(obj):
    return nil
  Texture(path: copyString(obj.path))

proc isValid*(texture: Texture): bool =
  ## Returns true when the texture entry is not nil.
  texture != nil
