import BreezeKit
import SwiftUI

struct MenuBarLabel: View {
    @Environment(ACController.self) private var controller
    @AppStorage(DefaultsKey.showTemperatureInMenuBar) private var showTemperature = true

    var body: some View {
        if controller.isOn, let temperature = controller.state.targetTemperature {
            Image(systemName: controller.mode?.symbolName ?? "snowflake")
            if showTemperature { Text("\(temperature)°") }
        } else {
            Image(systemName: "air.conditioner.horizontal")
        }
    }
}

/// The compact control panel shown from the menu bar.
struct MenuBarPanel: View {
    @Environment(ACController.self) private var controller
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 14) {
            switch controller.phase {
            case .signedOut:
                SignInView(compact: true)
            case .loading:
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 120)
            case .ready where controller.selectedDevice == nil:
                Text("No air conditioners found.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            case .ready:
                DeviceSwitcher(compact: true)
                header
                HStack(spacing: 0) {
                    TemperatureStepButton(delta: -1, size: 34)
                    Spacer(minLength: 0)
                    TemperatureDial(size: 170)
                    Spacer(minLength: 0)
                    TemperatureStepButton(delta: 1, size: 34)
                }
                ModePicker(compact: true)
                FanControl(compact: true)
                FeatureTiles(compact: true)
            }
            if let message = controller.errorMessage {
                ErrorBanner(message: message)
            }
            footer
        }
        .padding(16)
        .frame(width: 330)
        .background(AmbientBackground(colors: controller.palette, intensity: 0.6))
        .animation(.smooth, value: controller.isOn)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(controller.selectedDevice?.name ?? "")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                StatusPill()
            }
            Spacer()
            PowerButton(size: 38)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Button {
                openWindow(id: SceneID.main)
                NSApp.activate()
            } label: {
                Label("Open Breeze", systemImage: "macwindow")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .frame(height: 28)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)

            Spacer()

            if controller.phase != .signedOut {
                Button {
                    Task { await controller.reload() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
                .help("Refresh")
                .accessibilityLabel("Refresh")
            }

            Menu {
                SettingsLink { Text("Settings…") }
                Divider()
                Button("Quit Breeze") { NSApplication.shared.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel("More")
        }
    }
}
