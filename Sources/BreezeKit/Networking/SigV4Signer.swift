import CryptoKit
import Foundation

/// Temporary AWS credentials vended by Cognito.
public struct AWSCredentials: Sendable {
    public let accessKeyID: String
    public let secretKey: String
    public let sessionToken: String
    public let expiration: Date
}

/// Minimal AWS Signature Version 4 signer for the AWS IoT data-plane REST API.
struct SigV4Signer {
    let region: String
    let service: String
    let credentials: AWSCredentials

    struct Request {
        var method: String
        var host: String
        /// Raw, unencoded path segments.
        var pathSegments: [String]
        var query: [(String, String)] = []
        var body = Data()
    }

    /// RFC 3986 encoding of everything except unreserved characters.
    static func uriEncode(_ s: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.~")
        return s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
    }

    static func amzDate(_ date: Date) -> String {
        date.formatted(Date.VerbatimFormatStyle(
            format: "\(year: .defaultDigits)\(month: .twoDigits)\(day: .twoDigits)T\(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased))\(minute: .twoDigits)\(second: .twoDigits)Z",
            timeZone: .gmt, calendar: Calendar(identifier: .gregorian)))
    }

    func canonicalQuery(_ request: Request) -> String {
        request.query
            .map { (Self.uriEncode($0.0), Self.uriEncode($0.1)) }
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "&")
    }

    func canonicalRequest(_ request: Request, amzDate: String) -> String {
        // Non-S3 services double-encode the path in the canonical request.
        let path = "/" + request.pathSegments.map { Self.uriEncode(Self.uriEncode($0)) }.joined(separator: "/")
        return [
            request.method, path, canonicalQuery(request),
            "host:\(request.host)\nx-amz-date:\(amzDate)\nx-amz-security-token:\(credentials.sessionToken)\n",
            Self.signedHeaders, Hex.sha256(request.body),
        ].joined(separator: "\n")
    }

    func signature(_ request: Request, date: Date) -> String {
        let amzDate = Self.amzDate(date)
        let dateStamp = String(amzDate.prefix(8))
        let scope = "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256", amzDate, scope, Hex.sha256(Data(canonicalRequest(request, amzDate: amzDate).utf8)),
        ].joined(separator: "\n")

        var key = SymmetricKey(data: Data("AWS4\(credentials.secretKey)".utf8))
        for part in [dateStamp, region, service, "aws4_request"] {
            key = SymmetricKey(data: Self.hmac(key, part))
        }
        return Hex.string(Self.hmac(key, stringToSign))
    }

    func sign(_ request: Request, date: Date = .now) -> URLRequest {
        let amzDate = Self.amzDate(date)
        let scope = "\(amzDate.prefix(8))/\(region)/\(service)/aws4_request"

        var components = URLComponents()
        components.scheme = "https"
        components.host = request.host
        components.percentEncodedPath = "/" + request.pathSegments.map(Self.uriEncode).joined(separator: "/")
        let query = canonicalQuery(request)
        if !query.isEmpty { components.percentEncodedQuery = query }

        var urlRequest = URLRequest(url: components.url!)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body.isEmpty ? nil : request.body
        urlRequest.setValue(amzDate, forHTTPHeaderField: "X-Amz-Date")
        urlRequest.setValue(credentials.sessionToken, forHTTPHeaderField: "X-Amz-Security-Token")
        urlRequest.setValue(
            "AWS4-HMAC-SHA256 Credential=\(credentials.accessKeyID)/\(scope), "
                + "SignedHeaders=\(Self.signedHeaders), Signature=\(signature(request, date: date))",
            forHTTPHeaderField: "Authorization")
        return urlRequest
    }

    private static let signedHeaders = "host;x-amz-date;x-amz-security-token"

    private static func hmac(_ key: SymmetricKey, _ message: String) -> Data {
        Data(HMAC<SHA256>.authenticationCode(for: Data(message.utf8), using: key))
    }
}
