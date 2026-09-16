import assert from "node:assert/strict"
import fs from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import * as Ion from "ion-js"

const root = path.dirname(fileURLToPath(import.meta.url))
const fixture = (name) => fs.readFileSync(path.join(root, "..", "fixtures", name))

const scalarFixture = fixture("valid/binary-basic.hex")
  .toString("ascii")
  .replace(/#[^\n]*|\s+/g, "")
const scalarBytes = Buffer.from(scalarFixture, "hex")
const scalarValues = Ion.loadAll(scalarBytes)
assert.deepEqual(
  scalarValues.map((value) => [
    value instanceof Boolean ? "bool" :
    value instanceof Number ? "int" : "string",
    value.toString(),
  ]),
  [
    ["int", "1"],
    ["bool", "true"],
    ["string", "ion"],
  ],
)

const richText = "ann::{a: 1, a: 2, decimal: 12.30, timestamp: 2024-01-02T03:04:05.123Z, blob: {{aGk=}}, clob: {{\"hi\"}}, sexp: (add 1)}"
const richValues = Ion.dom.loadAll(richText)
assert.equal(richValues.length, 1)
assert.equal(richValues[0].getType().name, "struct")
assert.equal(richValues[0].getAnnotations()[0], "ann")
assert.equal(richValues[0].fields().length, 6)
const richFields = richValues[0].allFields()
assert.equal(richFields[0][0], "a")
assert.deepEqual(richFields[0][1].map((value) => value.toString()), ["1", "2"])
assert.equal(richFields[1][0], "decimal")

const encoded = Ion.dumpBinary(richValues[0])
const decoded = Ion.dom.loadAll(encoded)
assert.equal(decoded.length, 1)
assert.equal(decoded[0].getType().name, "struct")
assert.equal(decoded[0].getAnnotations()[0], "ann")
assert.equal(decoded[0].fields().length, 6)
assert.deepEqual(decoded[0].allFields()[0][1].map((value) => value.toString()), ["1", "2"])

const malformed = fixture("invalid/truncated-binary.hex")
  .toString("ascii")
  .replace(/#[^\n]*|\s+/g, "")
assert.throws(() => Ion.loadAll(Buffer.from(malformed, "hex")))

console.log(JSON.stringify({
  oracle: "amazon-ion/ion-js",
  version: "5.2.1",
  checks: [
    "binary scalar fixture",
    "annotated ordered struct text parse",
    "binary round-trip",
    "truncated binary rejection",
  ],
  result: "passed",
}))
