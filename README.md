# 🦴 PMX Forge 

**PMX 2.0 and 2.1 for Nim — read, validate, repair, and write MikuMikuDance models.**

![Nim](https://img.shields.io/badge/Nim-2.0%2B-ffe953?logo=nim&logoColor=black)
![Format](https://img.shields.io/badge/PMX-2.0%20%7C%202.1-8957e5)
![Platforms](https://img.shields.io/badge/targets-native%20%7C%20JS%20%7C%20wasm%20%7C%20Android-1f6feb)
![License](https://img.shields.io/badge/license-MIT-2ea043)
![Version](https://img.shields.io/badge/version-1.0.0-informational)

PMX Forge implements the PMX binary format itself. Parsing, serialization,
validation, and repair are all local: no MMD installation, no Python interpreter,
and no external parser, at build time or at runtime.

> [!WARNING]
> Reading a file does not validate it. `readPmx` checks structure — magic,
> version, widths, lengths, ranges. `validate(model)` is the separate pass that
> decides whether the data is coherent. A model whose references point nowhere
> still parses, because MMD tolerates them. Call `validate`, then decide what to
> do.

---

## 🎯 Why PMX Forge

Model files in the wild are frequently inconsistent, and a tool that wants to
read or rewrite them needs to survive that.

- **No external toolchain.** The format, its index widths, its two text
  encodings, and its null sentinels are implemented in Nim.
- **Damaged files are a first-class case.** Validation is separate from parsing,
  and repair is explicit rather than hidden inside the reader.
- **Untrusted input is bounded.** Every allocation follows an explicit budget,
  checked before the source is touched.
- **One API, four hosts.** The same operations exist for paths, streams, byte
  buffers, and filesystem-less targets such as browsers and WebAssembly.
- **Writes are all-or-nothing.** Path writes commit atomically, and stream writes
  at offset zero can be rolled back.

PMX Forge is a format library, not a renderer, a physics engine, or a motion
toolkit. VMD and VPD files are outside its scope.

## 📦 Installation

```sh
nimble install https://github.com/omega-slender/pmxforge-nim
```

Declare it in the application's `.nimble` file:

```nim
requires "pmxforge"
```

The package requires Nim 2.0 or newer and has no dependencies beyond the
standard library.

## 🚀 Quick start

```nim
import pmxforge

let model = readPmx("model.pmx")
validate(model)
writePmx(model, "model-copy.pmx")

echo model.nameJA, ": ", model.vertices.len, " vertices"
```

```sh
nim c -r app.nim
```

Reading and writing are independent operations: a tool that only inspects models
never needs the writer, and a generator never needs the reader.

A `PmxModel` is plain mutable data with no internal lock. Use one model from one
thread at a time, or guard it yourself.

## 🧭 The format at a glance

| Aspect | What PMX Forge exposes |
|:--|:--|
| Versions | PMX 2.0 and 2.1, both read and written |
| References | `int32` with `-1` as the null sentinel |
| Vertex indices | Never `-1`: non-negative `int32` values, written as unsigned fields |
| Index widths | One, two, or four bytes, honored on read and widened on write |
| Text | UTF-8 and UTF-16LE, selected by the header |
| Skinning | BDEF1, BDEF2, BDEF4, SDEF, and QDEF |
| Sections | Vertices, faces, textures, materials, bones, morphs, display slots, rigid bodies, joints, soft bodies |
| Coordinates | `+X` right, `+Y` up, `+Z` forward, rotations in radians |

PMX 2.1 data is detected, never guessed. `isPmx21Only(model)` reports whether a
model uses soft bodies, QDEF vertices, flip or impulse morphs, the newer joint
types, or the 2.1 material flags, and a 2.0 model that grows such data is
promoted on write unless you disable it.

Flags are exposed as named booleans. Every bit the format defines is modelled;
bits it does not define are dropped on read, so a round trip is not byte
identical for a file that carries them.

### Degrees, not radians

`BoneIK.limitAngle` and the `IKLink` limits carry **degrees**, the unit the MMD
editor displays. The reader converts wire radians to degrees and the writer
converts back.

The conversion is unit math, not a bit-exact round trip: arbitrary wire radians
can differ by one `float32` ULP after a read and write pair. Compare with that
tolerance, or keep the original bytes when bit identity matters.

## 📖 Reading models

Three overloads cover paths, any `Stream`, and `seq[byte]`. The path overload
records the parent directory, which is what an application needs to resolve
relative texture paths later.

```nim
import pmxforge

let model = readPmx("miku.pmx")
echo model.directory          # Directory the file was opened from.
echo model.textures[0].path   # Path exactly as stored.

try:
  validate(model)
  echo "the model is consistent"
except ValueError as exc:
  echo "the model needs attention: ", exc.msg
```

Errors distinguish their causes: `PmxFormatError` for malformed data,
`PmxTruncatedError` for short input, and `PmxLimitError` for an exceeded
budget. Every field is range checked before use, including enum ordinals and
non-finite floats, so hostile input fails as an exception instead of a crash.

### Texture paths stay strings

The texture table keeps raw strings exactly as stored. They may contain `..`
segments, absolute paths, or separators from another operating system, and the
library never opens them.

Resolve `model.directory / texture.path` against a canonical directory before
touching the filesystem, and treat the texture table of an uploaded model as
untrusted input.

### Building a model from scratch

Every element has a checked constructor. A material's `faceCount` counts
triangles, not indices, because the writer multiplies by three for the wire:

```nim
import pmxforge

let left = newVertex(
  Vector3(x: -0.5'f32, y: 0.0'f32, z: 0.0'f32),
  Vector3.up, Vector2(x: 0.0'f32, y: 1.0'f32), 0'i32
)
let top = newVertex(
  Vector3(x: 0.0'f32, y: 0.5'f32, z: 0.0'f32),
  Vector3.up, Vector2(x: 0.5'f32, y: 0.0'f32), 0'i32
)
let right = newVertex(
  Vector3(x: 0.5'f32, y: 0.0'f32, z: 0.0'f32),
  Vector3.up, Vector2(x: 1.0'f32, y: 1.0'f32), 0'i32
)

let model = newPmxModel(
  nameJA = "triangle",
  vertices = @[left, top, right],
  faces = @[newFace(0'i32, 1'i32, 2'i32)],
  materials = @[newMaterial(nameJA = "skin", faceCount = 1'i32)],
  bones = @[newBone(nameJA = "root")],
  displayFrames = @[newDisplaySlot(nameJA = "Root", frames = @[newBoneDisplayFrame(0'i32)])])

validate(model)
writePmx(model, "triangle.pmx")
```

`newPmxModel` deep-copies the elements you pass in, so the caller keeps
ownership of its own objects. `examples/make_sample.nim` builds a rigged cloth
plane the same way.

## ✍️ Writing models

```nim
import pmxforge

let model = readPmx("suspect.pmx")

writePmx(model, "strict.pmx")                       # default: refuse invalid models
writePmx(model, "lenient.pmx", mode = pwmLenient)   # keep defects that fit the wire
writePmx(model, "repaired.pmx", mode = pwmRepair)   # repair a private copy, then write it
```

| Mode | Behavior |
|:--|:--|
| `pwmStrict` | Default. Refuses to serialize a model that fails validation. |
| `pwmLenient` | Writes anything still encodable, dangling references included, widening index fields so those references stay representable. |
| `pwmRepair` | Repairs a private copy before serializing; the caller's model is untouched. |

All three modes stage bytes in a buffer first, so a rejected model never reaches
the destination.

**Path writes are atomic.** A temporary file is committed in one step, extended
attributes and ACLs are preserved where the platform exposes them, and the
buffered write is flushed with `fflush` checked. A failed flush aborts the
commit instead of replacing the destination with a truncated file.

**The destination directory is resolved first.** A directory reached through a
symlink (`/tmp` on macOS is one) or a Windows junction is audited and written
through its real path, so those destinations work. The destination *file* itself
must still be a regular file: a link at that path is refused.

**Text limits belong to the limits object.** `PmxWriteLimits` carries
`maxOutputBytes` and `maxStringBytes`; the `maxStringBytes` argument of
`writePmx` defaults to `-1`, which means "use the limits object", and a zero
`maxStringBytes` means the library default (`MaxStringBytes`). A caller that
reads with a raised text budget can hand the same value to the writer instead of
repeating it on every call, and a limits object built only from
`maxOutputBytes` keeps working unchanged.

**Stream writes buffer the whole output.** The stream overload stages the
serialized model in memory (bounded by `maxOutputBytes`) and commits it in one
call, which is what makes the rollback possible. The path overload streams into a
temporary file instead, so writing a large model to disk does not hold it twice
in RAM.

**Stream writes are recoverable at offset zero.** A readable `FileStream` is
snapshotted first; on failure the original prefix is restored and the file is
truncated to its old length. Write-only or non-seekable handles fall back to
restoring the position, and bytes that were never overwritten stay untouched.
The snapshot costs one copy of the overwritten prefix. A failed trim raises, and
a failed recovery reports both failures instead of hiding one.

**Collision groups stay in `[1, 16]`** in every mode, lenient included: a group
ID is a physics input, not a nullable reference.

A PMX 2.0 model holding 2.1 data is promoted automatically. Pass
`autoUpgradeVersion = false` to get an error instead.

## 🔧 Validation and repair

```nim
import pmxforge

let model = readPmx("damaged.pmx")
model.repair()
writePmx(model, "fixed.pmx")

let issues = repairWithReport(model)
for issue in issues:
  echo issue
```

| API | Contract |
|:--|:--|
| `validate` | Strict: scalar ranges, text limits, enum ordinals, cross references, material face coverage, version compatibility. |
| `validateWireSafe` | Looser: the model can still be encoded. |
| `isValid(model)` | The strict checks without exceptions. Pass `strict = false` for the wire-safe rule. |
| `repair` | Best effort: clamps values, drops references that no longer fit, breaks bone and group-morph cycles, resynchronizes material face counts, and clears IK links left behind by a disabled flag. |
| `repairWithReport` | Runs the same pass and returns the strict violations that remain. |
| `Face.repair`, `bone.repair`, `vertex.repair` | Per-element repair when only one section is suspect. |

Each skinning weight is clamped on its own, so a repaired set may no longer sum
to one. Isolated `Face.repair` never writes `-1`: vertex indices stay unsigned
and encodable, and faces that still sit outside the vertex list are dropped by
`PmxModel.repair`, not tombstoned.

`repair` is not a promise that `validate` will pass afterwards. It keeps the
declared version, so 2.1-only data in a 2.0 model (QDEF skinning, soft bodies,
flip or impulse morphs, 2.1 joints) stays in place and still fails the strict
contract; `writePmx` can promote the version separately, and there is no
automatic text rewriting. An empty `repairWithReport` result means `validate`
now accepts the model.

One asymmetry is deliberate: a material morph aimed at a material that does not
exist is dropped, not rewritten to `-1`, because in that payload `-1` means
every material. Rewriting it would turn a dangling offset into a global effect.

## 🛡️ Limits for untrusted input

```nim
import pmxforge

let model = readPmx(uploadedBytes, SafePmxReadLimits)

var limits = DesktopPmxReadLimits
limits.maxStringBytes = 4096
limits.acceptNonFiniteFloats = true   # Inspect a broken file instead of failing.
let inspected = readPmx(uploadedBytes, limits)
```

| Preset | Budget | Intended use |
|:--|:--|:--|
| `SafePmxReadLimits` | 64 MB | Uploads and web services |
| `DesktopPmxReadLimits` | 256 MB | Desktop tools |
| `TrustedLargePmxReadLimits` | 1 GB | Trusted, large models |
| `UnboundedPmxWriteLimits` | No cap | When you own the input |

The allocation budget is at least the source cap, so a file at the size limit is
not refused mid-parse for estimated memory. That estimate is conservative
accounting of what the parser retains — sequence backing, heap objects, decoded
text — not a measurement of process RSS.

The safe preset also caps collections at 250,000 entries, so a genuine model with
more vertices or faces than that is refused with a limit error even when the file
itself is small. Use `DesktopPmxReadLimits` or `TrustedLargePmxReadLimits` for
those.

An invalid limit configuration fails before the source is touched.

## 🌍 Portability

The library is pure Nim and links no third-party C libraries. The only
platform-specific code is the extended attribute, ACL, and Windows security
descriptor preservation used by the atomic writer.

### Buffers and hosts without a filesystem

`-d:pmxforgeNoFileSystem` removes every path overload at compile time. The
byte-buffer and stream overloads remain, and the host owns all storage:

```sh
nim c -d:pmxforgeNoFileSystem app.nim
nim js app.nim
```

`tests/test_nofs.nim` is written this way and runs unchanged on both backends.

### WebAssembly

`src/pmxforge/wasm/bridge.nim` compiles the byte-buffer API into a wasm32 module
with a small C ABI, and `src/pmxforge/wasm/build.nim` is the driver. Both ship
inside the package; the facade does not re-export the bridge, because a browser
host opts in explicitly.

`nimble wasm` writes `build/wasm/pmxforge.mjs` and `build/wasm/pmxforge.wasm`,
an ES module factory named `createPmxForge`, built with `--threads:off` and
`-d:pmxforgeNoFileSystem`.

The SDK is resolved from `-d:pmxforgeEmsdkPath:<path>`, then `PMXFORGE_EMSDK`,
then `EMSDK`, then the usual install directories, then `emcc` on `PATH`. The path
may be an emsdk checkout, a directory that holds `emcc`, or a prefix whose
`bin/` holds it, so a Homebrew or distribution install works. An explicit value
that is none of those fails instead of silently falling through. Nimble runs its
tasks as NimScript and does not forward `-d:` from the command line, so
`nimble wasm` reads the environment; the `-d:` form applies when you run the
driver directly.

```sh
nimble wasm
nim r --path:src src/pmxforge/wasm/build.nim -d:pmxforgeEmsdkPath:"C:\emsdk"
nim r --path:src src/pmxforge/wasm/build.nim -d:pmxforgeEmsdkPath:/opt/emsdk -- --out:build/wasm-debug
```

The ABI reports `0` ok, `1` format error, `2` truncated input, `3` limit
exceeded, `4` parsed but invalid model, and `5` internal error.
`pmxforge_roundtrip(ptr, len, outLenPtr)` returns malloc'd bytes that the host
releases with `pmxforge_free`. `pmxforge_last_status()`,
`pmxforge_last_message()`, and `pmxforge_version()` describe the last call.

The bridge starts on the safe preset.
`pmxforge_set_limits(maxElements, maxSourceBytes, maxStringBytes,
maxOutputBytes)` changes it; every argument is a 32-bit integer, so JavaScript
passes plain numbers. The text budget applies to validation and re-serialization
as well as to reading, so a host that raises it can process a model end to end.
The allocation estimate follows `maxSourceBytes` with a 256 KiB floor, so
shrinking the source cap also shrinks the heap budget.

> [!IMPORTANT]
> The ABI is not reentrant. Do not call validate, roundtrip, or set_limits while
> another call is running, and do not export `set_limits` to untrusted page
> script.

```js
import createPmxForge from './pmxforge.mjs'

const forge = await createPmxForge()
const bytes = new Uint8Array(await (await fetch('model.pmx')).arrayBuffer())

const input = forge._malloc(bytes.length)
forge.HEAPU8.set(bytes, input)

const status = forge._pmxforge_validate(input, bytes.length)
console.log(status, forge.UTF8ToString(forge._pmxforge_last_message()))
forge._free(input)
```

### Android

An Android build only needs the NDK's Clang wrapper:

```sh
nim c --os:android --cpu:arm64 --cc:clang --clang.exe:<NDK_CLANG> --clang.linkerexe:<NDK_CLANG> -d:pmxforgeNoFileSystem app.nim
```

`<NDK_CLANG>` is `aarch64-linux-android21-clang` under
`toolchains/llvm/prebuilt/<host>/bin`; `arm` uses
`armv7a-linux-androideabi21-clang` and `amd64` uses
`x86_64-linux-android21-clang`.

Path overloads exist there, but the atomic writer refuses `/data/local/tmp`:
`getTempDir()` points into it and the directories above it are group-writable, so
another user could swap the temporary file. Write to app-private storage, or to a
sticky directory such as a mounted `tmpfs`.

### Targets

| Target | Requires | Verify with |
|:--|:--|:--|
| Windows | Native Nim compiler; Win32 security descriptors and ACL preservation | `nimble test`, `nimble examples` |
| Linux | Native Nim compiler; POSIX atomic replace with extended attributes | `nimble test` (adds the `/dev/full` flush regression) |
| Android | Android NDK Clang with `--os:android` | No-filesystem buffer suites; path writes refuse non-sticky group-writable parents |
| WebAssembly | Emscripten `emcc` | `nimble wasmTest` |
| JavaScript | `nim js` backend | `nimble testJs` |
| Any target | `-d:pmxforgeNoFileSystem` | Native `test_nofs` plus `nimble testJs` |
| macOS, FreeBSD, NetBSD, DragonFly | Extended attributes and ACLs have a branch per platform | Not verified here; run the suite on that host |
| iOS, 32-bit hosts | Same sources, no platform branch of their own | Not verified |

Support depends on the compiler and the target platform's libraries. Before
shipping, build and test on the platform you actually target.

## 🧪 Testing

```sh
nimble test        # every native suite, including examples, wasm ABI, and no-filesystem
nimble testJs      # byte and stream suite on Node
nimble wasmTest    # Emscripten module plus the Node smoke test
nimble examples    # compiles all twenty-six examples
nimble apiDocs     # regenerates docs/API.md from the public API
```

| Task | Coverage |
|:--|:--|
| `nimble test` | Elements, model, validation, I/O, malformed files, regressions, hardening, examples, performance, independent fixtures, package metadata, the wasm ABI host, and the no-filesystem buffers |
| `nimble testJs` | The byte and stream suite under Node |
| `nimble wasmTest` | Builds the module and runs the smoke test over a valid model, an invalid one, a corrupt header, a byte-identical round trip, and source limits checked before the host buffer is copied |
| `nimble examples` | Compiles every example as a CLI |
| `nimble fixtures` | Regenerates `tests/fixtures/` |

Beyond the happy paths:

- **Adversarial bytes.** A valid file is corrupted one field at a time, so the
  failure modes are exercised rather than assumed.
- **Hardening.** A stream that cannot report its position, a destination reached
  through a directory link, a corrupt material face count, the shared text
  budget, and the repair contract for IK links are covered by
  `tests/test_hardening.nim`.
- **Independent fixtures.** `tests/fixtures/` holds PMX files written by
  `tools/make_fixtures.nim` with primitive byte writes, not by this library: PMX
  2.0 sub-texture blending, a ConeTwist joint, and a flip morph that references
  itself.
- **Performance regression.** A 250,000-offset morph with and without a 64 KiB
  name is compared against a relative time bound, for validation and for writing,
  so name-times-offset amplification fails instead of only being benchmarked by
  hand.
- **Corpus.** Point `PMXFORGE_CORPUS` at a directory of real models to parse,
  validate, and re-serialize them:

```sh
PMXFORGE_CORPUS=/path/to/models nimble test
```

The binary fixtures are committed, so running the suite never needs the
generator.

## 🧰 Examples

The examples are small tools rather than fragments. `make_sample` writes a model
to disk and the rest work on whatever file or directory you point them at, so they
chain:

```sh
nim c -r examples/make_sample.nim        # writes sample.pmx in the current directory
nim c -r examples/inspect.nim sample.pmx
```

## 🩺 When it refuses

Error messages name the field, so they are worth reading:

| Message | What it means |
|:--|:--|
| `Material faceCount sum ... does not match total faces ...` | `faceCount` counts triangles. One triangle is `1`, even though the wire stores three indices per triangle. |
| `The model uses PMX 2.1-only data` | A 2.0 model holds QDEF vertices, soft bodies, a 2.1 joint, or the newer morphs. Leave `autoUpgradeVersion` on, or set `version = pmx21`. |
| `File not found` | An `IOError`, not a format error. The file never opened, so there was nothing to parse. |
| `Float32 value must be finite` | The file holds a NaN or an infinity. Read it with `acceptNonFiniteFloats = true`, then call `repair` to replace the value. |
| `String length ... exceeds the limit` | The declared text length is larger than the budget allows, which is what stops a small file from asking for a huge allocation. Raise `maxStringBytes` if the file is genuinely that large. |
| Trailing bytes after the last section | The file is longer than the model it describes, and the reader refuses to guess what the extra data means. |

One structural defect is tolerated rather than refused: a face count that is not a
multiple of three, either in a material or in the model's face index total. MMD
reads every stored index and draws the whole triangles, so the reader stores
`count div 3` and consumes the one or two leftover indices, which keeps the
sections that follow aligned. A negative count is still a format error.

## 🗂️ Project layout

```text
src/pmxforge.nim            Public module: re-exports the entire API
src/pmxforge/core/          Vectors, quaternions, and colors
src/pmxforge/format/        Element records, flags, limits, and validation
src/pmxforge/format/io/     Reader, writer, binary primitives, and text codec
src/pmxforge/wasm/          Emscripten bridge and the driver that builds it
examples/                   Twenty-six standalone tools
tests/                      Test suites, including the no-filesystem and JS ones
tests/wasm/                 Fixtures and the Node smoke test for the bridge
tools/                      Fixture and documentation generators
docs/                       Generated API reference
```

## 📚 Documentation

The complete API reference is [`docs/API.md`](docs/API.md): every public symbol
with its signature and docstring. It is generated from the sources, so run
`nimble apiDocs` after changing the public API.

## 🙏 Credits

PMX Forge follows **pymeshio**, the Python package for 3D model I/O that Ousttrue
wrote as the backend of a Blender import/export plugin. It reads and writes MMD
PMD and PMX files, reads VMD and VPD motion data, and reads Metasequoia MQO and
OBJ meshes. The repository is archived; its last push was in 2018, and it remains
a clear reference for what the PMX structures mean.

The layout of this library follows that example: format records live in their own
module, a reader and a writer own the two directions of the wire format, and
validation is a separate pass that a caller chooses to run.

- pymeshio: <https://github.com/ousttrue/pymeshio>
- PyPI: <https://pypi.org/project/pymeshio/>

PMX Forge is an independent Nim implementation; pymeshio is a separate project
with its own authors and terms.

## 📄 License

Available under the [MIT License](LICENSE).

Maintained by **Omega Slender** — <https://github.com/omega-slender/pmxforge-nim>.

---

## 💜 Support

PMX Forge is written and maintained on my own time. If it saves you some, you
can support the project with a donation:

**[ko-fi.com/omega_slender](https://ko-fi.com/omega_slender)**
