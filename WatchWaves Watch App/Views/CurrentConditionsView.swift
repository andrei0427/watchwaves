import SwiftUI

enum ConditionsMode { case compass, conditions }

struct CurrentConditionsView: View {
    let mode: ConditionsMode
    let condition: WaveCondition
    let useMetric: Bool
    let coastDirection: CompassDirection?
    var heading: Double?
    var lastUpdated: Date?
    var beachName: String?
    var coastBearing: Double?
    var coastDistanceKm: Double?
    var onTap: () -> Void = {}

    @State private var smoothRotation: Double = 0

    private var gradientIntensity: Double {
        min(condition.waveHeight / 5.0, 1.0)
    }

    private var relativeWaveDir: Double {
        guard let heading else { return condition.waveDirection }
        return condition.waveDirection - heading
    }

    private var relativeWindDir: Double? {
        guard let windDir = condition.windDirection else { return nil }
        guard let heading else { return windDir }
        return windDir - heading
    }

    private var windNudge: Double {
        guard let windDir = relativeWindDir else { return 0 }
        let diff = (windDir - relativeWaveDir)
            .truncatingRemainder(dividingBy: 360)
        let normalized = diff < -180 ? diff + 360 : (diff > 180 ? diff - 360 : diff)
        if abs(normalized) < 10 {
            return normalized >= 0 ? 10 : -10
        }
        return 0
    }

