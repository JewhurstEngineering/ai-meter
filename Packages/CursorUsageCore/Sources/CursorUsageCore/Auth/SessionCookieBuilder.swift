import Foundation

/// Builds `WorkosCursorSessionToken` cookie values from a raw JWT or preformed `sub::jwt`.
public enum SessionCookieBuilder {
    public static func cookieValue(fromStoredToken token: String) throws -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("::") || trimmed.contains("%3A%3A") {
            return trimmed.replacingOccurrences(of: "::", with: "%3A%3A")
        }
        let sub = try JWTSub.extract(from: trimmed)
        let userSub = sub.contains("|") ? String(sub.split(separator: "|").last!) : sub
        return "\(userSub)%3A%3A\(trimmed)"
    }
}

enum JWTSub {
    static func extract(from jwt: String) throws -> String {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else { throw SessionAuthError.invalidToken }
        var payload = String(parts[1])
        let pad = (4 - payload.count % 4) % 4
        payload += String(repeating: "=", count: pad)
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String
        else {
            throw SessionAuthError.invalidToken
        }
        return sub
    }
}

public enum SessionAuthError: Error, Sendable {
    case invalidToken
    case notAuthenticated
    case missingCredential
}
