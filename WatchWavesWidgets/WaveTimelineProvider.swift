import WidgetKit

struct WaveTimelineProvider: TimelineProvider {
    private let store = DataStore.shared

    func placeholder(in context: Context) -> WaveTimelineEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (WaveTimelineEntry) -> Void) {
        completion(currentEntry() ?? .placeholder)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaveTimelineEntry>) -> Void) {
        let prefs = store.preferences
        guard let conditions = store.waveConditions, !conditions.isEmpty else {
            let timeline = Timeline(entries: [WaveTimelineEntry.empty], policy: .after(Date(timeIntervalSinceNow: 900)))
            completion(timeline)
            return
        }

        let now = Date()
        var entries: [WaveTimelineEntry] = []

        for condition in conditions {
            // Only include future or current entries
            guard condition.time >= now.addingTimeInterval(-3600) else { continue }

            entries.append(WaveTimelineEntry(
                date: condition.time,
                waveHeight: condition.waveHeight,
                waveDirection: condition.waveDirection,
                wavePeriod: condition.wavePeriod,
                windSpeed: condition.windSpeed,
                windDirection: condition.windDirection,
                seaSurfaceTemperature: condition.seaSurfaceTemperature,
                useMetric: prefs.useMetricUnits
            ))
        }

        if entries.isEmpty {
            entries.append(.empty)
        }

        let timeline = Timeline(entries: entries, policy: .after(Date(timeIntervalSinceNow: 1800)))
        completion(timeline)
    }

    private func currentEntry() -> WaveTimelineEntry? {
        guard let conditions = store.waveConditions, let first = conditions.first else { return nil }
        let prefs = store.preferences
        return WaveTimelineEntry(
            date: first.time,
            waveHeight: first.waveHeight,
            waveDirection: first.waveDirection,
            wavePeriod: first.wavePeriod,
            windSpeed: first.windSpeed,
            windDirection: first.windDirection,
            seaSurfaceTemperature: first.seaSurfaceTemperature,
            useMetric: prefs.useMetricUnits
        )
    }
}
