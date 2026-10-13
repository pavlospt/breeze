import BreezeKit
import SwiftUI

/// Glass chips for switching between ACs; each shows that unit's live mode and temperature.
/// Hidden when the account has a single device.
struct DeviceSwitcher: View {
    @Environment(ACController.self) private var controller
    var compact = false
    @Namespace private var namespace

    var body: some View {
        if controller.devices.count > 1 {
            // A plain row when the chips fit; otherwise a scrolling row that fades out at the edges.
            ViewThatFits(in: .horizontal) {
                chips
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        chips.padding(.horizontal, 2)
                    }
                    .onChange(of: controller.selectedID, initial: true) { _, id in
                        withAnimation(.smooth) { proxy.scrollTo(id, anchor: .center) }
                    }
                }
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.03),
                                           .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                   startPoint: .leading, endPoint: .trailing)
                }
            }
        }
    }

    private var chips: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(controller.devices) { chip(for: $0) }
            }
        }
        .padding(.vertical, 4)
        .fixedSize()
    }

    private func chip(for device: ACDevice) -> some View {
        let isSelected = device.id == controller.selectedID
        let state = controller.states[device.id] ?? ACState()
        let mode = controller.mode(of: device)
        let tint = (state.isOn ? mode?.tint : nil) ?? .gray

        return Button {
            withAnimation(.smooth(duration: 0.45)) { controller.selectedID = device.id }
        } label: {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(isSelected ? AnyShapeStyle(.white.opacity(0.25))
                                             : AnyShapeStyle(tint.opacity(state.isOn ? 0.2 : 0.12)))
                    Image(systemName: state.isOn ? (mode?.symbolName ?? "snowflake") : "power")
                        .font(.system(size: compact ? 10 : 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : (state.isOn ? tint : .secondary))
                }
                .frame(width: compact ? 22 : 28, height: compact ? 22 : 28)

                VStack(alignment: .leading, spacing: 0) {
                    Text(device.name)
                        .font(.system(size: compact ? 11 : 13, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle(device, state: state, mode: mode))
                        .font(.system(size: compact ? 9 : 10, weight: .medium))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.8)) : AnyShapeStyle(.secondary))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(isSelected ? .white : .primary)
            }
            .padding(.leading, compact ? 5 : 6)
            .padding(.trailing, compact ? 11 : 14)
            .frame(height: compact ? 34 : 42)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.toggled(isSelected, tint: tint), in: .capsule)
        .glassEffectID(device.id, in: namespace)
        .id(device.id)
        .opacity(device.isOnline ? 1 : 0.6)
        .accessibilityLabel("\(device.name), \(subtitle(device, state: state, mode: mode))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func subtitle(_ device: ACDevice, state: ACState, mode: ACMode?) -> String {
        guard device.isOnline else { return "Offline" }
        guard state.isOn else { return "Off" }
        return [mode?.rawValue, state.targetTemperature.map { "\($0)°" }]
            .compactMap { $0 }
            .joined(separator: " · ")
    }
}
