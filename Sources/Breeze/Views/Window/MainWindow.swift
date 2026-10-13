import BreezeKit
import SwiftUI

struct MainWindow: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        ZStack {
            AmbientBackground(colors: controller.palette)
                .ignoresSafeArea()

            switch controller.phase {
            case .signedOut:
                SignInView()
                    .frame(width: 340)
                    .padding(28)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Connecting to your AC…").foregroundStyle(.secondary)
                    if let message = controller.errorMessage {
                        ErrorBanner(message: message).frame(width: 360)
                    }
                }
            case .ready:
                if controller.selectedDevice == nil {
                    ContentUnavailableView("No air conditioners", systemImage: "air.conditioner.horizontal",
                                           description: Text("Add your AC in the TCL Home app, then refresh."))
                } else {
                    ResponsiveDeviceLayout()
                }
            }
        }
        .frame(minWidth: 440, minHeight: 560)
        .animation(.smooth, value: controller.phase)
        .toolbar {
            if controller.phase != .signedOut {
                ToolbarItem {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await controller.reload() }
                    }
                }
                ToolbarItem {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
        }
    }
}

/// Two columns when there's room, otherwise a single scrolling column.
/// The dial scales to whatever space is available.
private struct ResponsiveDeviceLayout: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        GeometryReader { geo in
            if geo.size.width >= 780 && geo.size.height >= 500 {
                wide(geo.size)
            } else {
                stacked(geo.size)
            }
        }
    }

    private func wide(_ size: CGSize) -> some View {
        let hPad: CGFloat = 32, gap: CGFloat = 28
        let switcherHeight: CGFloat = controller.devices.count > 1 ? 68 : 0
        let rightWidth = min(440, max(340, (size.width - hPad * 2 - gap) * 0.46))
        let leftWidth = size.width - hPad * 2 - gap - rightWidth
        // Height left after header (52), step row (44) and the four 18pt gaps (72).
        let availableHeight = size.height - switcherHeight - 8 - 24 - 52 - 44 - 72
        // The dial's drawn footprint is ~1.07 × size + 8 (ring + knob padding).
        let dialSize = min(max((min(leftWidth - 40, availableHeight) - 8) / 1.07, 180), 400)

        return VStack(alignment: .leading, spacing: 18) {
            DeviceSwitcher()
            HStack(alignment: .top, spacing: gap) {
                VStack(spacing: 18) {
                    DeviceHeader()
                    Spacer(minLength: 0)
                    TemperatureDial(size: dialSize)
                    Spacer(minLength: 0)
                    StepRow()
                }
                .frame(width: leftWidth)
                .frame(maxHeight: .infinity)

                ScrollView(showsIndicators: false) {
                    ControlCards()
                }
                .scrollClipDisabled()
                .frame(width: rightWidth)
            }
        }
        .padding(.horizontal, hPad)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(width: size.width, height: size.height)
    }

    private func stacked(_ size: CGSize) -> some View {
        let width = min(size.width - 48, 520)
        let dialSize = min(max(width - 100, 180), 300)

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                DeviceSwitcher()
                DeviceHeader()
                TemperatureDial(size: dialSize)
                StepRow()
                ControlCards()
            }
            .frame(width: width)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct DeviceHeader: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(controller.selectedDevice?.name ?? "")
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(1)
                    .contentTransition(.opacity)
                StatusPill()
            }
            Spacer()
            PowerButton(size: 52)
        }
    }
}

private struct StepRow: View {
    var body: some View {
        HStack(spacing: 14) {
            TemperatureStepButton(delta: -1)
            Text("Drag the dial or use − / +")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            TemperatureStepButton(delta: 1)
        }
    }
}

private struct ControlCards: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        VStack(spacing: 16) {
            GlassCard(title: "Mode", symbol: "slider.horizontal.3") {
                ModePicker()
            }
            GlassCard {
                FanControl()
            }
            if !controller.profile.features.isEmpty {
                GlassCard(title: "Features", symbol: "sparkles") {
                    FeatureTiles()
                }
            }
            if let message = controller.errorMessage {
                ErrorBanner(message: message)
            }
        }
    }
}
