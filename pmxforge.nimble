version = "1.0.0"
author = "Omega Slender"
description = "PMX 2.0/2.1 parsing and serialization for Nim."
license = "MIT"
srcDir = "src"
requires "nim >= 2.0.0"
skipDirs = @["examples", "tests", "tools", "docs", "build", "nimcache"]
skipFiles = @["nimble.paths"]

task test, "Compiles and runs every test suite.":
  for suite in [
    "tests/test_elements.nim",
    "tests/test_model.nim",
    "tests/test_validation.nim",
    "tests/test_io.nim",
    "tests/test_malformed.nim",
    "tests/test_regressions.nim",
    "tests/test_hardening.nim",
    "tests/test_examples.nim",
    "tests/test_perf.nim",
    "tests/test_fixtures.nim",
    "tests/test_package.nim",
    "tests/test_wasm_abi.nim"
  ]:
    let flags =
      if suite.endsWith("test_wasm_abi.nim"):
        " -d:pmxforgeWasmHostTest"
      else:
        ""
    exec "nim c -r --hints:off --path:src" & flags & " " & suite
  exec "nim c -r --hints:off --path:src -d:pmxforgeNoFileSystem tests/test_nofs.nim"

task testJs, "Runs the byte-only suite on JavaScript.":
  exec "nim js -r --hints:off --path:src tests/test_nofs.nim"

task wasm, "Builds the Emscripten WebAssembly bridge into build/wasm.":
  exec "nim r --hints:off --path:src src/pmxforge/wasm/build.nim"

task wasmTest, "Builds the wasm bridge, writes fixtures, and runs the Node smoke test.":
  exec "nim r --hints:off --path:src src/pmxforge/wasm/build.nim"
  exec "nim c -r --hints:off --path:src -o:build/wasm/fixture.exe tests/wasm/fixture.nim"
  exec "node tests/wasm/smoke.mjs"

task examples, "Compiles every example.":
  for example in [
    "examples/make_sample.nim",
    "examples/inspect.nim",
    "examples/rename_model.nim",
    "examples/convert_encoding.nim",
    "examples/stats_csv.nim",
    "examples/add_box.nim",
    "examples/transform_vertices.nim",
    "examples/recompute_normals.nim",
    "examples/flip_faces.nim",
    "examples/mirror_mesh.nim",
    "examples/soften_weights.nim",
    "examples/convert_skinning.nim",
    "examples/add_bone_chain.nim",
    "examples/build_ik.nim",
    "examples/add_morphs.nim",
    "examples/split_material.nim",
    "examples/retint_materials.nim",
    "examples/fix_texture_paths.nim",
    "examples/add_physics.nim",
    "examples/strip_physics.nim",
    "examples/setup_soft_body.nim",
    "examples/export_obj.nim",
    "examples/batch_repair.nim",
    "examples/fill_names.nim",
    "examples/downgrade_20.nim",
    "examples/sanitize_bytes.nim"
  ]:
    exec "nim c --hints:off --path:src " & example

task apiDocs, "Regenerates docs/API.md from the public API.":
  exec "nim r --hints:off tools/gen_api_docs.nim"

task apiDocsCheck, "Verifies that docs/API.md matches the public API.":
  exec "nim r --hints:off tools/gen_api_docs.nim -- --check"

task fixtures, "Regenerates the independent PMX fixtures.":
  exec "nim c -r --hints:off tools/make_fixtures.nim"

