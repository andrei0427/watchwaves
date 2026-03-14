import Foundation
import CoreLocation

@MainActor
@Observable
final class WaveViewModel {
    var currentCondition: WaveCondition?
    var forecast: [WaveCondition] = []
    var coastDetection: CoastDetectionResult?
    var selectedCoast: CoastProbeResult?
    var isLoading = false
    var errorMessage: String?
    var nearestBeachName: String?
    var coastBearing: Double?
    var coastDistanceKm: Double?

    let locationService = LocationService()
    private let coastService = CoastDetectionService()
    private let apiClient = MarineAPIClient()
    private let store = DataStore.shared
    private let geocoder = CLGeocoder()
    private var isLoadingInProgress = false

    private let reprobeThresholdKm: Double = 2.0

    var preferences: UserPreferences {
        get { store.preferences }
        set {
            store.preferences = newValue
            if let detection = coastDetection {
                updateSelectedCoast(from: detection)
            }
        }
    }

    func loadData() async {
        guard !isLoadingInProgress else { return }
        isLoadingInProgress = true
        isLoading = true
        errorMessage = nil

        do {
            let location = try await locationService.requestLocation()

            if shouldReprobe(from: location.coordinate) {
                let detection = await coastService.detectCoasts(from: location.coordinate)
                coastDetection = detection
                store.coastDetection = detection
                updateSelectedCoast(from: detection)
            } else if let cached = store.coastDetection {
                coastDetection = cached
                updateSelectedCoast(from: cached)
            }

            if let coast = selectedCoast {
                coastDistanceKm = coast.bestDistanceKm
                coastBearing = GeoHelpers.bearing(from: location.coordinate, to: coast.bestCoordinate)
                await resolveBeachName(for: coast, from: location.coordinate)

                let conditions = try await apiClient.fetchMarineData(at: coast.oceanCoordinate, windAt: location.coordinate)
                forecast = conditions
                currentCondition = conditions.first
                store.waveConditions = conditions
            } else {
                errorMessage = "No coast detected nearby"
            }
        } catch {
            errorMessage = error.localizedDescription
            if let cached = store.waveConditions {
                forecast = cached
                currentCondition = cached.first
            }
        }

        isLoading = false
        isLoadingInProgress = false
        BackgroundRefreshManager.shared.scheduleNextRefresh()
    }

    private nonisolated func shouldReprobe(from coordinate: CLLocationCoordinate2D) -> Bool {
        guard let cached = store.coastDetection else { return true }
        let distance = GeoHelpers.distanceKm(from: cached.probeOrigin, to: coordinate)
        return distance > reprobeThresholdKm
    }

    private func updateSelectedCoast(from detection: CoastDetectionResult) {
        if let manual = preferences.manualCoastDirection {
            selectedCoast = detection.detectedCoasts.first(where: { $0.direction == manual })
        } else {
            selectedCoast = detection.nearestCoast
        }
    }

    private func resolveBeachName(for coast: CoastProbeResult, from origin: CLLocationCoordinate2D) async {
        let shoreCoord = coast.bestCoordinate

        // Perimeter walk — advance 500m along the shoreline in both directions,
        // probing for a named locality. Alternate CW/CCW so the closer name wins.
        let oceanBearing = GeoHelpers.bearing(from: origin, to: shoreCoord)
        var cwPos = shoreCoord
        var ccwPos = shoreCoord
        var cwTangent = (oceanBearing + 90).truncatingRemainder(dividingBy: 360)
        var ccwTangent = (oceanBearing - 90 + 360).truncatingRemainder(dividingBy: 360)

        for _ in 0..<6 {
            if let name = await perimeterStep(position: &cwPos, tangentBearing: &cwTangent, isClockwise: true) {
                nearestBeachName = name
                return
            }
            if let name = await perimeterStep(position: &ccwPos, tangentBearing: &ccwTangent, isClockwise: false) {
                nearestBeachName = name
                return
            }
        }

        // Phase 2: Fallback to cardinal direction label
        nearestBeachName = coast.direction.label + " Coast"
    }

    // Advance one 500m step along the coast, correct back to shore, and geocode 100m inland.
    // Updates position and tangentBearing in-place to follow coastline curvature.
    // Returns a land name if found, nil otherwise.
    private func perimeterStep(
        position: inout CLLocationCoordinate2D,
        tangentBearing: inout Double,
        isClockwise: Bool
    ) async -> String? {
        let candidate = GeoHelpers.destinationPoint(from: position, bearing: tangentBearing, distanceKm: 0.5)

        // For a CW walker the ocean is to the left  (tangent − 90).
        // For a CCW walker the ocean is to the right (tangent + 90).
        let seawardBearing = isClockwise
            ? (tangentBearing - 90 + 360).truncatingRemainder(dividingBy: 360)
            : (tangentBearing + 90).truncatingRemainder(dividingBy: 360)
        let inlandBearing = (seawardBearing + 180).truncatingRemainder(dividingBy: 360)

        // Single probe: correct toward shore by 200m
        let isOcean = (try? await apiClient.probeIsOcean(at: candidate)) ?? false
        let corrected = GeoHelpers.destinationPoint(
            from: candidate,
            bearing: isOcean ? inlandBearing : seawardBearing,
            distanceKm: 0.2
        )

        // Update tangent so subsequent steps follow the coastline curve
        tangentBearing = GeoHelpers.bearing(from: position, to: corrected)
        position = corrected

        // Geocode 50m inland from the corrected shore point
        let geocodePoint = GeoHelpers.destinationPoint(from: corrected, bearing: inlandBearing, distanceKm: 0.05)
        return await geocodeLandName(at: geocodePoint)
    }

    private func geocodeLandName(at coordinate: CLLocationCoordinate2D) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let place = placemarks.first else { return nil }
            // Named areas of interest (beaches, parks, harbours) take priority
            if let aoi = place.areasOfInterest?.first(where: { isCoastalName($0) }) {
                return aoi
            }
            // Accept the POI name only if it sounds coastal
            if let name = place.name, isCoastalName(name) {
                return name
            }
        } catch {
            // Treat geocoding failure as no result
        }
        return nil
    }

    private func isCoastalName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let keywords = ["beach", "bay", "cove", "harbour", "harbor", "port", "marina",
                        "quay", "wharf", "jetty", "pier", "promenade", "waterfront",
                        "coast", "shore", "lido", "strand", "creek", "inlet", "haven", "dock"]
        return keywords.contains(where: { lower.contains($0) })
    }
}
