import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { sanitize } from "./sanitize";

describe("sanitize", () => {
  it("redacts credential-like lines", () => {
    assert.equal(sanitize("Cookie: WorkosCursorSessionToken=abc"), "[redacted]");
    assert.equal(sanitize("Authorization: Bearer x"), "[redacted]");
    assert.equal(sanitize("Refresh succeeded"), "Refresh succeeded");
  });
});
