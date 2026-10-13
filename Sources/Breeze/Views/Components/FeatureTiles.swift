import BreezeKit
import SwiftUI

/// Toggle tiles for the extras the selected device reports (swing, eco, sleep, …).
struct FeatureTiles: View {
    @Environment(ACController.self) private var controller
    var compact = false

    var body: some View {
        let features = controller.profile.features
        if !features.isEmpty {
            GlassEffectContainer(spacing: 8) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                         count: min(features.count, compact ? 5 : 3)),
                          spacing: 8) {
                    ForEach(features) { tile($0) }
                }
            }
        }
    }

    private func tile(_ feature: FeatureToggle) -> some View {
        let isOn = feature.isOn(in: controller.state)
        return Button {
            controller.send(isOn ? feature.offCommand : feature.onCommand)
        } label: {
            Group {
                if compact {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 15, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: feature.symbolName)
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 20)
                        Text(feature.name).font(.system(size: 12, weight: .medium))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                }
            }
            .foregroundStyle(isOn ? .white : .primary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.toggled(isOn, tint: controller.tint), in: .rect(cornerRadius: 12))
        .animation(.smooth, value: isOn)
        .help(feature.name)
        .accessibilityLabel(feature.name)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
