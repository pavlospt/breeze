import Observation
import ServiceManagement

/// Wraps `SMAppService` so the Settings toggle reflects the system's login-item state.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var errorMessage: String?

    func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}
