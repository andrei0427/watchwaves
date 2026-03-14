import Foundation

/// Open-Meteo Marine API response
struct MarineAPIResponse: Codable {
    let latitude: Double
    let longitude: Double
    let hourly: MarineHourlyData?
}

struct MarineHourlyData: Codable {
    let time: [String]
    let waveHeight: [Double?]?
    let waveDirection: [Double?]?
    let wavePeriod: [Double?]?
    let swellWaveHeight: [Double?]?
    let swellWaveDirection: [Double?]?
    let swellWavePeriod: [Double?]?
    let secondarySwellWaveHeight: [Double?]?
    let secondarySwellWaveDirection: [Double?]?
    let secondarySwellWavePeriod: [Double?]?
    let seaSurfaceTemperature: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case waveHeight = "wave_height"
        case waveDirection = "wave_direction"
        case wavePeriod = "wave_period"
        case swellWaveHeight = "swell_wave_height"
        case swellWaveDirection = "swell_wave_direction"
        case swellWavePeriod = "swell_wave_period"
        case secondarySwellWaveHeight = "secondary_swell_wave_height"
        case secondarySwellWaveDirection = "secondary_swell_wave_direction"
        case secondarySwellWavePeriod = "secondary_swell_wave_period"
        case seaSurfaceTemperature = "sea_surface_temperature"
    }
}

/// Open-Meteo Elevation API response
struct ElevationAPIResponse: Codable {
    let elevation: [Double]?
}

/// Open-Meteo Weather/Forecast API response (for wind data)
struct WeatherAPIResponse: Codable {
    let latitude: Double
    let longitude: Double
    let hourly: WeatherHourlyData?
}

struct WeatherHourlyData: Codable {
    let time: [String]
    let windSpeed10m: [Double?]?
    let windDirection10m: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case windSpeed10m = "wind_speed_10m"
        case windDirection10m = "wind_direction_10m"
    }
}
