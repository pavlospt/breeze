import BreezeKit
import Foundation

/// In-memory backend with sample units. Powers `--demo` mode and SwiftUI previews.
actor DemoACService: ACService {
    private var states: [String: ACState] = [
        "living": ACState(properties: [
            "powerSwitch": 1, "workMode": 1, "targetTemperature": 22, "currentTemperature": 27,
            "windSpeed": 4, "turbo": 0, "silenceSwitch": 0, "highTemperatureWind": 0,
            "verticalSwitch": 1, "verticalDirection": 1, "ECO": 0, "sleep": 0, "screen": 1,
        ]),
        "bedroom": ACState(properties: [
            "powerSwitch": 0, "workMode": 4, "targetTemperature": 24, "currentTemperature": 19,
            "windSpeed": 0, "turbo": 0, "silenceSwitch": 0, "highTemperatureWind": 0,
            "verticalDirection": 11, "ECO": 1, "sleep": 0, "screen": 1,
        ]),
        "office": ACState(properties: [
            "powerSwitch": 1, "workMode": 0, "targetTemperature": 23, "currentTemperature": 24,
            "windSpeed": 0, "turbo": 0, "silenceSwitch": 0, "highTemperatureWind": 0,
            "verticalDirection": 11, "ECO": 0, "sleep": 0, "screen": 0,
        ]),
    ]

    func devices() async throws -> [ACDevice] {
        [
            ACDevice(id: "living", name: "Living Room", type: "Split AC", isOnline: true),
            ACDevice(id: "bedroom", name: "Bedroom", type: "Split AC", isOnline: true),
            ACDevice(id: "office", name: "Office", type: "Split AC", isOnline: true),
        ]
    }

    func state(of deviceID: String) async throws -> ACState { states[deviceID] ?? ACState() }

    func send(_ command: ACCommand, to deviceID: String) async throws {
        states[deviceID, default: ACState()].apply(command)
    }
}

/// Credentials held only in memory (demo mode and previews never touch the Keychain).
final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var credentials: Credentials?

    init(_ credentials: Credentials? = nil) { self.credentials = credentials }

    func load() -> Credentials? { lock.withLock { credentials } }
    func save(_ credentials: Credentials) throws { lock.withLock { self.credentials = credentials } }
    func delete() { lock.withLock { credentials = nil } }
}
