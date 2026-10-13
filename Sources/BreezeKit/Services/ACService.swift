import Foundation

/// Account credentials for the TCL Home cloud.
public struct Credentials: Equatable, Sendable {
    public let email: String
    public let password: String

    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Abstraction over the AC backend, so the app can run against the real cloud or a mock.
public protocol ACService: Sendable {
    /// Lists the account's devices. Also used to validate credentials at sign-in.
    func devices() async throws -> [ACDevice]
    func state(of deviceID: String) async throws -> ACState
    func send(_ command: ACCommand, to deviceID: String) async throws
}

public enum ACServiceError: LocalizedError, Equatable {
    case invalidCredentials(String)
    case http(step: String, status: Int, body: String)
    case unexpectedResponse(step: String)

    public var errorDescription: String? {
        switch self {
        case .invalidCredentials(let message):
            "Sign-in failed: \(message)"
        case .http(let step, let status, let body):
            "\(step) failed (HTTP \(status)): \(body.prefix(200))"
        case .unexpectedResponse(let step):
            "Unexpected response from \(step)."
        }
    }

    var isAuthFailure: Bool {
        if case .http(_, let status, _) = self { return status == 401 || status == 403 }
        return false
    }
}
