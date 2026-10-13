import Foundation
import Testing
@testable import BreezeKit

@Suite("Parsing")
struct ParsingTests {
    func json(_ string: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(string.utf8))
    }

    @Test func stateKeepsNumericAndBooleanValues() throws {
        let shadow = try json(#"{"powerSwitch":1,"targetTemperature":22.0,"flag":true,"name":"x","nested":{"a":1}}"#)
        guard case .object(let reported) = shadow else { Issue.record("Not an object"); return }
        let state = ACState(reported: reported)
        #expect(state.isOn)
        #expect(state.targetTemperature == 22)
        #expect(state.int("flag") == 1)
        #expect(!state.has("name"))
        #expect(!state.has("nested"))
    }

    @Test func applyingCommandUpdatesState() {
        let state = ACState(properties: ["powerSwitch": 0, "targetTemperature": 24])
            .applying(["powerSwitch": 1, "targetTemperature": 20])
        #expect(state.isOn)
        #expect(state.targetTemperature == 20)
    }

    @Test func parsesDeviceWithCamelCaseKeys() throws {
        let device = TCLCloudClient.device(from: try json(
            #"{"deviceId":"abc","nickName":"Office","deviceName":"Split AC","isOnline":"1"}"#))
        #expect(device == ACDevice(id: "abc", name: "Office", type: "Split AC", isOnline: true))
    }

    @Test func parsesDeviceWithSnakeCaseKeysAndRoomLabel() throws {
        let device = TCLCloudClient.device(from: try json(
            #"{"device_id":"xyz","device_name":"Portable AC","is_online":0,"labels":[{"labelKey":"room","labelValue":"Bedroom"}]}"#))
        #expect(device == ACDevice(id: "xyz", name: "Bedroom", type: "Portable AC", isOnline: false))
    }

    @Test func skipsDeviceWithoutID() throws {
        #expect(TCLCloudClient.device(from: try json(#"{"nickName":"Ghost"}"#)) == nil)
    }

    @Test func anyOfPrefersFirstNonNullKey() throws {
        let value = try json(#"{"saas_token":null,"saasToken":"t"}"#)
        #expect(value[anyOf: "saas_token", "saasToken"]?.stringValue == "t")
    }
}

@Suite("JWT")
struct JWTTests {
    /// Builds an unsigned JWT with the given claims.
    func token(_ claims: String) -> String {
        let payload = Data(claims.utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        return "eyJhbGciOiJub25lIn0.\(payload).sig"
    }

    @Test func readsClaims() {
        #expect(JWT.claims(token(#"{"sub":"us-east-1:abc"}"#))["sub"]?.stringValue == "us-east-1:abc")
        #expect(JWT.claims("not-a-jwt").isEmpty)
    }

    @Test func detectsExpiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(JWT.isExpired(token(#"{"exp":1000030}"#), leeway: 60, now: now))
        #expect(!JWT.isExpired(token(#"{"exp":1000120}"#), leeway: 60, now: now))
        #expect(!JWT.isExpired(token(#"{"sub":"x"}"#), now: now))
    }

    @Test func md5MatchesKnownDigest() {
        #expect(Hex.md5("password") == "5f4dcc3b5aa765d61d8327deb882cf99")
    }
}
