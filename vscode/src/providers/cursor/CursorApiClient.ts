import type {
  AggregatedUsageResponse,
  AuthMeResponse,
  AuthStripeResponse,
  SandUsageStatus,
  UsageSummaryResponse,
} from "./CursorTypes";
import { cookieValueFromStoredToken } from "./SessionCookie";

const BASE_URL = "https://cursor.com";
const USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15";
const TIMEOUT_MS = 20_000;

export type PersonalApiErrorKind =
  | "unauthorized"
  | "emptyResponse"
  | "decodingFailed"
  | "httpStatus";

export class PersonalApiError extends Error {
  readonly kind: PersonalApiErrorKind;
  readonly status?: number;

  constructor(kind: PersonalApiErrorKind, status?: number, message?: string) {
    super(message ?? kind);
    this.name = "PersonalApiError";
    this.kind = kind;
    this.status = status;
  }

  get keepsLastNumbers(): boolean {
    if (this.kind === "decodingFailed" || this.kind === "emptyResponse") {
      return true;
    }
    if (this.kind === "httpStatus" && this.status != null) {
      return this.status === 429 || (this.status >= 500 && this.status <= 599);
    }
    return false;
  }

  get userMessage(): string {
    switch (this.kind) {
      case "unauthorized":
        return "Session expired — sign in again.";
      case "decodingFailed":
        return "Cursor’s usage API changed. Last numbers are kept.";
      case "emptyResponse":
        return "Cursor returned an empty usage response. Last numbers are kept.";
      case "httpStatus":
        if (this.status != null && this.status >= 500) {
          return `Cursor’s servers returned an error (${this.status}). Try again in a few minutes.`;
        }
        return this.status != null
          ? `Usage refresh failed (HTTP ${this.status}).`
          : "Usage refresh failed.";
    }
  }

  static fromStatus(status: number): PersonalApiError {
    if (status === 401) {
      return new PersonalApiError("unauthorized", 401);
    }
    if (status === 204) {
      return new PersonalApiError("emptyResponse", 204);
    }
    return new PersonalApiError("httpStatus", status);
  }
}

export interface CursorUsagePayload {
  me: AuthMeResponse;
  summary: UsageSummaryResponse;
  stripe?: AuthStripeResponse;
  aggregated?: AggregatedUsageResponse;
  sand?: SandUsageStatus;
}

export type FetchLike = (input: string | URL | Request, init?: RequestInit) => Promise<Response>;

export class CursorApiClient {
  constructor(private readonly fetchImpl: FetchLike = fetch) {}

  async fetchUsage(sessionToken: string): Promise<CursorUsagePayload> {
    const cookie = cookieValueFromStoredToken(sessionToken);
    const me = await this.getJson<AuthMeResponse>("/api/auth/me", cookie);
    if (me.sub == null && me.id == null) {
      throw new PersonalApiError("unauthorized", 401);
    }

    const summary = await this.getJson<UsageSummaryResponse>("/api/usage-summary", cookie, {
      emptyOnNoContent: {},
    });

    let stripe: AuthStripeResponse | undefined;
    try {
      stripe = await this.getJson<AuthStripeResponse>("/api/auth/stripe", cookie);
    } catch {
      stripe = undefined;
    }

    let sand: SandUsageStatus | undefined;
    try {
      sand = await this.postJson<SandUsageStatus>(
        "/api/dashboard/get-sand-usage-status",
        cookie,
        {}
      );
    } catch {
      sand = undefined;
    }

    let aggregated: AggregatedUsageResponse | undefined;
    if (
      me.id != null &&
      summary.billingCycleStart &&
      summary.billingCycleEnd
    ) {
      const start = Date.parse(summary.billingCycleStart);
      const end = Date.parse(summary.billingCycleEnd);
      if (!Number.isNaN(start) && !Number.isNaN(end)) {
        try {
          aggregated = await this.postJson<AggregatedUsageResponse>(
            "/api/dashboard/get-aggregated-usage-events",
            cookie,
            {
              teamId: 0,
              startDate: String(Math.round(start)),
              endDate: String(Math.round(end)),
              userId: me.id,
            }
          );
        } catch {
          aggregated = undefined;
        }
      }
    }

    return { me, summary, stripe, sand, aggregated };
  }

  async validate(sessionToken: string): Promise<AuthMeResponse> {
    const cookie = cookieValueFromStoredToken(sessionToken);
    return this.getJson<AuthMeResponse>("/api/auth/me", cookie);
  }

  private async getJson<T>(
    path: string,
    cookie: string,
    options: { emptyOnNoContent?: T } = {}
  ): Promise<T> {
    const response = await this.send(path, cookie, { method: "GET" });
    return this.readJson(response, options.emptyOnNoContent);
  }

  private async postJson<T>(path: string, cookie: string, body: unknown): Promise<T> {
    const response = await this.send(path, cookie, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Origin: BASE_URL,
      },
      body: JSON.stringify(body),
    });
    return this.readJson(response);
  }

  private async send(path: string, cookie: string, init: RequestInit): Promise<Response> {
    const headers = new Headers(init.headers);
    headers.set("Cookie", `WorkosCursorSessionToken=${cookie}`);
    headers.set("User-Agent", USER_AGENT);
    return this.fetchImpl(new URL(path, BASE_URL), {
      ...init,
      headers,
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
  }

  private async readJson<T>(response: Response, emptyOnNoContent?: T): Promise<T> {
    const raw = await response.arrayBuffer();
    const empty = raw.byteLength === 0;
    if (response.status === 204 || (response.status === 200 && empty)) {
      if (emptyOnNoContent !== undefined) {
        return emptyOnNoContent;
      }
      throw new PersonalApiError("emptyResponse", response.status);
    }
    const classified = PersonalApiError.fromStatus(response.status);
    if (classified.kind === "unauthorized") {
      throw classified;
    }
    if (response.status < 200 || response.status >= 300) {
      throw classified;
    }
    try {
      const text = new TextDecoder().decode(raw);
      return JSON.parse(text) as T;
    } catch {
      throw new PersonalApiError("decodingFailed", response.status);
    }
  }
}
