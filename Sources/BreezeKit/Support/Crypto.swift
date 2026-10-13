import CryptoKit
import Foundation

enum Hex {
    static func string<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func md5(_ string: String) -> String {
        Hex.string(Insecure.MD5.hash(data: Data(string.utf8)))
    }

    static func sha256(_ data: Data) -> String {
        Hex.string(SHA256.hash(data: data))
    }
}

/// Reads claims from a JWT without verifying its signature.
enum JWT {
    static func claims(_ token: String) -> [String: JSONValue] {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return [:] }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64),
              case .object(let claims)? = try? JSONDecoder().decode(JSONValue.self, from: data)
        else { return [:] }
        return claims
    }

    /// True when the token expires within `leeway` seconds. Tokens without `exp` never expire.
    static func isExpired(_ token: String, leeway: TimeInterval = 60, now: Date = .now) -> Bool {
        guard let exp = claims(token)["exp"]?.numberValue else { return false }
        return Date(timeIntervalSince1970: exp) < now.addingTimeInterval(leeway)
    }
}
