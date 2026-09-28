import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { cookieValueFromStoredToken, extractJwtSub, SessionAuthError } from "./SessionCookie";

function jwtWithSub(sub: string): string {
  const payload = Buffer.from(JSON.stringify({ sub }), "utf8").toString("base64url");
  return `eyJhbGciOiJub25lIn0.${payload}.sig`;
}

describe("SessionCookie", () => {
  it("encodes a raw JWT as userId%3A%3Ajwt", () => {
    const jwt = jwtWithSub("user_01EXAMPLE");
    assert.equal(cookieValueFromStoredToken(jwt), `user_01EXAMPLE%3A%3A${jwt}`);
  });

  it("uses the last segment when sub contains a pipe", () => {
    const jwt = jwtWithSub("auth0|user_99");
    assert.equal(cookieValueFromStoredToken(jwt), `user_99%3A%3A${jwt}`);
  });

  it("encodes a preformed sub::jwt cookie", () => {
    assert.equal(cookieValueFromStoredToken("abc::token.parts"), "abc%3A%3Atoken.parts");
  });

  it("leaves an already-encoded cookie alone", () => {
    assert.equal(cookieValueFromStoredToken("abc%3A%3Atoken"), "abc%3A%3Atoken");
  });

  it("rejects garbage tokens", () => {
    assert.throws(() => extractJwtSub("not-a-jwt"), SessionAuthError);
    assert.throws(() => cookieValueFromStoredToken("   "), SessionAuthError);
  });
});
