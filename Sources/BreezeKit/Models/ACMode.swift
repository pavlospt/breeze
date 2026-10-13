import Foundation

public enum ACMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "Auto"
    case cool = "Cool"
    case dry = "Dry"
    case fan = "Fan"
    case heat = "Heat"

    public var id: String { rawValue }

    public var symbolName: String {
        switch self {
        case .auto: "a.circle"
        case .cool: "snowflake"
        case .dry: "drop"
        case .fan: "fan"
        case .heat: "sun.max"
        }
    }

    /// Whether the target temperature applies in this mode.
    public var usesTargetTemperature: Bool { self != .fan }
}
