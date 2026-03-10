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
        let bearing = GeoHelpers.bearing(from: shoreCoord, to: origin)

        // Try the shore point first, then nudge inland at small increments
        let nudgesKm: [Double] = [0, 0.1, 0.3, 0.5, 1.0]

        for nudge in nudgesKm {
            let point = nudge == 0
                ? shoreCoord
                : GeoHelpers.destinationPoint(from: shoreCoord, bearing: bearing, distanceKm: nudge)
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            do {
                let placemarks = try await geocoder.reverseGeocodeLocation(location)
                if let place = placemarks.first {
                    // Pick the first usable land name, skipping ocean/water body names
                    let candidate = place.name ?? place.locality ?? place.subLocality ?? place.administrativeArea
                    if let name = candidate, !isWaterBodyName(name) {
                        nearestBeachName = name
                        return
                    }
                }
            } catch {
                continue
            }
        }
        // Fallback to generic coast name
        nearestBeachName = coast.direction.label + " Coast"
    }

    private func isWaterBodyName(_ name: String) -> Bool {
        let lower = name.lowercased()
        let waterKeywords = ["sea", "ocean", "strait", "gulf", "bay of", "channel", "sound of"]
        return waterKeywords.contains(where: { lower.contains($0) })
    }
}
