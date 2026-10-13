import Foundation

/// A selectable fan speed and the shadow properties that select it.
public struct FanSpeed: Identifiable, Hashable, Sendable {
    public let name: String
    public let command: ACCommand
    public var id: String { name }

    public var isAuto: Bool { name == "Auto" }

    /// True when the state matches every property this speed sets. Properties the
    /// device doesn't report are ignored, but `windSpeed` must be present.
    public func matches(_ state: ACState) -> Bool {
        guard state.has(ACState.Key.windSpeed) else { return false }
        return command.allSatisfy { key, value in state.int(key).map { $0 == value } ?? true }
    }
}

/// An on/off feature, shown only when the device reports `key`.
public struct FeatureToggle: Identifiable, Hashable, Sendable {
    public let key: String
    public let name: String
    public let symbolName: String
    public let onCommand: ACCommand
    public let offCommand: ACCommand
    public var id: String { key }

    public func isOn(in state: ACState) -> Bool {
        let value = state.int(key) ?? 0
        // Vertical swing values 1–3 are swing modes; 8+ are fixed louver positions.
        return key == "verticalDirection" ? (1...3).contains(value) : value != 0
    }

    public static let all: [FeatureToggle] = [
        FeatureToggle(key: "verticalDirection", name: "Swing", symbolName: "arrow.up.and.down.circle",
                      onCommand: ["verticalSwitch": 1, "verticalDirection": 1],
                      offCommand: ["verticalSwitch": 0, "verticalDirection": 11]),
        FeatureToggle(key: "swingWind", name: "Swing", symbolName: "arrow.up.and.down.circle",
                      onCommand: ["swingWind": 1], offCommand: ["swingWind": 0]),
        FeatureToggle(key: "ECO", name: "Eco", symbolName: "leaf",
                      onCommand: ["ECO": 1], offCommand: ["ECO": 0]),
        FeatureToggle(key: "sleep", name: "Sleep", symbolName: "moon.zzz",
                      onCommand: ["sleep": 1], offCommand: ["sleep": 0]),
        FeatureToggle(key: "screen", name: "Display", symbolName: "lightbulb.max",
                      onCommand: ["screen": 1], offCommand: ["screen": 0]),
        FeatureToggle(key: "beepSwitch", name: "Beep", symbolName: "speaker.wave.2",
                      onCommand: ["beepSwitch": 1], offCommand: ["beepSwitch": 0]),
    ]
}

/// What a given device type supports and how UI concepts map to its shadow properties.
/// Mappings follow github.com/nemesa/ha-tcl-home-unofficial-integration.
public struct DeviceProfile: Sendable {
    /// Supported modes; a mode's index is its `workMode` value.
    public let modes: [ACMode]
    public let fanSpeeds: [FanSpeed]
    public let features: [FeatureToggle]
    public let temperatureRange: ClosedRange<Int> = 16...31

    public func mode(in state: ACState) -> ACMode? {
        guard let wm = state.workMode, modes.indices.contains(wm) else { return nil }
        return modes[wm]
    }

    public func fanSpeed(in state: ACState) -> FanSpeed? {
        fanSpeeds.last { $0.matches(state) }
    }

    public func command(for mode: ACMode, in state: ACState) -> ACCommand? {
        guard let wm = modes.firstIndex(of: mode) else { return nil }
        var command: ACCommand = [ACState.Key.workMode: wm]
        if state.has(ACState.Key.turbo) { command[ACState.Key.turbo] = 0 }
        return command
    }

    public static func `for`(_ device: ACDevice, state: ACState) -> DeviceProfile {
        forType(device.type, state: state)
    }

    /// - Parameter deviceType: TCL's device-type string; unknown types get the split-AC profile.
    public static func forType(_ deviceType: String, state: ACState) -> DeviceProfile {
        // Some devices report a numbered type, e.g. "Split AC-2".
        let type = deviceType.replacingOccurrences(of: #"-\d+$"#, with: "", options: .regularExpression)
        let features = FeatureToggle.all.filter { state.has($0.key) }

        switch type {
        case "Window AC":
            return DeviceProfile(modes: [.auto, .cool, .dry, .fan], fanSpeeds: [
                FanSpeed(name: "Auto", command: ["windSpeed": 0]),
                FanSpeed(name: "Low", command: ["windSpeed": 2]),
                FanSpeed(name: "Medium", command: ["windSpeed": 4]),
                FanSpeed(name: "High", command: ["windSpeed": 6]),
            ], features: features)

        case "Portable AC" where state.has("swingWind"):
            return DeviceProfile(modes: [.auto, .cool, .dry, .fan], fanSpeeds: [
                FanSpeed(name: "Auto", command: ["windSpeed": 0]),
                FanSpeed(name: "Low", command: ["windSpeed": 1]),
                FanSpeed(name: "High", command: ["windSpeed": 2]),
            ], features: features)

        case "Portable AC":
            return DeviceProfile(modes: [.cool, .dry, .fan], fanSpeeds: [
                FanSpeed(name: "Low", command: ["windSpeed": 0]),
                FanSpeed(name: "High", command: ["windSpeed": 1]),
            ], features: features)

        default:
            // Split AC and its variants (fresh air, cylindrical, duct).
            func split(_ speed: Int, turbo: Int = 0, silence: Int = 0) -> ACCommand {
                ["windSpeed": speed, "turbo": turbo, "silenceSwitch": silence, "highTemperatureWind": 0]
            }
            return DeviceProfile(modes: [.auto, .cool, .dry, .fan, .heat], fanSpeeds: [
                FanSpeed(name: "Auto", command: split(0)),
                FanSpeed(name: "Mute", command: split(2, silence: 1)),
                FanSpeed(name: "Low", command: split(2)),
                FanSpeed(name: "Mid-low", command: split(3)),
                FanSpeed(name: "Medium", command: split(4)),
                FanSpeed(name: "Mid-high", command: split(5)),
                FanSpeed(name: "High", command: split(6)),
                FanSpeed(name: "Turbo", command: split(6, turbo: 1)),
            ], features: features)
        }
    }
}
