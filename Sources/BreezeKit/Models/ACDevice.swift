import Foundation

/// An air conditioner registered to the user's TCL Home account.
public struct ACDevice: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// TCL's device-type string, e.g. "Split AC", "Portable AC", "Window AC".
    public let type: String
    public let isOnline: Bool

    public init(id: String, name: String, type: String, isOnline: Bool) {
        self.id = id
        self.name = name
        self.type = type
        self.isOnline = isOnline
    }
}
