import Foundation
import CoreLocation

struct CoastProbeResult: Codable {
    let direction: CompassDirection
    let distanceKm: Double
    let oceanLatitude: Double
    let oceanLongitude: Double
    var shoreDistanceKm: Double? = nil
    var shoreLatitude: Double? = nil
    var shoreLongitude: Double? = nil

    var oceanCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: oceanLatitude, longitude: oceanLongitude)
    }

    var shoreCoordinate: CLLocationCoordinate2D? {
        guard let lat = shoreLatitude, let lon = shoreLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// Best coordinate for display — shore if refined, otherwise ocean
    var bestCoordinate: CLLocationCoordinate2D {
        shoreCoordinate ?? oceanCoordinate
    }

    /// Best distance — shore if refined, otherwise ocean probe distance
    var bestDistanceKm: Double {
        shoreDistanceKm ?? distanceKm
    }
}

struct CoastDetectionResult: Codable {
    let probeOriginLatitude: Double
    let probeOriginLongitude: Double
    let detectedCoasts: [CoastProbeResult]
    let timestamp: Date

    var probeOrigin: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: probeOriginLatitude, longitude: probeOriginLongitude)
    }

    /// The nearest coast (shortest refined shore distance)
    var nearestCoast: CoastProbeResult? {
        detectedCoasts.min(by: { $0.bestDistanceKm < $1.bestDistanceKm })
    }
}
