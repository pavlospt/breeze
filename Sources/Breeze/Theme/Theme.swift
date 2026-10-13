import BreezeKit
import SwiftUI

/// Mode-driven palette shared by the window and the menu bar panel.
extension ACMode {
    var colors: [Color] {
        switch self {
        case .cool: [Color(red: 0.35, green: 0.85, blue: 1.0), Color(red: 0.15, green: 0.45, blue: 1.0)]
        case .heat: [Color(red: 1.0, green: 0.72, blue: 0.3), Color(red: 1.0, green: 0.35, blue: 0.25)]
        case .dry: [Color(red: 0.45, green: 0.95, blue: 0.85), Color(red: 0.1, green: 0.65, blue: 0.75)]
        case .fan: [Color(red: 0.6, green: 0.95, blue: 0.6), Color(red: 0.2, green: 0.75, blue: 0.5)]
        case .auto: [Color(red: 0.8, green: 0.6, blue: 1.0), Color(red: 0.45, green: 0.35, blue: 1.0)]
        }
    }

    var tint: Color { colors[1] }
}

enum Palette {
    static let off: [Color] = [Color.gray.opacity(0.7), Color.gray.opacity(0.45)]
}

extension ACController {
    /// Colors for the selected device's current state; muted when it's off.
    var palette: [Color] {
        guard isOn, let mode else { return Palette.off }
        return mode.colors
    }

    var tint: Color { palette[1] }
}

/// Glass that picks up a tint when `isActive`, with interactive press feedback.
extension Glass {
    static func toggled(_ isActive: Bool, tint: Color) -> Glass {
        isActive ? .regular.tint(tint).interactive() : .regular.interactive()
    }
}
