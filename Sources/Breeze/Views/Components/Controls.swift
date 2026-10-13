import BreezeKit
import SwiftUI

struct PowerButton: View {
    @Environment(ACController.self) private var controller
    var size: CGFloat = 44

    var body: some View {
        Button { controller.setPower(!controller.isOn) } label: {
            Image(systemName: "power")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(controller.isOn ? .white : .secondary)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(.toggled(controller.isOn, tint: controller.tint), in: .circle)
        .shadow(color: controller.isOn ? controller.tint.opacity(0.5) : .clear, radius: 10)
        .animation(.smooth, value: controller.isOn)
        .help(controller.isOn ? "Turn off" : "Turn on")
        .accessibilityLabel("Power")
        .accessibilityValue(controller.isOn ? "On" : "Off")
    }
}

/// Round − / + button that nudges the target temperature by `delta`.
struct TemperatureStepButton: View {
    @Environment(ACController.self) private var controller
    let delta: Int
    var size: CGFloat = 44

    var body: some View {
        Button { controller.adjustTemperature(by: delta) } label: {
            Image(systemName: delta < 0 ? "minus" : "plus")
                .font(.system(size: size * 0.36, weight: .semibold))
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .disabled(!controller.canAdjustTemperature)
        .opacity(controller.canAdjustTemperature ? 1 : 0.4)
        .accessibilityLabel(delta < 0 ? "Decrease temperature" : "Increase temperature")
    }
}

struct StatusPill: View {
    @Environment(ACController.self) private var controller

    var body: some View {
        let isOnline = controller.selectedDevice?.isOnline == true
        HStack(spacing: 5) {
            Circle()
                .fill(isOnline ? Color.green : Color.gray)
                .frame(width: 6, height: 6)
                .shadow(color: isOnline ? .green : .clear, radius: 3)
            Text(isOnline ? "Online" : "Offline")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 11))
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A titled glass card used to group controls in the window.
struct GlassCard<Content: View>: View {
    var title: String?
    var symbol: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                Label(title, systemImage: symbol ?? "circle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}
