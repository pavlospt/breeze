import BreezeKit
import SwiftUI

struct ModePicker: View {
    @Environment(ACController.self) private var controller
    var compact = false
    @Namespace private var namespace

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(controller.profile.modes) { mode in
                    button(for: mode)
                }
            }
        }
    }

    private func button(for mode: ACMode) -> some View {
        let isSelected = controller.isOn && controller.mode == mode
        return Button {
            withAnimation(.smooth) { controller.setMode(mode) }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.symbolName)
                    .font(.system(size: compact ? 15 : 18, weight: .medium))
                    .symbolEffect(.bounce, value: isSelected)
                Text(mode.rawValue)
                    .font(.system(size: compact ? 10 : 11, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 48 : 60)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.toggled(isSelected, tint: mode.tint), in: .rect(cornerRadius: compact ? 14 : 18))
        .glassEffectID(mode.id, in: namespace)
        .accessibilityLabel("\(mode.rawValue) mode")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
