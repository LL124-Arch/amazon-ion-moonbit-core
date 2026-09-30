import assert from "node:assert/strict"
import { execFileSync } from "node:child_process"
import path from "node:path"
import { fileURLToPath } from "node:url"
import * as Ion from "ion-js"

const root = path.dirname(fileURLToPath(import.meta.url))
const repoRoot = path.resolve(root, "..")

function runMoonBit(mode, payload, { allowError = false } = {}) {
  const output = execFileSync(
    "moon",
    ["run", "--quiet", "examples/interop", mode, payload],
    { cwd: repoRoot, encoding: "utf8", maxBuffer: 4 * 1024 * 1024 },
  ).trim()
  const fields = Object.fromEntries(
    output.split(/\r?\n/).map((line) => {
      const separator = line.indexOf("=")
      assert.notEqual(separator, -1, `unexpected MoonBit output: ${line}`)
      return [line.slice(0, separator), line.slice(separator + 1)]
    }),
  )
  if (!allowError) assert.equal(fields.ERROR, undefined, fields.ERROR)
  return fields
}

function canonicalValues(textOrBinary) {
  return Ion.dom.loadAll(textOrBinary).map((value) => Ion.dumpText(value))
}

function assertEquivalent(actual, expected, direction) {
  assert.deepEqual(canonicalValues(actual), expected, direction)
}

const richText =
  'ann::{a: 1, a: 2, huge: 123456789012345678901234567890, decimal: 12.30, timestamp: 2024-01-02T03:04:05.123Z, blob: {{aGk=}}, clob: {{"hi"}}, precise_float: 1.0000000000000002e0, negative_zero: -0e0, sexp: (add 1), list: [true, null.int]}'
const expected = canonicalValues(richText)

// MoonBit reads Ion text, writes both formats, and ion-js verifies the results.
const moonOutput = runMoonBit("roundtrip", richText)
const moonText = Buffer.from(moonOutput.TEXT_HEX, "hex").toString("utf8")
const moonBinary = Buffer.from(moonOutput.BINARY_HEX, "hex")
assertEquivalent(moonText, expected, "MoonBit text output must match ion-js")
assertEquivalent(moonBinary, expected, "MoonBit binary output must match ion-js")

// ion-js writes both formats, then MoonBit parses them and returns normalized text.
const ionJsValue = Ion.dom.loadAll(richText)[0]
const ionJsText = Ion.dumpText(ionJsValue)
const ionJsBinary = Buffer.from(Ion.dumpBinary(ionJsValue))
const moonFromIonText = runMoonBit("parse-text", ionJsText)
const moonFromIonBinary = runMoonBit("parse-binary", ionJsBinary.toString("hex"))
assertEquivalent(
  Buffer.from(moonFromIonText.TEXT_HEX, "hex").toString("utf8"),
  expected,
  "MoonBit must parse ion-js text output",
)
assertEquivalent(
  Buffer.from(moonFromIonBinary.TEXT_HEX, "hex").toString("utf8"),
  expected,
  "MoonBit must parse ion-js binary output",
)

// Keep malformed-input behavior in the same cross-runtime check.
const malformed = runMoonBit("parse-binary", "e00100ea8e00", { allowError: true })
assert.match(malformed.ERROR ?? "", /unexpected|eof|VarUInt/i)

console.log(JSON.stringify({
  oracle: "amazon-ion/ion-js",
  version: "5.2.1",
  directions: [
    "MoonBit text and binary output parsed by ion-js",
    "ion-js text and binary output parsed by MoonBit",
    "truncated VarUInt rejected by MoonBit",
  ],
  cases: ["annotations", "duplicate struct fields", "large int", "double precision float", "negative-zero float", "decimal", "timestamp", "blob/clob", "sexp/list"],
  result: "passed",
}))
