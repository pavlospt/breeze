import BreezeKit
import SwiftUI

/// A 270° arc dial. Drag anywhere on the ring to set the target temperature.
struct TemperatureDial: View {
    @Environment(ACController.self) private var controller
    var size: CGFloat = 280

    @State private var dragValue: Int?

    private var lineWidth: CGFloat { size * 0.07 }
    private var range: ClosedRange<Int> { controller.profile.temperatureRange }
    private var span: Int { range.upperBound - range.lowerBound }
    private var displayed: Int? { dragValue ?? controller.state.targetTemperature }
    private var fraction: Double {
        guard let displayed else { return 0 }
        return Double(displayed - range.lowerBound) / Double(span)
    }
    private static let sweep = 0.75 // 270° of the circle

    var body: some View {
        ZStack {
            track
            ticks
            progress
            knob
            readout
        }
        .frame(width: size, height: size)
        .padding(lineWidth / 2 + 4)
        .contentShape(Circle())
        .gesture(drag)
        .sensoryFeedback(.alignment, trigger: dragValue) { _, new in new != nil }
        .animation(.smooth(duration: 0.35), value: fraction)
        .animation(.smooth, value: controller.palette)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Target temperature")
        .accessibilityValue(displayed.map { "\($0) degrees Celsius" } ?? "Unavailable")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: controller.adjustTemperature(by: 1)
            case .decrement: controller.adjustTemperature(by: -1)
            @unknown default: break
            }
        }
    }

    private var track: some View {
        Circle().trim(from: 0, to: Self.sweep)
            .stroke(.primary.opacity(0.08), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(135))
    }

    private var ticks: some View {
        ForEach(0...span, id: \.self) { i in
            Capsule()
                .fill(.primary.opacity(i % 5 == 0 ? 0.25 : 0.1))
                .frame(width: 2, height: i % 5 == 0 ? 9 : 5)
                .offset(y: -(size / 2 - lineWidth - 12))
                .rotationEffect(.degrees(-135 + 270 * Double(i) / Double(span)))
        }
    }

    private var progress: some View {
        Circle().trim(from: 0, to: Self.sweep * fraction)
            .stroke(
                AngularGradient(colors: controller.palette, center: .center,
                                startAngle: .zero, endAngle: .degrees(270 * max(fraction, 0.01))),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(135))
            .shadow(color: controller.tint.opacity(controller.canAdjustTemperature ? 0.55 : 0), radius: 14)
    }

    private var knob: some View {
        Circle()
            .fill(.white)
            .frame(width: lineWidth + 8, height: lineWidth + 8)
            .shadow(color: .black.opacity(0.25), radius: 4, y: 1)
            .overlay(Circle().fill(controller.tint).frame(width: lineWidth - 6))
            .offset(y: -size / 2)
            .rotationEffect(.degrees(-135 + 270 * fraction))
            .opacity(controller.canAdjustTemperature ? 1 : 0)
    }

    private var readout: some View {
        VStack(spacing: size * 0.01) {
            Text(controller.isOn ? (controller.mode?.rawValue.uppercased() ?? "") : "OFF")
                .font(.system(size: size * 0.05, weight: .semibold))
                .tracking(2)
                .foregroundStyle(controller.isOn ? AnyShapeStyle(controller.tint) : AnyShapeStyle(.secondary))
            HStack(alignment: .top, spacing: 2) {
                Text(displayed.map(String.init) ?? "--")
                    .font(.system(size: size * 0.3, weight: .thin, design: .rounded))
                    .contentTransition(.numericText(value: Double(displayed ?? 0)))
                    .monospacedDigit()
                Text("°C")
                    .font(.system(size: size * 0.07, weight: .light, design: .rounded))
                    .padding(.top, size * 0.06)
                    .foregroundStyle(.secondary)
            }
            .opacity(controller.mode?.usesTargetTemperature == false ? 0.35 : 1)
            if let room = controller.state.currentTemperature {
                Label("Room \(room)°", systemImage: "house")
                    .font(.system(size: size * 0.048, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard controller.canAdjustTemperature else { return }
                let center = (size + lineWidth + 8) / 2
                let dx = value.location.x - center, dy = value.location.y - center
                // Ignore drags in the middle of the dial.
                guard hypot(dx, dy) > size * 0.3 else { return }
                var degrees = atan2(dy, dx) * 180 / .pi // clockwise from +x (y points down)
                if degrees < 135 { degrees += 360 }
                var f = (degrees - 135) / 270
                if f > 1 { f = f < 1 + (90.0 / 270 / 2) ? 1 : 0 } // in the bottom gap: snap to nearest end
                dragValue = range.lowerBound + Int((f * Double(span)).rounded())
            }
            .onEnded { _ in
                if let dragValue { controller.setTemperature(dragValue) }
                dragValue = nil
            }
    }
}
