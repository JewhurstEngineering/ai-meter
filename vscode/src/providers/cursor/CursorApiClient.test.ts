import assert from "node:assert/strict";
import { describe, it } from "node:test";
import { CursorApiClient, PersonalApiError, type FetchLike } from "./CursorApiClient";

describe("PersonalApiError", () => {
  it("keeps last numbers for decode, empty, 429, and 5xx", () => {
    assert.equal(new PersonalApiError("decodingFailed").keepsLastNumbers, true);
    assert.equal(new PersonalApiError("emptyResponse", 204).keepsLastNumbers, true);
    assert.equal(PersonalApiError.fromStatus(429).keepsLastNumbers, true);
    assert.equal(PersonalApiError.fromStatus(503).keepsLastNumbers, true);
    assert.equal(PersonalApiError.fromStatus(401).keepsLastNumbers, false);
    assert.equal(PersonalApiError.fromStatus(403).keepsLastNumbers, false);
  });
});

describe("CursorApiClient", () => {
  it("fetches me, summary, stripe, and aggregated usage", async () => {
    const calls: string[] = [];
    const fetchImpl: FetchLike = async (input, init) => {
      const url = String(input);
      calls.push(`${init?.method ?? "GET"} ${url}`);
      if (url.endsWith("/api/auth/me")) {
        return json({ sub: "user_01EXAMPLE", id: 123 });
      }
      if (url.endsWith("/api/usage-summary")) {
        return json({
          billingCycleStart: "2026-08-01T00:00:00.000Z",
          billingCycleEnd: "2026-09-01T00:00:00.000Z",
          membershipType: "pro",
          individualUsage: { plan: { autoPercentUsed: 10 } },
        });
      }
      if (url.endsWith("/api/auth/stripe")) {
        return json({ membershipType: "pro" });
      }
      if (url.endsWith("/api/dashboard/get-sand-usage-status")) {
        const body = JSON.parse(String(init?.body));
        assert.deepEqual(body, {});
        return json({ usagePercent: 18, hasNonZeroIncludedLimit: true });
      }
      if (url.endsWith("/api/dashboard/get-aggregated-usage-events")) {
        const body = JSON.parse(String(init?.body));
        assert.equal(body.teamId, 0);
        assert.equal(body.userId, 123);
        assert.match(String(body.startDate), /^\d+$/);
        return json({ aggregations: [{ modelIntent: "composer", totalCents: 1 }] });
      }
      return new Response("missing", { status: 404 });
    };

    const client = new CursorApiClient(fetchImpl);
    const payload = await client.fetchUsage("abc%3A%3Atoken");
    assert.equal(payload.me.id, 123);
    assert.equal(payload.summary.membershipType, "pro");
    assert.equal(payload.aggregated?.aggregations?.[0]?.modelIntent, "composer");
    assert.equal(payload.sand?.usagePercent, 18);
    assert.deepEqual(calls.map((line) => line.replace("https://cursor.com", "")), [
      "GET /api/auth/me",
      "GET /api/usage-summary",
      "GET /api/auth/stripe",
      "POST /api/dashboard/get-sand-usage-status",
      "POST /api/dashboard/get-aggregated-usage-events",
    ]);
  });

  it("treats 401 as unauthorized", async () => {
    const fetchImpl: FetchLike = async () => new Response("no", { status: 401 });
    const client = new CursorApiClient(fetchImpl);
    await assert.rejects(
      () => client.fetchUsage("abc%3A%3Atoken"),
      (error: unknown) => error instanceof PersonalApiError && error.kind === "unauthorized"
    );
  });

  it("keeps the rest of usage when Grok Bot status fails", async () => {
    const fetchImpl: FetchLike = async (input) => {
      const url = String(input);
      if (url.endsWith("/api/auth/me")) {
        return json({ sub: "user_01EXAMPLE", id: 1 });
      }
      if (url.endsWith("/api/usage-summary")) {
        return json({ membershipType: "pro", individualUsage: { plan: { autoPercentUsed: 4 } } });
      }
      if (url.endsWith("/api/dashboard/get-sand-usage-status")) {
        return new Response("no", { status: 500 });
      }
      return json({});
    };
    const client = new CursorApiClient(fetchImpl);
    const payload = await client.fetchUsage("abc%3A%3Atoken");
    assert.equal(payload.summary.membershipType, "pro");
    assert.equal(payload.sand, undefined);
  });

  it("returns empty summary on 204", async () => {
    const fetchImpl: FetchLike = async (input) => {
      const url = String(input);
      if (url.endsWith("/api/auth/me")) {
        return json({ sub: "user_01EXAMPLE", id: 1 });
      }
      if (url.endsWith("/api/usage-summary")) {
        return new Response(null, { status: 204 });
      }
      return new Response("{}", {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    };
    const client = new CursorApiClient(fetchImpl);
    const payload = await client.fetchUsage("abc%3A%3Atoken");
    assert.deepEqual(payload.summary, {});
  });
});

function json(body: unknown): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
}
