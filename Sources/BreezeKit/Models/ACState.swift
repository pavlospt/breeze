import Foundation

/// A desired-state update: TCL shadow property names mapped to integer values.
public typealias ACCommand = [String: Int]

/// The reported state of a device, taken from its AWS IoT shadow.
///
/// TCL devices report a flat set of numeric properties (`powerSwitch`, `workMode`,
/// `targetTemperature`, …). Which ones are present depends on the model, so the raw
/// values are kept and exposed through typed accessors.
public struct ACState: Equatable, Sendable {
    public private(set) var properties: [String: Double]

    public init(properties: [String: Double] = [:]) {
        self.properties = properties
    }

    public var isEmpty: Bool { properties.isEmpty }

    public func has(_ key: String) -> Bool { properties[key] != nil }

    public func int(_ key: String) -> Int? { properties[key].map { Int($0) } }

    public var isOn: Bool { int(Key.power) == 1 }
    public var workMode: Int? { int(Key.workMode) }
    public var targetTemperature: Int? { int(Key.targetTemperature) }
    public var currentTemperature: Int? { int(Key.currentTemperature) }

    /// Applies a command locally (used for optimistic UI updates).
    public mutating func apply(_ command: ACCommand) {
        for (key, value) in command { properties[key] = Double(value) }
    }

    public func applying(_ command: ACCommand) -> ACState {
        var copy = self
        copy.apply(command)
        return copy
    }

    /// Shadow property names used across the app.
    public enum Key {
        public static let power = "powerSwitch"
        public static let workMode = "workMode"
        public static let targetTemperature = "targetTemperature"
        public static let currentTemperature = "currentTemperature"
        public static let windSpeed = "windSpeed"
        public static let turbo = "turbo"
    }
}

extension ACState {
    /// Builds a state from a decoded shadow, keeping numeric and boolean values.
    init(reported: [String: JSONValue]) {
        var props: [String: Double] = [:]
        for (key, value) in reported {
            if let n = value.numberValue { props[key] = n }
        }
        self.init(properties: props)
    }
}
