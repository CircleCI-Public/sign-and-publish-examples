const test = require("node:test");
const assert = require("node:assert/strict");
const { helloWorld } = require("./index");

test("helloWorld returns default greeting", () => {
  assert.equal(helloWorld(), "Hello, world!");
});

test("helloWorld returns greeting for provided name", () => {
  assert.equal(helloWorld("CircleCI"), "Hello, CircleCI!");
});
