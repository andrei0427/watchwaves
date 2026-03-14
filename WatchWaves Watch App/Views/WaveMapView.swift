import SwiftUI
import MapKit

struct WaveMapView: View {
    let detection: CoastDetectionResult
    let condition: WaveCondition?
    let selectedCoast: CoastProbeResult?

    private let coastByDirection: [CompassDirection: CoastProbeResult]
    private let maxRadiusKm: Double
    #if os(iOS)
    private let waveParticleCount = 320
    private let windParticleCount = 200
    #else
    private let waveParticleCount = 120
    private let windParticleCount = 80
    #endif
    @State private var selectedPin: WebcamPin?

    init(detection: CoastDetectionResult, condition: WaveCondition?, selectedCoast: CoastProbeResult?) {
        self.detection = detection
        self.condition = condition
        self.selectedCoast = selectedCoast

        var lookup: [CompassDirection: CoastProbeResult] = [:]
        for c in detection.detectedCoasts { lookup[c.direction] = c }
        self.coastByDirection = lookup

        let maxCoast = detection.detectedCoasts.map(\.distanceKm).max() ?? 10
        self.maxRadiusKm = max(maxCoast * 1.4, 8)
    }

    private var mapRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: detection.probeOrigin,
            latitudinalMeters: maxRadiusKm * 1000 * 2,
            longitudinalMeters: maxRadiusKm * 1000 * 2
        )
    }

    var body: some View {
        ZStack {
            // Satellite map with webcam pins — camera locked to Malta + Gozo + buffer
            Map(
                initialPosition: .region(mapRegion),
                bounds: MapCameraBounds(
                    centerCoordinateBounds: MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 35.95, longitude: 14.35),
                        span: MKCoordinateSpan(latitudeDelta: 0.7, longitudeDelta: 0.9)
                    ),
                    minimumDistance: 500,
                    maximumDistance: 130_000
                ),
                interactionModes: [.pan, .zoom]
            ) {
                ForEach(WebcamPin.all) { pin in
                    Annotation("", coordinate: pin.coordinate, anchor: .bottom) {
                        WebcamPinMarker(pin: pin) { selectedPin = pin }
                    }
                }
                Annotation("", coordinate: detection.probeOrigin, anchor: .center) {
                    UserLocationPin()
                }
                if let coast = selectedCoast {
                    Annotation("", coordinate: coast.bestCoordinate, anchor: .center) {
                        ShorePointPin()
                    }
                }
            }
            .mapStyle(.imagery)

            // Dark overlay to mute map detail — lets particles pop
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Particle overlay — fills entire screen
            GeometryReader { geo in
                let radarRadius = min(geo.size.width, geo.size.height) / 2 - 12

                TimelineView(.animation) { timeline in
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        // Pixels per km for ocean check at full canvas scale
                        let pxPerKm = min(canvasSize.width, canvasSize.height) / 2 / maxRadiusKm

                        // Range rings
                        drawRangeRings(context: context, center: center, radarRadius: radarRadius)

                        // Wave particles (ocean only — excluded from land)
                        if let condition {
                            drawWaveParticles(
                                context: context, center: center,
                                canvasSize: canvasSize, time: time,
                                condition: condition, pxPerKm: pxPerKm
                            )
                        }

                        // Wind particles (land + sea — no land mask)
                        if let condition {
                            drawWindParticles(
                                context: context, center: center,
                                canvasSize: canvasSize, time: time,
                                condition: condition
                            )
                        }

                        // Compass labels
                        drawCompassLabels(context: context, center: center, radarRadius: radarRadius)
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Bottom info bar
            if let condition {
                VStack {
                    Spacer()
                    bottomBar(condition: condition)
                }
            }
        }
        .sheet(item: $selectedPin) { pin in
            WebcamPinSheet(pin: pin)
        }
    }

    // MARK: - Bottom Info Bar

    private func bottomBar(condition: WaveCondition) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                    .font(.system(size: 9))
                    .foregroundStyle(.cyan)
                Text(WaveFormatter.heightString(condition.waveHeight, useMetric: true))
                    .foregroundStyle(.cyan)
            }
            if let windSpeed = condition.windSpeed {
                HStack(spacing: 4) {
                    Image(systemName: "wind")
                        .font(.system(size: 9))
                    Text(WaveFormatter.windString(windSpeed, useMetric: true))
                }
                .foregroundStyle(.white.opacity(0.85))
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(.black.opacity(0.6), in: .capsule)
        .padding(.bottom, 4)
    }

    // MARK: - Ocean Check (for wave particle exclusion)

    /// Returns true if a pixel-space point is beyond the coast boundary (i.e. in the ocean)
    private func isOcean(point: CGPoint, center: CGPoint, pxPerKm: Double) -> Bool {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let pxDist = hypot(dx, dy)
        let kmDist = pxDist / pxPerKm

        // Compute bearing: atan2 gives angle from +x axis, convert to compass bearing (0=N, clockwise)
        let angleRad = atan2(dy, dx) // radians from +x axis
        let bearing = (angleRad * 180 / .pi + 90)
            .truncatingRemainder(dividingBy: 360)
        let normalizedBearing = bearing < 0 ? bearing + 360 : bearing

        let coastDist = interpolatedCoastDistance(bearing: normalizedBearing)
        return kmDist > coastDist
    }

    // MARK: - Land Path (for range ring visual)

    private func buildLandPath(center: CGPoint, radarRadius: Double) -> Path {
        let steps = 64
        var points: [CGPoint] = []
        for i in 0..<steps {
            let bearing = Double(i) / Double(steps) * 360
            let dist = interpolatedCoastDistance(bearing: bearing)
            let r = (dist / maxRadiusKm) * radarRadius
            let rad = (bearing - 90) * .pi / 180
            points.append(CGPoint(
                x: center.x + cos(rad) * r,
                y: center.y + sin(rad) * r
            ))
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        path.closeSubpath()
        return path
    }

    private func interpolatedCoastDistance(bearing: Double) -> Double {
        let directions = CompassDirection.allCases
        let bearings = directions.map(\.bearing)

        let normalized = ((bearing.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)

        var lowerIdx = 0
        for i in 0..<bearings.count {
            if bearings[i] <= normalized { lowerIdx = i }
        }
        let upperIdx = (lowerIdx + 1) % bearings.count

        let lowerBearing = bearings[lowerIdx]
        var upperBearing = bearings[upperIdx]
        if upperBearing <= lowerBearing { upperBearing += 360 }

        var adjustedNorm = normalized
        if adjustedNorm < lowerBearing { adjustedNorm += 360 }

        let span = upperBearing - lowerBearing
        let t = span > 0 ? (adjustedNorm - lowerBearing) / span : 0

        let lowerDist = coastByDirection[directions[lowerIdx]]?.distanceKm ?? maxRadiusKm
        let upperDist = coastByDirection[directions[upperIdx]]?.distanceKm ?? maxRadiusKm

        return lowerDist + (upperDist - lowerDist) * t
    }

    // MARK: - Range Rings

    private func drawRangeRings(context: GraphicsContext, center: CGPoint, radarRadius: Double) {
        for km in [5.0, 10.0, 20.0] {
            guard km < maxRadiusKm else { continue }
            let r = (km / maxRadiusKm) * radarRadius
            let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(.white.opacity(0.1)),
                lineWidth: 0.5
            )
        }
    }

    // MARK: - Wave Particles (ocean only)

    private func drawWaveParticles(
        context: GraphicsContext, center: CGPoint,
        canvasSize: CGSize, time: Double,
        condition: WaveCondition, pxPerKm: Double
    ) {
        let height = min(condition.waveHeight, 5.0)
        let period = max(condition.wavePeriod, 3.0)
        let speed = 1.0 / period
        let baseOpacity = 0.4 + (height / 5.0) * 0.4
        let canvasRadius = hypot(canvasSize.width, canvasSize.height) / 2

        let dirRad = (condition.waveDirection + 180 - 90) * .pi / 180
        let perpRad = dirRad + .pi / 2
        let minDist: CGFloat = 16
        var placed: [CGPoint] = []

        for i in 0..<waveParticleCount {
            let seed = Double(i) * 137.508
            let phase = (seed / 360.0 + time * speed * 0.4)
                .truncatingRemainder(dividingBy: 1.0)
            let t = phase < 0 ? phase + 1 : phase

            let spreadFactor = (Double(i % 17) - 8) / 8.0
            let driftOffset = (Double(i % 7) - 3) / 3.0 * 5.0

            let travelDist = (t - 0.5) * canvasRadius * 2.6
            let spreadDist = spreadFactor * canvasRadius * 0.9

            let x = center.x + cos(dirRad) * travelDist + cos(perpRad) * (spreadDist + driftOffset)
            let y = center.y + sin(dirRad) * travelDist + sin(perpRad) * (spreadDist + driftOffset)

            // Clip to canvas bounds
            guard x > -10 && x < canvasSize.width + 10 &&
                  y > -10 && y < canvasSize.height + 10 else { continue }
            // Ocean only: check bearing/distance against coast boundary
            guard isOcean(point: CGPoint(x: x, y: y), center: center, pxPerKm: pxPerKm) else { continue }

            // Skip if too close to an already-placed particle
            let pt = CGPoint(x: x, y: y)
            if placed.contains(where: { hypot($0.x - pt.x, $0.y - pt.y) < minDist }) { continue }
            placed.append(pt)

            let distFromEdge = min(x, y, canvasSize.width - x, canvasSize.height - y)
            let edgeFade = min(distFromEdge / 20.0, 1.0)
            let particleOpacity = baseOpacity * edgeFade
            let scale = 4.0 + height * 1.0

            let dx = cos(dirRad) * scale
            let dy = sin(dirRad) * scale
            let nx = cos(perpRad) * scale * 0.4
            let ny = sin(perpRad) * scale * 0.4

            var wavePath = Path()
            wavePath.move(to: CGPoint(x: x - dx, y: y - dy))
            wavePath.addQuadCurve(
                to: CGPoint(x: x, y: y),
                control: CGPoint(x: x - dx * 0.5 + nx, y: y - dy * 0.5 + ny)
            )
            wavePath.addQuadCurve(
                to: CGPoint(x: x + dx, y: y + dy),
                control: CGPoint(x: x + dx * 0.5 - nx, y: y + dy * 0.5 - ny)
            )

            context.stroke(
                wavePath,
                with: .color(Color.cyan.opacity(particleOpacity)),
                lineWidth: 1.8
            )

            // Leading dot at front of particle
            let dotX = x + dx
            let dotY = y + dy
            let dotSize: CGFloat = 2.5
            let dotRect = CGRect(x: dotX - dotSize / 2, y: dotY - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(Color.cyan.opacity(particleOpacity * 1.2)))
        }
    }

    // MARK: - Wind Particles (land + sea)

    private func drawWindParticles(
        context: GraphicsContext, center: CGPoint,
        canvasSize: CGSize, time: Double,
        condition: WaveCondition
    ) {
        guard let windDir = condition.windDirection,
              let windSpeed = condition.windSpeed else { return }

        let normalizedSpeed = min(windSpeed / 50.0, 1.0)
        let baseOpacity = 0.2 + normalizedSpeed * 0.35
        let speed = 0.15 + normalizedSpeed * 0.25
        let canvasRadius = hypot(canvasSize.width, canvasSize.height) / 2

        let dirRad = (windDir + 180 - 90) * .pi / 180
        let perpRad = dirRad + .pi / 2
        let minDist: CGFloat = 14
        var placed: [CGPoint] = []

        for i in 0..<windParticleCount {
            let seed = Double(i) * 97.135 + 50
            let phase = (seed / 360.0 + time * speed)
                .truncatingRemainder(dividingBy: 1.0)
            let t = phase < 0 ? phase + 1 : phase

            let spreadFactor = (Double(i % 13) - 6) / 6.0
            let driftOffset = (Double(i % 5) - 2) / 2.0 * 4.0

            let travelDist = (t - 0.5) * canvasRadius * 2.6
            let spreadDist = spreadFactor * canvasRadius * 0.9

            let x = center.x + cos(dirRad) * travelDist + cos(perpRad) * (spreadDist + driftOffset)
            let y = center.y + sin(dirRad) * travelDist + sin(perpRad) * (spreadDist + driftOffset)

            guard x > -10 && x < canvasSize.width + 10 &&
                  y > -10 && y < canvasSize.height + 10 else { continue }

            // Skip if too close to an already-placed particle
            let pt = CGPoint(x: x, y: y)
            if placed.contains(where: { hypot($0.x - pt.x, $0.y - pt.y) < minDist }) { continue }
            placed.append(pt)

            let distFromEdge = min(x, y, canvasSize.width - x, canvasSize.height - y)
            let edgeFade = min(distFromEdge / 20.0, 1.0)
            let particleOpacity = baseOpacity * edgeFade

            let streakLength = 5.0 + normalizedSpeed * 6.0
            let dx = cos(dirRad) * streakLength
            let dy = sin(dirRad) * streakLength

            // Tail line (dimmer)
            var streak = Path()
            streak.move(to: CGPoint(x: x - dx, y: y - dy))
            streak.addLine(to: CGPoint(x: x + dx, y: y + dy))

            context.stroke(
                streak,
                with: .color(Color.white.opacity(particleOpacity * 0.7)),
                lineWidth: 1.2
            )

            // Leading dot at front
            let dotX = x + dx
            let dotY = y + dy
            let dotSize: CGFloat = 2.0
            let dotRect = CGRect(x: dotX - dotSize / 2, y: dotY - dotSize / 2, width: dotSize, height: dotSize)
            context.fill(Path(ellipseIn: dotRect), with: .color(Color.white.opacity(particleOpacity * 1.2)))
        }
    }

    // MARK: - Compass Labels

    private func drawCompassLabels(context: GraphicsContext, center: CGPoint, radarRadius: Double) {
        let labels: [(String, Angle)] = [
            ("N", .degrees(-90)),
            ("E", .degrees(0)),
            ("S", .degrees(90)),
            ("W", .degrees(180)),
        ]
        for (label, angle) in labels {
            // Push labels to near screen edges
            let edgePadding: CGFloat = 10
            let pt: CGPoint
            switch label {
            case "N": pt = CGPoint(x: center.x, y: edgePadding)
            case "S": pt = CGPoint(x: center.x, y: center.y * 2 - edgePadding - 18)
            case "E": pt = CGPoint(x: center.x * 2 - edgePadding - 4, y: center.y)
            case "W": pt = CGPoint(x: edgePadding + 4, y: center.y)
            default:
                let dist = radarRadius + 10
                pt = CGPoint(
                    x: center.x + cos(angle.radians) * dist,
                    y: center.y + sin(angle.radians) * dist
                )
            }
            // Shadow for contrast against both light and dark backgrounds
            let shadow = Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.black.opacity(0.6))
            context.draw(context.resolve(shadow), at: CGPoint(x: pt.x + 0.5, y: pt.y + 0.5))

            let text = Text(label)
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(.white)
            context.draw(context.resolve(text), at: pt)
        }
    }
}

