import Foundation

enum WaveFormatter {
    static func heightString(_ meters: Double, useMetric: Bool = true) -> String {
        if useMetric {
            return String(format: "%.1fm", meters)
        } else {
            let feet = meters * 3.28084
            return String(format: "%.0fft", feet)
        }
    }

    static func periodString(_ seconds: Double) -> String {
        String(format: "%.0fs", seconds)
    }

    static func directionString(_ degrees: Double) -> String {
        CompassDirection.from(bearing: degrees).rawValue
    }

    static func windString(_ kmh: Double, useMetric: Bool = true) -> String {
        if useMetric {
            return String(format: "%.0f km/h", kmh)
        } else {
            let mph = kmh * 0.621371
            return String(format: "%.0f mph", mph)
        }
    }

    static func relativeTimeString(from date: Date) -> String {
        let seconds = Int(-date.timeIntervalSinceNow)
        if seconds < 60 { return "just now" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        return "\(days)d ago"
    }

    static func temperatureString(_ celsius: Double, useMetric: Bool = true) -> String {
        if useMetric {
            return String(format: "%.0f°C", celsius)
        } else {
            let fahrenheit = celsius * 9.0 / 5.0 + 32
            return String(format: "%.0f°F", fahrenheit)
        }
    }

    static func inlineSummary(height: Double, direction: Double, period: Double, useMetric: Bool = true) -> String {
        "\(heightString(height, useMetric: useMetric)) \(directionString(direction)) \(periodString(period))"
    }
}
