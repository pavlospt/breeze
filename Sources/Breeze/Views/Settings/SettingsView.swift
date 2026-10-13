import BreezeKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Account", systemImage: "person.crop.circle") { AccountSettings() }
        }
        .frame(width: 460)
        .scenePadding()
    }
}

private struct GeneralSettings: View {
    @Environment(LaunchAtLogin.self) private var launchAtLogin
    @AppStorage(DefaultsKey.refreshInterval) private var refreshInterval = 30
    @AppStorage(DefaultsKey.showTemperatureInMenuBar) private var showTemperature = true

    var body: some View {
        Form {
            Toggle("Open Breeze at login", isOn: Binding(
                get: { launchAtLogin.isEnabled },
                set: { launchAtLogin.set($0) }))
            if let message = launchAtLogin.errorMessage {
                Text(message).font(.caption).foregroundStyle(.red)
            }
            Toggle("Show temperature in menu bar", isOn: $showTemperature)
            Picker("Refresh status every", selection: $refreshInterval) {
                Text("15 seconds").tag(15)
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("5 minutes").tag(300)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AccountSettings: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        Form {
            if let account = controller.account {
                LabeledContent("TCL Home account", value: account)
                LabeledContent("Devices", value: "\(controller.devices.count)")
                Button("Sign Out", role: .destructive) { controller.signOut() }
            } else {
                Text("Not signed in. Open Breeze to sign in.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
