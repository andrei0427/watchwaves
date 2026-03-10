import SwiftUI

struct ForecastView: View {
    let forecast: [WaveCondition]
    let useMetric: Bool
    var lastUpdated: Date?
    var onRefresh: (() async -> Void)?

    private var periodRange: String {
        let periods = forecast.map(\.wavePeriod)
        guard let lo = periods.min(), let hi = periods.max() else { return "--" }
        if lo == hi {
            return WaveFormatter.periodString(lo)
        }
        return "\(Int(lo))–\(Int(hi))s"
    }

    /// Group forecast by day, showing every hour for today, every 3 hours for future days
    private var groupedForecast: [(header: String, conditions: [WaveCondition])] {
        let calendar = Calendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)

        var groups: [(String, [WaveCondition])] = []
        var currentDay: Date?
        var currentConditions: [WaveCondition] = []
        var currentHeader = ""

        for condition in forecast {
            guard condition.time >= now.addingTimeInterval(-3600) else { continue }

            let day = calendar.startOfDay(for: condition.time)
            if day != currentDay {
                if !currentConditions.isEmpty {
                    groups.append((currentHeader, currentConditions))
                }
                currentDay = day
                currentConditions = []
                currentHeader = dayHeader(for: day, today: today, calendar: calendar)
            }

            // Today: every hour. Future days: every 3 hours
            if day == today {
                currentConditions.append(condition)
            } else {
                let hour = calendar.component(.hour, from: condition.time)
                if hour % 3 == 0 {
                    currentConditions.append(condition)
                }
            }
        }

        if !currentConditions.isEmpty {
            groups.append((currentHeader, currentConditions))
        }

        return groups
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(groupedForecast.enumerated()), id: \.element.header) { index, group in
                    if index == 0 {
                        // Column headers only for first group
                        HStack(spacing: 0) {
                            Text("")
                                .frame(width: 24)
                            HStack(spacing: 2) {
                                Image(systemName: "wind")
                                Text("Wind")
                            }
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                            HStack(spacing: 2) {
                                Image(systemName: "water.waves")
                                Text("Wave")
                            }
                            .foregroundStyle(.cyan)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "thermometer.medium")
                                .foregroundStyle(.orange.opacity(0.7))
                                .frame(width: 28, alignment: .trailing)
                        }
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.bottom, 3)
                    } else {
                        // Day header for subsequent groups
                        HStack {
                            Text(group.header)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .padding(.bottom, 3)
                    }

                    ForEach(group.conditions) { condition in
                        forecastRow(condition)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)

                        Divider()
                            .overlay(.white.opacity(0.08))
                    }
                }

                // Period footer
                Text("Period: \(periodRange)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 6)

                // Last updated
                if let lastUpdated {
                    Text("Updated \(WaveFormatter.relativeTimeString(from: lastUpdated))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.top, 2)
                }

                // Refresh button
                if let onRefresh {
                    Button {
                        Task { await onRefresh() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                    }
                    .font(.system(size: 12))
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan.opacity(0.3))
                    .padding(.top, 10)
                }
            }
        }
        .navigationTitle("Forecast")
    }

    private func forecastRow(_ condition: WaveCondition) -> some View {
        HStack(spacing: 0) {
            // Hour
            Text(hourString(condition.time))
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .leading)

            // Wind: speed + direction
            if let windSpeed = condition.windSpeed,
               let windDir = condition.windDirection {
                HStack(spacing: 3) {
                    Text(shortWindString(windSpeed))
                        .foregroundStyle(.white.opacity(0.8))
                    DirectionIndicatorView(degrees: windDir, size: 8)
                    if let label = condition.windDirectionLabel {
                        Text(label)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("--")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Wave: height + direction
            HStack(spacing: 3) {
                Text(WaveFormatter.heightString(condition.waveHeight, useMetric: useMetric))
                    .foregroundStyle(.cyan)
                    .fontWeight(.semibold)
                DirectionIndicatorView(degrees: condition.waveDirection, size: 8)
                Text(condition.directionLabel)
                    .foregroundStyle(.cyan.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Temperature
            if let sst = condition.seaSurfaceTemperature {
                Text(String(format: "%.0f°", sst))
                    .foregroundStyle(.orange.opacity(0.7))
                    .frame(width: 28, alignment: .trailing)
            } else {
                Text("--")
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }
        }
        .font(.system(size: 11))
    }

    private func dayHeader(for day: Date, today: Date, calendar: Calendar) -> String {
        if calendar.isDate(day, inSameDayAs: today) {
            return "Today"
        } else if calendar.isDate(day, inSameDayAs: today.addingTimeInterval(86400)) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE d MMM"
            return formatter.string(from: day)
        }
    }

    private func hourString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH"
        return formatter.string(from: date)
    }

    private func shortWindString(_ kmh: Double) -> String {
        if useMetric {
            return "\(Int(kmh))k"
        } else {
            let mph = kmh * 0.621371
            return "\(Int(mph))m"
        }
    }
}

#Preview {
    let conditions = (0..<120).map { i in
        WaveCondition(
            time: Date(timeIntervalSinceNow: TimeInterval(i * 3600)),
            waveHeight: 1.0 + Double(i % 5) * 0.3,
            waveDirection: Double(180 + i * 10),
            wavePeriod: 7 + Double(i % 4),
            swellHeight: nil,
            swellDirection: nil,
            swellPeriod: nil,
            secondarySwellHeight: nil,
            secondarySwellDirection: nil,
            secondarySwellPeriod: nil,
            windSpeed: 10 + Double(i % 6) * 3,
            windDirection: Double(90 + i * 15),
            seaSurfaceTemperature: 18.5 + Double(i % 3) * 0.5
        )
    }
    ForecastView(forecast: conditions, useMetric: true)
}
