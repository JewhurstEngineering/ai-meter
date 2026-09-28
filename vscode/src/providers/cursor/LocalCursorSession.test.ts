import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { cursorStateDbPath } from "./LocalCursorSession";

describe("cursorStateDbPath", () => {
  it("points at Cursor's macOS state.vscdb", () => {
    assert.equal(
      cursorStateDbPath("darwin", "/Users/you"),
      "/Users/you/Library/Application Support/Cursor/User/globalStorage/state.vscdb"
    );
  });

  it("points at Cursor's Linux config dir", () => {
    assert.equal(
      cursorStateDbPath("linux", "/home/you"),
      "/home/you/.config/Cursor/User/globalStorage/state.vscdb"
    );
  });
});
