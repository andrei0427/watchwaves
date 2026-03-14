import Foundation
import CoreLocation

actor CoastDetectionService {
    private let apiClient: MarineAPIClient
    private let probeDistancesKm: [Double] = [0.5, 1, 2, 5, 10, 20, 40, 80]

    init(apiClient: MarineAPIClient = MarineAPIClient()) {
        self.apiClient = apiClient
    }

    /// Probe 8 compass directions to find ocean, then refine the nearest with a fine sweep.
    func detectCoasts(from location: CLLocationCoordinate2D) async -> CoastDetectionResult {
        // Phase 1: coarse sweep at 8 cardinal/intercardinal directions
        var results = await withTaskGroup(of: CoastProbeResult?.self, returning: [CoastProbeResult].self) { group in
            for direction in CompassDirection.allCases {
                group.addTask {
                    await self.probeDirection(direction, from: location)
                }
            }

            var detected: [CoastProbeResult] = []
            for await result in group {
                if let result {
                    detected.append(result)
                }
            }
            return detected
        }

        // Phase 2: fine sweep around the nearest hit to find the true closest shore
        if let nearest = results.min(by: { $0.bestDistanceKm < $1.bestDistanceKm }) {
            let centerBearing = nearest.direction.bearing
            // Probe at 10° intervals in a ±40° arc around the nearest direction
            let fineBearings = stride(from: centerBearing - 40, through: centerBearing + 40, by: 10)
                .map { ($0 + 360).truncatingRemainder(dividingBy: 360) }
                // Skip bearings that are already covered by the 8 main directions
                .filter { b in !CompassDirection.allCases.contains(where: { abs($0.bearing - b) < 5 }) }

            let fineResults = await withTaskGroup(of: CoastProbeResult?.self, returning: [CoastProbeResult].self) { group in
                for bearing in fineBearings {
                    let dir = CompassDirection.from(bearing: bearing)
                    group.addTask {
                        await self.probeAtBearing(bearing, direction: dir, from: location)
                    }
                }
                var detected: [CoastProbeResult] = []
                for await result in group {
                    if let result { detected.append(result) }
                }
                return detected
            }

            // Replace the nearest result if we found something closer
            if let fineNearest = fineResults.min(by: { $0.bestDistanceKm < $1.bestDistanceKm }),
               fineNearest.bestDistanceKm < nearest.bestDistanceKm {
                // Replace the coarse result for this direction
                results.removeAll(where: { $0.direction == nearest.direction })
                results.append(fineNearest)
            }
        }

        return CoastDetectionResult(
            probeOriginLatitude: location.latitude,
            probeOriginLongitude: location.longitude,
            detectedCoasts: results.sorted(by: { $0.distanceKm < $1.distanceKm }),
            timestamp: .now
        )
    }

    /// Probe a single compass direction at increasing distances.
    private func probeDirection(_ direction: CompassDirection, from origin: CLLocationCoordinate2D) async -> CoastProbeResult? {
        await probeAtBearing(direction.bearing, direction: direction, from: origin)
    }

    /// Probe at an arbitrary bearing at increasing distances. Returns first ocean hit, then refines to shoreline.
    private func probeAtBearing(_ bearing: Double, direction: CompassDirection, from origin: CLLocationCoordinate2D) async -> CoastProbeResult? {
        var lastLandKm: Double = 0

        for distance in probeDistancesKm {
            let point = GeoHelpers.destinationPoint(from: origin, bearing: bearing, distanceKm: distance)
            do {
                let isOcean = try await apiClient.probeIsOcean(at: point)
                if isOcean {
                    let (shoreKm, shorePoint) = await refineShore(
                        from: origin, bearing: bearing,
                        landKm: lastLandKm, oceanKm: distance
                    )

                    return CoastProbeResult(
                        direction: direction,
                        distanceKm: distance,
                        oceanLatitude: point.latitude,
                        oceanLongitude: point.longitude,
                        shoreDistanceKm: shoreKm,
                        shoreLatitude: shorePoint.latitude,
                        shoreLongitude: shorePoint.longitude
                    )
                }
                lastLandKm = distance
            } catch {
                continue
            }
        }
        return nil
    }

    /// Binary search between a known land point and a known ocean point to find the shoreline.
    private func refineShore(
        from origin: CLLocationCoordinate2D, bearing: Double,
        landKm: Double, oceanKm: Double, iterations: Int = 5
    ) async -> (Double, CLLocationCoordinate2D) {
        var lo = landKm
        var hi = oceanKm

        for _ in 0..<iterations {
            let mid = (lo + hi) / 2
            let point = GeoHelpers.destinationPoint(from: origin, bearing: bearing, distanceKm: mid)
            let isOcean = (try? await apiClient.probeIsOcean(at: point)) ?? false
            if isOcean {
                hi = mid
            } else {
                lo = mid
            }
        }

        // Return the ocean-side boundary (hi) — the water's edge
        let shorePoint = GeoHelpers.destinationPoint(from: origin, bearing: bearing, distanceKm: hi)
        return (hi, shorePoint)
    }
}
