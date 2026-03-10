import Foundation

struct WaveCondition: Codable, Identifiable {
    var id: Date { time }

    let time: Date
    let waveHeight: Double
    let waveDirection: Double
    let wavePeriod: Double
    let swellHeight: Double?
    let swellDirection: Double?
    let swellPeriod: Double?
    let secondarySwellHeight: Double?
    let secondarySwellDirection: Double?
    let secondarySwellPeriod: Double?
    let windSpeed: Double?
    let windDirection: Double?
    let seaSurfaceTemperature: Double?

    var directionLabel: String {
        CompassDirection.from(bearing: waveDirection).rawValue
    }

    var inlineSummary: String {
        WaveFormatter.inlineSummary(height: waveHeight, direction: waveDirection, period: wavePeriod)
    }

    var windDirectionLabel: String? {
        guard let dir = windDirection else { return nil }
        return CompassDirection.from(bearing: dir).rawValue
    }

    static let placeholder = WaveCondition(
        time: .now,
        waveHeight: 1.5,
        waveDirection: 270,
        wavePeriod: 8,
        swellHeight: 1.2,
        swellDirection: 280,
        swellPeriod: 10,
        secondarySwellHeight: 0.4,
        secondarySwellDirection: 190,
        secondarySwellPeriod: 6,
        windSpeed: 15,
        windDirection: 200,
        seaSurfaceTemperature: 19.5
    )
}
