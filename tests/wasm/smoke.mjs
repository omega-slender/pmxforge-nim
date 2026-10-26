import { readFile } from "node:fs/promises";
import { fileURLToPath, pathToFileURL } from "node:url";
import { dirname, join } from "node:path";

const buildDir = join(dirname(fileURLToPath(import.meta.url)), "..", "..", "build", "wasm");
const bridgeUrl = pathToFileURL(join(buildDir, "pmxforge.mjs")).href;

function fail(message) {
  console.error(`FAIL: ${message}`);
  process.exit(1);
}

const createPmxForge = (await import(bridgeUrl)).default;
const forge = await createPmxForge();

const text = (pointer) => forge.UTF8ToString(pointer);

function validate(bytes) {
  const input = forge._malloc(bytes.length);
  forge.HEAPU8.set(bytes, input);
  try {
    return forge._pmxforge_validate(input, bytes.length);
  } finally {
    forge._free(input);
  }
}

function roundtrip(bytes) {
  const input = forge._malloc(bytes.length);
  const outLength = forge._malloc(4);
  forge.HEAPU8.set(bytes, input);
  try {
    const output = forge._pmxforge_roundtrip(input, bytes.length, outLength);
    if (output === 0) {
      fail(`round trip returned nil: ${text(forge._pmxforge_last_message())}`);
    }
    const length = forge.HEAP32[outLength >> 2];
    const copy = Buffer.from(forge.HEAPU8.slice(output, output + length));
    forge._pmxforge_free(output);
    return copy;
  } finally {
    forge._free(outLength);
    forge._free(input);
  }
}

const version = text(forge._pmxforge_version());
if (version !== "1.0.0") {
  fail(`expected bridge version 1.0.0, got '${version}'`);
}

const valid = await readFile(join(buildDir, "fixture.pmx"));
const status = validate(valid);
if (status !== 0) {
  fail(`valid model reported status ${status}: ${text(forge._pmxforge_last_message())}`);
}

const round = roundtrip(valid);
if (!round.equals(valid)) {
  fail(`round trip is not byte-identical (${round.length} vs ${valid.length} bytes)`);
}

const damaged = await readFile(join(buildDir, "damaged.pmx"));
const invalidStatus = validate(damaged);
if (invalidStatus !== 4) {
  fail(`invalid model reported ${invalidStatus} instead of 4: ${text(forge._pmxforge_last_message())}`);
}

const corrupt = Buffer.from(valid);
corrupt[1] = 0x00;
const corruptStatus = validate(corrupt);
if (corruptStatus !== 1) {
  fail(`corrupt header reported ${corruptStatus} instead of 1: ${text(forge._pmxforge_last_message())}`);
}

forge._pmxforge_set_limits(0, 1024, 1024, 1024);
if (forge._pmxforge_last_status() !== 5) {
  fail("set_limits accepted a zero element budget instead of reporting status 5");
}

forge._pmxforge_set_limits(4000000, 67108864, 2147483647, 67108864);
if (forge._pmxforge_last_status() !== 0) {
  fail("set_limits rejected a valid budget");
}

forge._pmxforge_set_limits(4000000, valid.length, valid.length + 64, valid.length + 64);
if (forge._pmxforge_last_status() !== 0) {
  fail("set_limits rejected the fixture-sized budget");
}
if (validate(valid) !== 0) {
  fail(`a buffer exactly at maxSourceBytes reported ${text(forge._pmxforge_last_message())}`);
}
const exactRoundtrip = roundtrip(valid);
if (!exactRoundtrip.equals(valid)) {
  fail("roundtrip at the exact maxSourceBytes is not byte-identical");
}
forge._pmxforge_set_limits(4000000, valid.length - 1, 1024, 1024);
if (validate(valid) !== 3) {
  fail(`a buffer one byte above maxSourceBytes reported ${text(forge._pmxforge_last_message())}`);
}
if (!text(forge._pmxforge_last_message()).includes("maxSourceBytes")) {
  fail("the size-limit message does not name maxSourceBytes");
}
forge._pmxforge_set_limits(4000000, 0, 1024, 1024);
if (validate(valid) !== 3) {
  fail(`a zero maxSourceBytes accepted a ${valid.length}-byte buffer`);
}

forge._pmxforge_set_limits(4000000, 8, 1024, 1024);
if (forge._pmxforge_last_status() !== 0) {
  fail("set_limits rejected an 8-byte source cap; allocation must shrink with the source budget");
}
const oversizedLength = 16 * 1024 * 1024;
const oversized = forge._malloc(oversizedLength);
if (!oversized) {
  fail("could not allocate the oversized input buffer");
}
forge.HEAPU8.fill(0x50, oversized, oversized + oversizedLength);
const heapBefore = forge.HEAPU8.buffer.byteLength;
const oversizedStatus = forge._pmxforge_validate(oversized, oversizedLength);
const heapAfter = forge.HEAPU8.buffer.byteLength;
if (oversizedStatus !== 3) {
  fail(`oversized input reported ${oversizedStatus} instead of 3: ${text(forge._pmxforge_last_message())}`);
}
if (heapAfter - heapBefore > 8 * 1024 * 1024) {
  fail(`bridge grew the heap by ${heapAfter - heapBefore} bytes before rejecting 16 MiB`);
}
const outLength = forge._malloc(4);
const oversizedRoundtrip = forge._pmxforge_roundtrip(oversized, oversizedLength, outLength);
if (oversizedRoundtrip !== 0 || forge._pmxforge_last_status() !== 3) {
  fail("roundtrip did not reject the oversized input with status 3");
}
forge._free(outLength);
forge._free(oversized);
forge._pmxforge_set_limits(4000000, 67108864, 2147483647, 67108864);
if (forge._pmxforge_last_status() !== 0) {
  fail("set_limits could not restore the default budget");
}

const afterFailure = validate(corrupt);
if (afterFailure !== 1) {
  fail(`corrupt header after a limit failure reported ${afterFailure}`);
}
forge._pmxforge_set_limits(250000, 67108864, 32768, 67108864);
if (forge._pmxforge_last_status() !== 0) {
  fail("set_limits could not run after a failed validate; the busy latch leaked");
}

console.log(
  `ok: bridge ${version}, ${valid.length}-byte round trip, invalid model and corrupt header reported 4 and 1, ` +
    "size limits enforced before copying",
);
