import SwiftUI
import WidgetKit

struct CircularComplicationView: View {
    let entry: WaveTimelineEntry

    /// Small offset to separate arrows when they nearly overlap
    private var windNudge: Double {
        guard let waveDir = entry.waveDirection,
              let windDir = entry.windDirection else { return 0 }
        let diff = (windDir - waveDir)
            .truncatingRemainder(dividingBy: 360)
        let normalized = diff < -180 ? diff + 360 : (diff > 180 ? diff - 360 : diff)
        if abs(normalized) < 15 {
            return normalized >= 0 ? 15 : -15
        }
        return 0
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let outerRadius = size / 2 - 1
            let tickOuterRadius = outerRadius

            ZStack {
                // Compass tick marks — skip cardinal positions (replaced by labels)
                ForEach(0..<60, id: \.self) { i in
                    if i % 15 != 0 {
                        let angle = Double(i) * 6.0
                        let isIntercardinal = i % 5 == 0
                        let tickLen: CGFloat = isIntercardinal ? 3.5 : 2
                        let tickWidth: CGFloat = isIntercardinal ? 1 : 0.75
                        let opacity: Double = isIntercardinal ? 0.7 : 0.35

                        let rad = (angle - 90) * .pi / 180
                        let outerX = cos(rad) * tickOuterRadius
                        let outerY = sin(rad) * tickOuterRadius
                        let innerX = cos(rad) * (tickOuterRadius - tickLen)
                        let innerY = sin(rad) * (tickOuterRadius - tickLen)

                        Path { path in
                            path.move(to: CGPoint(x: size / 2 + outerX, y: size / 2 + outerY))
                            path.addLine(to: CGPoint(x: size / 2 + innerX, y: size / 2 + innerY))
                        }
                        .stroke(.white.opacity(opacity), lineWidth: tickWidth)
                    }
                }

                // Cardinal direction labels — just inside the perimeter
                let labelRadius = outerRadius - 2
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { idx, label in
                    let angle = Double(idx) * 90.0
                    let rad = (angle - 90) * .pi / 180
                    Text(label)
                        .font(.system(size: size * 0.14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .position(
                            x: size / 2 + cos(rad) * labelRadius,
                            y: size / 2 + sin(rad) * labelRadius
                        )
                }

                // Wave needle (cyan) — full width, full opacity
                if let dir = entry.waveDirection {
                    ComplicationNeedle()
                        .fill(.cyan)
                        .frame(width: 10, height: outerRadius * 2)
                        .rotationEffect(.degrees(dir + 180))
                }

                // Wind needle (white) — full width, full opacity
                if let windDir = entry.windDirection {
                    ComplicationNeedle()
                        .fill(.white)
                        .frame(width: 10, height: outerRadius * 2)
                        .rotationEffect(.degrees(windDir + windNudge + 180))
                }

                // Center text overlapping the needles
                VStack(spacing: -1) {
                    if let wind = entry.compactWindString {
                        Text(wind)
                            .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.6)
                    }
                    Text(entry.compactHeightString)
                        .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 3)
                .background(
                    Capsule()
                        .fill(.black)
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Full-diameter compass needle — bold arrow tip, tapered tail
struct ComplicationNeedle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let mid = h / 2

        // Top half: compact pointed arrowhead
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w, y: mid * 0.4))
        path.addLine(to: CGPoint(x: w * 0.5, y: mid * 0.3))
        path.addLine(to: CGPoint(x: 0, y: mid * 0.4))
        path.closeSubpath()

        // Bottom half: pointed tail extending to opposite edge
        var tail = Path()
        tail.move(to: CGPoint(x: w * 0.35, y: mid * 0.3))
        tail.addLine(to: CGPoint(x: w * 0.65, y: mid * 0.3))
        tail.addLine(to: CGPoint(x: w * 0.5, y: h))
        tail.closeSubpath()

        path.addPath(tail)
        return path
    }
}