// MARK: - Location annotation views

private struct UserLocationPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.25))
                .frame(width: 14, height: 14)
            Circle()
                .fill(.white)
                .frame(width: 7, height: 7)
        }
    }
}

private struct ShorePointPin: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.orange)
                .frame(width: 13, height: 2)
            Rectangle()
                .fill(.orange)
                .frame(width: 2, height: 13)
            Circle()
                .fill(.orange)
                .frame(width: 4, height: 4)
        }
        .shadow(color: .orange.opacity(0.9), radius: 4)
    }
}

// MARK: - Webcam pin marker (shown on the map)

private struct WebcamPinMarker: View {
    let pin: WebcamPin
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "video.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(5)
                    .background(.cyan, in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: .cyan.opacity(0.8), radius: 4)

                if pin.cameras.count > 1 {
                    Text("\(pin.cameras.count)")
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(.black)
                        .frame(width: 12, height: 12)
                        .background(.white, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sheet shown when a pin is tapped

private struct WebcamPinSheet: View {
    let pin: WebcamPin

    var body: some View {
        NavigationStack {
            if pin.cameras.count == 1, let entry = pin.cameras.first {
                WebcamSnapshotView(entry: entry)
            } else {
                List(pin.cameras) { entry in
                    NavigationLink(entry.name) {
                        WebcamSnapshotView(entry: entry)
                    }
                    .font(.system(size: 14, weight: .medium))
                }
                .navigationTitle(pin.cameras.first.map { _ in
                    pin.cameras[0].name.components(separatedBy: " ").first ?? "Cameras"
                } ?? "Cameras")
            }
        }
    }
}

#Preview {
    WaveMapView(
        detection: CoastDetectionResult(
            probeOriginLatitude: 35.9,
            probeOriginLongitude: 14.5,
            detectedCoasts: [
                CoastProbeResult(direction: .north, distanceKm: 5, oceanLatitude: 35.95, oceanLongitude: 14.5),
                CoastProbeResult(direction: .northEast, distanceKm: 5, oceanLatitude: 35.93, oceanLongitude: 14.55),
                CoastProbeResult(direction: .east, distanceKm: 5, oceanLatitude: 35.9, oceanLongitude: 14.55),
                CoastProbeResult(direction: .southEast, distanceKm: 5, oceanLatitude: 35.87, oceanLongitude: 14.55),
                CoastProbeResult(direction: .south, distanceKm: 5, oceanLatitude: 35.85, oceanLongitude: 14.5),
                CoastProbeResult(direction: .southWest, distanceKm: 5, oceanLatitude: 35.87, oceanLongitude: 14.45),
                CoastProbeResult(direction: .west, distanceKm: 10, oceanLatitude: 35.9, oceanLongitude: 14.4),
                CoastProbeResult(direction: .northWest, distanceKm: 5, oceanLatitude: 35.93, oceanLongitude: 14.45),
            ],
            timestamp: .now
        ),
        condition: .placeholder,
        selectedCoast: CoastProbeResult(direction: .northEast, distanceKm: 5, oceanLatitude: 35.93, oceanLongitude: 14.55)
    )
}
