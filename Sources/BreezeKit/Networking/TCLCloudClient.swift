import Foundation
import os

/// Talks to TCL Home's (unofficial) cloud the same way the Android app does.
///
/// Session flow: account login → regional cloud URLs → SaaS + Cognito tokens →
/// temporary AWS credentials → AWS IoT device shadows. Reverse-engineered from
/// github.com/nemesa/ha-tcl-home-unofficial-integration.
public actor TCLCloudClient: ACService {
    private enum Endpoint {
        static let login = URL(string: "https://pa.account.tcl.com/account/login?clientId=54148614")!
        static let cloudURLs = URL(string: "https://prod-center.aws.tcljd.com/v3/global/cloud_url_get")!
        static let appID = "wx6e1af3fa84fbe523"
    }

    private struct Session {
        var ssoToken: String
        var username: String
        var cloudURL: URL
        var deviceURL: URL
        var region: String
        var saasToken: String
        var aws: AWSCredentials

        var isValid: Bool {
            aws.expiration > .now.addingTimeInterval(120) && !JWT.isExpired(ssoToken)
        }
    }

    private let credentials: Credentials
    private let urlSession: URLSession
    private var session: Session?

    public init(credentials: Credentials, urlSession: URLSession = .shared) {
        self.credentials = credentials
        self.urlSession = urlSession
    }

    // MARK: ACService

    public func devices() async throws -> [ACDevice] {
        try await withSession { session in
            let timestamp = String(Int(Date.now.timeIntervalSince1970 * 1000))
            let nonce = String((0..<16).map { _ in "abcdefghijklmnopqrstuvwxyz0123456789".randomElement()! })
            let json = try await self.post(
                session.deviceURL.appending(path: "v3/user/get_things"), body: [String: String](),
                step: "Device list",
                headers: [
                    "platform": "android", "appversion": "5.4.1", "thomeversion": "4.8.1",
                    "accesstoken": session.saasToken, "accept-language": "en",
                    "timestamp": timestamp, "nonce": nonce,
                    "sign": Hex.md5(timestamp + nonce + session.saasToken),
                ])
            guard case .array(let list)? = json["data"] else {
                throw ACServiceError.unexpectedResponse(step: "Device list")
            }
            return list.compactMap(Self.device(from:))
        }
    }

    public func state(of deviceID: String) async throws -> ACState {
        try await withSession { session in
            let request = SigV4Signer.Request(
                method: "GET", host: Self.iotHost(session.region),
                pathSegments: ["things", deviceID, "shadow"])
            let json = try await self.send(self.signer(session).sign(request), step: "Read state")
            guard case .object(let reported)? = json["state"]?["reported"] else { return ACState() }
            return ACState(reported: reported)
        }
    }

    public func send(_ command: ACCommand, to deviceID: String) async throws {
        try await withSession { session in
            struct ShadowUpdate: Encodable {
                struct State: Encodable { let desired: ACCommand }
                let state: State
                let clientToken: String
            }
            let payload = try JSONEncoder().encode(ShadowUpdate(
                state: .init(desired: command),
                clientToken: "mobile_\(Int(Date.now.timeIntervalSince1970))"))
            let request = SigV4Signer.Request(
                method: "POST", host: Self.iotHost(session.region),
                pathSegments: ["topics", "$aws/things/\(deviceID)/shadow/update"],
                query: [("qos", "1")], body: payload)
            Logger.cloud.debug("Sending \(command) to \(deviceID)")
            _ = try await self.send(self.signer(session).sign(request), step: "Send command")
        }
    }

    // MARK: Session

    /// Runs `operation` with a valid session; on an auth failure, signs in again once and retries.
    private func withSession<T: Sendable>(_ operation: (Session) async throws -> T) async throws -> T {
        do {
            return try await operation(try await validSession())
        } catch let error as ACServiceError where error.isAuthFailure {
            Logger.cloud.info("Auth failure, re-establishing session")
            session = nil
            return try await operation(try await validSession())
        }
    }

    private func validSession() async throws -> Session {
        if let session, session.isValid { return session }
        let new = try await establishSession()
        session = new
        return new
    }

    private func establishSession() async throws -> Session {
        Logger.cloud.info("Establishing session")

        // 1. Account login (the password is sent MD5-hashed, like the app does).
        struct LoginBody: Encodable {
            let equipment = 2, osType = 1, captchaRule = 2
            let password: String, username: String
            let clientVersion = "4.8.1", osVersion = "6.0", channel = "app"
            let deviceModel = "AndroidAndroid SDK built for x86"
        }
        let login = try await post(
            Endpoint.login,
            body: LoginBody(password: Hex.md5(credentials.password), username: credentials.email),
            step: "Sign-in",
            headers: ["th_platform": "android", "th_version": "4.8.1", "th_appbulid": "830"])
        guard login["status"]?.numberValue == 1,
              let ssoToken = login["token"]?.stringValue,
              let username = login["user"]?["username"]?.stringValue
        else {
            throw ACServiceError.invalidCredentials(
                login[anyOf: "msg", "message"]?.stringValue ?? "Check your email and password.")
        }

        // 2. Regional endpoints.
        let urls = try await post(Endpoint.cloudURLs, body: ["ssoId": username, "ssoToken": ssoToken], step: "Cloud URLs")
        guard let data = urls["data"],
              let cloudURL = data[anyOf: "cloud_url", "cloudUrl"]?.stringValue.flatMap(URL.init(string:)),
              let deviceURL = data[anyOf: "device_url", "deviceUrl"]?.stringValue.flatMap(URL.init(string:)),
              let region = data[anyOf: "cloud_region", "cloudRegion"]?.stringValue
        else { throw ACServiceError.unexpectedResponse(step: "Cloud URLs") }

        // 3. SaaS + Cognito tokens.
        let tokens = try await post(
            cloudURL.appending(path: "v3/auth/refresh_tokens"),
            body: ["userId": username, "ssoToken": ssoToken, "appId": Endpoint.appID],
            step: "Token refresh")
        guard let tokenData = tokens["data"],
              let saasToken = tokenData[anyOf: "saas_token", "saasToken"]?.stringValue,
              let cognitoToken = tokenData[anyOf: "cognito_token", "cognitoToken"]?.stringValue
        else { throw ACServiceError.unexpectedResponse(step: "Token refresh") }

        // 4. Exchange the Cognito OpenID token for temporary AWS credentials.
        let aws = try await awsCredentials(region: region, cognitoToken: cognitoToken)

        return Session(ssoToken: ssoToken, username: username, cloudURL: cloudURL, deviceURL: deviceURL,
                       region: region, saasToken: saasToken, aws: aws)
    }

    private func awsCredentials(region: String, cognitoToken: String) async throws -> AWSCredentials {
        struct Body: Encodable {
            let IdentityId: String
            let Logins: [String: String]
        }
        var request = URLRequest(url: URL(string: "https://cognito-identity.\(region).amazonaws.com/")!)
        request.httpMethod = "POST"
        request.setValue("AWSCognitoIdentityService.GetCredentialsForIdentity", forHTTPHeaderField: "X-Amz-Target")
        request.setValue("application/x-amz-json-1.1", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Body(
            IdentityId: JWT.claims(cognitoToken)["sub"]?.stringValue ?? "",
            Logins: ["cognito-identity.amazonaws.com": cognitoToken]))

        let json = try await send(request, step: "AWS credentials")
        guard let c = json["Credentials"],
              let accessKeyID = c["AccessKeyId"]?.stringValue,
              let secretKey = c["SecretKey"]?.stringValue,
              let sessionToken = c["SessionToken"]?.stringValue,
              let expiration = c["Expiration"]?.numberValue
        else { throw ACServiceError.unexpectedResponse(step: "AWS credentials") }
        return AWSCredentials(accessKeyID: accessKeyID, secretKey: secretKey, sessionToken: sessionToken,
                              expiration: Date(timeIntervalSince1970: expiration))
    }

    // MARK: Helpers

    private static func iotHost(_ region: String) -> String { "data-ats.iot.\(region).amazonaws.com" }

    private func signer(_ session: Session) -> SigV4Signer {
        SigV4Signer(region: session.region, service: "iotdata", credentials: session.aws)
    }

    static func device(from json: JSONValue) -> ACDevice? {
        guard let id = json[anyOf: "deviceId", "device_id"]?.stringValue else { return nil }
        let type = json[anyOf: "deviceName", "device_name"]?.stringValue ?? "Unknown"
        var name = json[anyOf: "nickName", "nick_name"]?.stringValue
        if name == nil, case .array(let labels)? = json["labels"] {
            name = labels.first { $0["labelKey"]?.stringValue == "room" }?["labelValue"]?.stringValue
        }
        let online = json[anyOf: "isOnline", "is_online"]?.numberValue == 1
        return ACDevice(id: id, name: name ?? type, type: type, isOnline: online)
    }

    private func post(_ url: URL, body: some Encodable, step: String,
                      headers: [String: String] = [:]) async throws -> JSONValue {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Android", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers { request.setValue(value, forHTTPHeaderField: field) }
        request.httpBody = try JSONEncoder().encode(body)
        return try await send(request, step: step)
    }

    private func send(_ request: URLRequest, step: String) async throws -> JSONValue {
        var request = request
        request.timeoutInterval = 15
        let (data, response) = try await urlSession.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            Logger.cloud.error("\(step) failed with HTTP \(status)")
            throw ACServiceError.http(step: step, status: status, body: String(decoding: data, as: UTF8.self))
        }
        guard !data.isEmpty else { return .null }
        return (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .null
    }
}