    var body: some View {
        ZStack {
            // Main content
            VStack(spacing: 5) {
                // Coast label
                if let name = beachName {
                    HStack(spacing: 4) {
                        Text(name)
                        if let dist = coastDistanceKm {
                            Text("·")
                            Text(coastDistanceString(dist))
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                } else if let coast = coastDirection {
                    Text("\(coast.label) Coast")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Water temperature — secondary measure
                if let sst = condition.seaSurfaceTemperature {
                    Text(WaveFormatter.temperatureString(sst, useMetric: useMetric))
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }

                // Hero wave direction
                HStack(spacing: 6) {
                    Text(condition.directionLabel)
                    DirectionIndicatorView(degrees: condition.waveDirection, size: 28)
                }
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                // Wave pill
                HStack(spacing: 6) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 10))
                    Text(WaveFormatter.heightString(condition.waveHeight, useMetric: useMetric))
                    Text(WaveFormatter.periodString(condition.wavePeriod))
                }
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.cyan.opacity(0.25), in: .capsule)

                // Wind pill
                if let windSpeed = condition.windSpeed,
                   let windDir = condition.windDirection {
                    HStack(spacing: 6) {
                        Image(systemName: "wind")
                            .font(.system(size: 10))
                        if let label = condition.windDirectionLabel {
                            Text(label)
                        }
                        DirectionIndicatorView(degrees: windDir, size: 10)
                        Text(WaveFormatter.windString(windSpeed, useMetric: useMetric))
                    }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: .capsule)
                }

                // Swell footer
                if let swellHeight = condition.swellHeight,
                   let swellPeriod = condition.swellPeriod {
                    HStack(spacing: 5) {
                        Text("Swell")
                        Text(WaveFormatter.heightString(swellHeight, useMetric: useMetric))
                        if let dir = condition.swellDirection {
                            DirectionIndicatorView(degrees: dir, size: 8)
                        }
                        Text(WaveFormatter.periodString(swellPeriod))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                }

                // Secondary swell
                if let swell2H = condition.secondarySwellHeight,
                   let swell2P = condition.secondarySwellPeriod,
                   swell2H > 0.1 {
                    HStack(spacing: 5) {
                        Text("Swell 2")
                        Text(WaveFormatter.heightString(swell2H, useMetric: useMetric))
                        if let dir = condition.secondarySwellDirection {
                            DirectionIndicatorView(degrees: dir, size: 8)
                        }
                        Text(WaveFormatter.periodString(swell2P))
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                }

                // Last updated
                if let lastUpdated {
                    Text("Updated \(WaveFormatter.relativeTimeString(from: lastUpdated))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .opacity(mode == .compass ? 0 : 1)
            .allowsHitTesting(mode == .conditions)

            // Compass overlay
            if mode == .compass {
                compassOverlay
            }
        }
        .simultaneousGesture(
            TapGesture().onEnded { onTap() }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [
                    Color(red: 10/255, green: 22/255, blue: 40/255),
                    Color(
                        red: (10 + 30 * gradientIntensity) / 255,
                        green: (22 + 80 * gradientIntensity) / 255,
                        blue: (40 + 60 * gradientIntensity) / 255
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
        .onChange(of: heading) { _, newHeading in
            let target = -(newHeading ?? 0)
            var delta = target - smoothRotation
            // Normalize delta to [-180, 180] for shortest path
            delta = delta.truncatingRemainder(dividingBy: 360)
            if delta > 180 { delta -= 360 }
            if delta < -180 { delta += 360 }
            smoothRotation += delta
        }
    }

    private func coastDistanceString(_ km: Double) -> String {
        if useMetric {
            return km < 1 ? String(format: "%.0fm", km * 1000) : String(format: "%.0fkm", km)
        } else {
            let miles = km * 0.621371
            return String(format: "%.1fmi", miles)
        }
    }

    private var compassRotation: Double {
        smoothRotation
    }

    private var compassOverlay: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let ringRadius = size / 2 - 20
            // Scale factor relative to a reference watchOS ring of ~62pt
            let s = max(1.0, ringRadius / 62)
            let labelRadius = ringRadius + 12 * s

            ZStack {
                // Rotating compass ring + arrows
                ZStack {
                    // Ring
                    Circle()
                        .stroke(.white.opacity(0.2), lineWidth: 2 * s)
                        .frame(width: ringRadius * 2, height: ringRadius * 2)

                    // Cardinal labels — counter-rotated to stay upright
                    ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { idx, label in
                        let angle = Double(idx) * 90.0
                        let rad = (angle - 90) * .pi / 180
                        Text(label)
                            .font(.system(size: 10 * s, weight: .bold))
                            .foregroundStyle(label == "N" ? .white : .white.opacity(0.5))
                            .rotationEffect(.degrees(-compassRotation))
                            .offset(
                                x: cos(rad) * labelRadius,
                                y: sin(rad) * labelRadius
                            )
                    }

                    // Wave indicator (cyan) — curling wave
                    WaveCurlIndicator()
                        .fill(.cyan)
                        .frame(width: 20 * s, height: 16 * s)
                        .rotationEffect(.degrees(-compassRotation - condition.waveDirection))
                        .offset(y: -ringRadius)
                        .rotationEffect(.degrees(condition.waveDirection))

                    // Wind indicator (white) — streaks
                    if let windDir = condition.windDirection {
                        let absNudge: Double = {
                            let diff = (windDir - condition.waveDirection)
                                .truncatingRemainder(dividingBy: 360)
                            let normalized = diff < -180 ? diff + 360 : (diff > 180 ? diff - 360 : diff)
                            if abs(normalized) < 10 { return normalized >= 0 ? 10 : -10 }
                            return 0
                        }()
                        let windAngle = windDir + absNudge
                        WindStreakIndicator()
                            .fill(.white.opacity(0.8))
                            .frame(width: 18 * s, height: 16 * s)
                            .rotationEffect(.degrees(-compassRotation - windAngle))
                            .offset(y: -ringRadius)
                            .rotationEffect(.degrees(windAngle))
                    }
                    // Shore marker (sandy gold) — on compass ring
                    if let bearing = coastBearing {
                        ShoreIndicator()
                            .fill(.orange.opacity(0.9))
                            .frame(width: 14 * s, height: 12 * s)
                            .rotationEffect(.degrees(-compassRotation - bearing))
                            .offset(y: -ringRadius)
                            .rotationEffect(.degrees(bearing))
                    }
                }
                .rotationEffect(.degrees(compassRotation))
                .animation(.easeOut(duration: 0.3), value: compassRotation)

                // Top: beach name (fixed)
                VStack {
                    if let name = beachName {
                        HStack(spacing: 3) {
                            Text(name)
                            if let dist = coastDistanceKm {
                                Text(coastDistanceString(dist))
                            }
                        }
                        .font(.system(size: 9 * s, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.7))
                    } else if let coast = coastDirection {
                        Text("\(coast.label) Coast")
                            .font(.system(size: 9 * s, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                }
                .padding(.top, 4 * s)

                // Center info (fixed, non-rotating)
                VStack(spacing: 2 * s) {
                    if let windSpeed = condition.windSpeed {
                        HStack(spacing: 2) {
                            Image(systemName: "wind")
                                .font(.system(size: 7 * s))
                            Text(WaveFormatter.windString(windSpeed, useMetric: useMetric))
                        }
                        .font(.system(size: 9 * s, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    }

                    Text(WaveFormatter.heightString(condition.waveHeight, useMetric: useMetric))
                        .font(.system(size: 22 * s, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(WaveFormatter.periodString(condition.wavePeriod))
                        .font(.system(size: 11 * s, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))

                    if let sst = condition.seaSurfaceTemperature {
                        Text(WaveFormatter.temperatureString(sst, useMetric: useMetric))
                            .font(.system(size: 9 * s, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Bottom legend (fixed)
                VStack {
                    Spacer()
                    HStack(spacing: 8 * s) {
                        HStack(spacing: 3) {
                            WaveCurlIndicator()
                                .fill(.cyan)
                                .frame(width: 8 * s, height: 6 * s)
                            Text("wave")
                        }
                        HStack(spacing: 3) {
                            WindStreakIndicator()
                                .fill(.white.opacity(0.8))
                                .frame(width: 7 * s, height: 6 * s)
                            Text("wind")
                        }
                        if coastBearing != nil {
                            HStack(spacing: 3) {
                                ShoreIndicator()
                                    .fill(.orange.opacity(0.9))
                                    .frame(width: 7 * s, height: 6 * s)
                                Text("shore")
                            }
                        }
                    }
                    .font(.system(size: 8 * s))
                    .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.bottom, 4 * s)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// Droplet / water drop pointing in travel direction
struct WaveCurlIndicator: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Sharp tip at top (direction of travel)
        path.move(to: CGPoint(x: w * 0.5, y: 0))

        // Right curve — flares out to a rounded base
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: h),
            control1: CGPoint(x: w * 1.1, y: h * 0.35),
            control2: CGPoint(x: w * 0.85, y: h * 0.85)
        )

        // Left curve — mirror back to tip
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: w * 0.15, y: h * 0.85),
            control2: CGPoint(x: w * -0.1, y: h * 0.35)
        )

        path.closeSubpath()
        return path
    }
}

/// Wind streaks — three angled lines with a pointed tip
struct WindStreakIndicator: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let t: CGFloat = w * 0.06 // streak thickness

        // Main center streak — pointed arrow tip at top, tapers from body
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addLine(to: CGPoint(x: w * 0.5 + t, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.5 + t, y: h))
        path.addLine(to: CGPoint(x: w * 0.5 - t, y: h))
        path.addLine(to: CGPoint(x: w * 0.5 - t, y: h * 0.2))
        path.closeSubpath()

        // Left streak — shorter, offset
        path.move(to: CGPoint(x: w * 0.25, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.25 + t, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.25 + t, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.25 - t, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.25 - t, y: h * 0.3))
        path.closeSubpath()

        // Right streak — shorter, offset
        path.move(to: CGPoint(x: w * 0.75, y: h * 0.2))
        path.addLine(to: CGPoint(x: w * 0.75 + t, y: h * 0.3))
        path.addLine(to: CGPoint(x: w * 0.75 + t, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.75 - t, y: h * 0.85))
        path.addLine(to: CGPoint(x: w * 0.75 - t, y: h * 0.3))
        path.closeSubpath()

        return path
    }
}

/// Shore/beach marker — a small flag shape
struct ShoreIndicator: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Pole
        let poleX = w * 0.35
        let poleW = w * 0.08
        path.addRect(CGRect(x: poleX - poleW / 2, y: 0, width: poleW, height: h))

        // Flag — triangular pennant to the right
        path.move(to: CGPoint(x: poleX, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.2))
        path.addLine(to: CGPoint(x: poleX, y: h * 0.4))
        path.closeSubpath()

        return path
    }
}

#Preview {
    CurrentConditionsView(
        mode: .compass,
        condition: .placeholder,
        useMetric: true,
        coastDirection: .west,
        heading: 0,
        lastUpdated: Date(timeIntervalSinceNow: -300),
        beachName: "Għajn Tuffieħa",
        coastBearing: 300,
        coastDistanceKm: 5
    )
}
