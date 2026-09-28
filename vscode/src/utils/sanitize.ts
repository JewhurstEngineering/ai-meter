const SENSITIVE = /authorization|cookie|set-cookie|token|session|jwt|email|account.?id|user.?id/i;

export function sanitize(message: string): string {
  return message
    .split("\n")
    .map((line) => (SENSITIVE.test(line) ? "[redacted]" : line))
    .join("\n");
}
