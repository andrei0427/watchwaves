import WidgetKit

struct WaveTimelineEntry: TimelineEntry {
    let date: Date
    let waveHeight: Double?
    let waveDirection: Double?
    let wavePeriod: Double?
    let windSpeed: Double?
    let windDirection: Double?
    let seaSurfaceTemperature: Double?
    let useMetric: Bool

    var directionLabel: String? {
        guard let dir = waveDirection else { return nil }
        return CompassDirection.from(bearing: dir).rawValue
    }

    var windDirectionLabel: String? {
        guard let dir = windDirection else { return nil }
        return CompassDirection.from(bearing: dir).rawValue
    }

    var heightString: String {
        guard let h = waveHeight else { return "--" }
        return WaveFormatter.heightString(h, useMetric: useMetric)
    }

    var compactHeightString: String {
        guard let h = waveHeight else { return "--" }
        return WaveFormatter.heightString(h, useMetric: useMetric)
    }

    var periodString: String {
        guard let p = wavePeriod else { return "--" }
        return WaveFormatter.periodString(p)
    }

    var inlineString: String {
        guard let h = waveHeight, let d = waveDirection, let p = wavePeriod else {
            return "No data"
        }
        return WaveFormatter.inlineSummary(height: h, direction: d, period: p, useMetric: useMetric)
    }

    var compactWindString: String? {
        guard let w = windSpeed else { return nil }
        if useMetric {
            return "\(Int(w))k"
        } else {
            return "\(Int(w * 0.621371))m"
        }
    }

    static let placeholder = WaveTimelineEntry(
        date: .now,
        waveHeight: 1.5,
        waveDirection: 270,
        wavePeriod: 8,
        windSpeed: 15,
        windDirection: 200,
        seaSurfaceTemperature: 19.5,
        useMetric: true
    )

    static let empty = WaveTimelineEntry(
        date: .now,
        waveHeight: nil,
        waveDirection: nil,
        wavePeriod: nil,
        windSpeed: nil,
        windDirection: nil,
        seaSurfaceTemperature: nil,
        useMetric: true
    )
}
