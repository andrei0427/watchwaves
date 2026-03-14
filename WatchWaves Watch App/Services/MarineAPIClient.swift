import Foundation
import CoreLocation
import os

private let logger = Logger(subsystem: "com.watchWaves", category: "API")

actor MarineAPIClient {
    private let session: URLSession
    private let marineBaseURL = "https://marine-api.open-meteo.com/v1/marine"
    private let weatherBaseURL = "https://api.open-meteo.com/v1/forecast"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch marine data from ocean coordinate, wind from user's location
    func fetchMarineData(at oceanCoordinate: CLLocationCoordinate2D, windAt userCoordinate: CLLocationCoordinate2D, hours: Int = 120) async throws -> [WaveCondition] {
        async let marineResponse = fetchMarine(at: oceanCoordinate, hours: hours)
        async let weatherResponse = fetchWind(at: userCoordinate, hours: hours)

        let marine = try await marineResponse
        let weather = try? await weatherResponse

        return parseConditions(from: marine, weather: weather)
    }

    /// Probe a coordinate — returns true if ocean (elevation ≤ 0m).
    /// Uses the Open-Meteo elevation API (~90m Copernicus DEM resolution),
    /// which correctly distinguishes open sea from land even inside enclosed
    /// harbours — unlike the marine wave model whose ~28km grid treats Grand
    /// Harbour as indistinguishable from open Mediterranean.
    func probeIsOcean(at coordinate: CLLocationCoordinate2D) async throws -> Bool {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.5f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.5f", coordinate.longitude)),
        ]

        let (data, _) = try await session.data(from: components.url!)
        let response = try JSONDecoder().decode(ElevationAPIResponse.self, from: data)
        guard let elevation = response.elevation?.first else { return false }
        return elevation <= 0
    }

    private func fetchMarine(at coordinate: CLLocationCoordinate2D, hours: Int) async throws -> MarineAPIResponse {
        var components = URLComponents(string: marineBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period,swell_wave_height,swell_wave_direction,swell_wave_period,secondary_swell_wave_height,secondary_swell_wave_direction,secondary_swell_wave_period,sea_surface_temperature"),
            URLQueryItem(name: "forecast_hours", value: "\(hours)"),
        ]

        logger.debug("Fetching marine data: \(components.url!.absoluteString)")
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode(MarineAPIResponse.self, from: data)
    }

    private func fetchWind(at coordinate: CLLocationCoordinate2D, hours: Int) async throws -> WeatherAPIResponse {
        var components = URLComponents(string: weatherBaseURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", coordinate.longitude)),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "forecast_hours", value: "\(hours)"),
            URLQueryItem(name: "models", value: "ecmwf_ifs025"),
        ]

        logger.debug("Fetching wind data: \(components.url!.absoluteString)")
        let (data, _) = try await session.data(from: components.url!)
        return try JSONDecoder().decode(WeatherAPIResponse.self, from: data)
    }

    private func parseConditions(from marine: MarineAPIResponse, weather: WeatherAPIResponse?) -> [WaveCondition] {
        guard let hourly = marine.hourly else {
            logger.error("No hourly data in response")
            return []
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(identifier: "GMT")

        // Build wind lookup by time string for efficient matching
        var windByTime: [String: (speed: Double?, direction: Double?)] = [:]
        if let windHourly = weather?.hourly {
            for i in windHourly.time.indices {
                let speed = windHourly.windSpeed10m?.indices.contains(i) == true ? windHourly.windSpeed10m?[i] : nil
                let dir = windHourly.windDirection10m?.indices.contains(i) == true ? windHourly.windDirection10m?[i] : nil
                windByTime[windHourly.time[i]] = (speed, dir)
            }
        }

        var conditions: [WaveCondition] = []

        for i in hourly.time.indices {
            guard let date = formatter.date(from: hourly.time[i]) else {
                logger.debug("Failed to parse date: \(hourly.time[i])")
                continue
            }

            let height = hourly.waveHeight?.indices.contains(i) == true ? hourly.waveHeight?[i] : nil
            let direction = hourly.waveDirection?.indices.contains(i) == true ? hourly.waveDirection?[i] : nil
            let period = hourly.wavePeriod?.indices.contains(i) == true ? hourly.wavePeriod?[i] : nil

            guard let h = height as? Double,
                  let d = direction as? Double,
                  let p = period as? Double else {
                continue
            }

            let swellH = hourly.swellWaveHeight?.indices.contains(i) == true ? hourly.swellWaveHeight?[i] : nil
            let swellD = hourly.swellWaveDirection?.indices.contains(i) == true ? hourly.swellWaveDirection?[i] : nil
            let swellP = hourly.swellWavePeriod?.indices.contains(i) == true ? hourly.swellWavePeriod?[i] : nil
            let swell2H = hourly.secondarySwellWaveHeight?.indices.contains(i) == true ? hourly.secondarySwellWaveHeight?[i] : nil
            let swell2D = hourly.secondarySwellWaveDirection?.indices.contains(i) == true ? hourly.secondarySwellWaveDirection?[i] : nil
            let swell2P = hourly.secondarySwellWavePeriod?.indices.contains(i) == true ? hourly.secondarySwellWavePeriod?[i] : nil
            let sst = hourly.seaSurfaceTemperature?.indices.contains(i) == true ? hourly.seaSurfaceTemperature?[i] : nil

            let wind = windByTime[hourly.time[i]]

            conditions.append(WaveCondition(
                time: date,
                waveHeight: h,
                waveDirection: d,
                wavePeriod: p,
                swellHeight: swellH as? Double,
                swellDirection: swellD as? Double,
                swellPeriod: swellP as? Double,
                secondarySwellHeight: swell2H as? Double,
                secondarySwellDirection: swell2D as? Double,
                secondarySwellPeriod: swell2P as? Double,
                windSpeed: wind?.speed as? Double,
                windDirection: wind?.direction as? Double,
                seaSurfaceTemperature: sst as? Double
            ))
        }

        if conditions.isEmpty {
            logger.error("No valid conditions parsed. Times: \(hourly.time.prefix(3)), Heights: \(String(describing: hourly.waveHeight?.prefix(3)))")
        }

        logger.debug("Parsed \(conditions.count) conditions from response")
        return conditions
    }
}
