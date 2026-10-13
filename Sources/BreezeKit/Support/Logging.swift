import os

extension Logger {
    static let subsystem = "com.ptournaris.Breeze"
    static let cloud = Logger(subsystem: subsystem, category: "cloud")
    static let keychain = Logger(subsystem: subsystem, category: "keychain")
}
