export class SessionAuthError extends Error {
  constructor(message = "Invalid Cursor session token") {
    super(message);
    this.name = "SessionAuthError";
  }
}

/**
 * Builds a `WorkosCursorSessionToken` cookie value from a raw JWT or a
 * preformed `sub::jwt` / `sub%3A%3Ajwt` string. Ported from AIMeterCore's
 * SessionCookieBuilder — do not log the result.
 */
export function cookieValueFromStoredToken(token: string): string {
  const trimmed = token.trim();
  if (!trimmed) {
    throw new SessionAuthError("Session token is empty");
  }
  if (trimmed.includes("::") || trimmed.includes("%3A%3A")) {
    return trimmed.replaceAll("::", "%3A%3A");
  }
  const sub = extractJwtSub(trimmed);
  const userSub = sub.includes("|") ? sub.split("|").pop() ?? sub : sub;
  return `${userSub}%3A%3A${trimmed}`;
}

export function extractJwtSub(jwt: string): string {
  const parts = jwt.split(".");
  if (parts.length < 2) {
    throw new SessionAuthError();
  }
  const payload = padBase64(parts[1].replaceAll("-", "+").replaceAll("_", "/"));
  let json: unknown;
  try {
    json = JSON.parse(Buffer.from(payload, "base64").toString("utf8"));
  } catch {
    throw new SessionAuthError();
  }
  if (!json || typeof json !== "object" || typeof (json as { sub?: unknown }).sub !== "string") {
    throw new SessionAuthError();
  }
  return (json as { sub: string }).sub;
}

function padBase64(value: string): string {
  const pad = (4 - (value.length % 4)) % 4;
  return value + "=".repeat(pad);
}
