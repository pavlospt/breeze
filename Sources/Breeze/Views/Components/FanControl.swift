import BreezeKit
import SwiftUI

/// An "Auto" chip plus ascending level bars for the manual fan speeds.
struct FanControl: View {
    @Environment(ACController.self) private var controller
    var compact = false

    var body: some View {
        let speeds = controller.profile.fanSpeeds
        let auto = speeds.first(where: \.isAuto)
        let levels = speeds.filter { !$0.isAuto }
        let current = controller.fanSpeed
        let currentLevel = levels.firstIndex { $0 == current }

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "fan")
                    .symbolEffect(.rotate, options: .repeat(.continuous), isActive: controller.isOn)
                    .foregroundStyle(controller.isOn ? controller.tint : .secondary)
                Text("Fan").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(current?.name ?? "—")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .contentTransition(.interpolate)
            }

            HStack(alignment: .bottom, spacing: compact ? 5 : 7) {
                if let auto {
                    autoChip(auto, isSelected: current == auto)
                }
                ForEach(Array(levels.enumerated()), id: \.element.id) { index, speed in
                    levelBar(speed, index: index, isLit: currentLevel.map { index <= $0 } ?? false)
                }
            }
            .animation(.smooth(duration: 0.3), value: current)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fan speed")
    }

    private var barAreaHeight: CGFloat { compact ? 30 : 36 }

    private func autoChip(_ speed: FanSpeed, isSelected: Bool) -> some View {
        Button { controller.send(speed.command) } label: {
            Text("AUTO")
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: compact ? 44 : 52, height: barAreaHeight)
        }
        .buttonStyle(.plain)
        .glassEffect(.toggled(isSelected, tint: controller.tint), in: .rect(cornerRadius: 10))
        .padding(.trailing, 4)
        .accessibilityLabel("Automatic fan speed")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func levelBar(_ speed: FanSpeed, index: Int, isLit: Bool) -> some View {
        Button { controller.send(speed.command) } label: {
            RoundedRectangle(cornerRadius: 4)
                .fill(isLit
                      ? AnyShapeStyle(LinearGradient(colors: controller.palette, startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(.primary.opacity(0.22)))
                .frame(maxWidth: .infinity)
                .frame(height: (compact ? 10 : 12) + CGFloat(index) * (compact ? 3 : 4))
                .frame(height: barAreaHeight, alignment: .bottom)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help(speed.name)
        .accessibilityLabel(speed.name)
        .accessibilityAddTraits(controller.fanSpeed == speed ? .isSelected : [])
    }
}
