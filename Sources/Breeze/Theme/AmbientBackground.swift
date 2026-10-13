import SwiftUI

/// Soft, animated backdrop of blurred color blobs in the current mode's palette.
struct AmbientBackground: View {
    let colors: [Color]
    var intensity: Double = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(colors[0].opacity(0.45 * intensity))
                    .frame(width: geo.size.width * 0.9)
                    .offset(x: -geo.size.width * 0.3, y: -geo.size.height * 0.35)
                Circle()
                    .fill(colors[1].opacity(0.4 * intensity))
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.35, y: geo.size.height * 0.4)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .blur(radius: 90)
        }
        .animation(.smooth(duration: 0.8), value: colors)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
