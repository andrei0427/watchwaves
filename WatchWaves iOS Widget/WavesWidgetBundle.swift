import SwiftUI
import WidgetKit

// MARK: - Lock screen widget (accessoryCircular / Rectangular / Inline)

struct LockScreenWaveWidget: Widget {
    let kind: String = "LockScreenWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaveTimelineProvider()) { entry in
            LockScreenWaveWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wave Conditions")
        .description("Wave height, direction, and period on your lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWaveWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WaveTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCircular:    CircularComplicationView(entry: entry)
        case .accessoryRectangular: RectangularComplicationView(entry: entry)
        case .accessoryInline:      InlineComplicationView(entry: entry)
        default:                    Text(entry.heightString)
        }
    }
}

// MARK: - Home screen widget (systemSmall / systemMedium)

struct HomeScreenWaveWidget: Widget {
    let kind: String = "HomeScreenWaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaveTimelineProvider()) { entry in
            HomeScreenWaveWidgetView(entry: entry)
                .containerBackground(
                    LinearGradient(
                        colors: [
                            Color(red: 5/255, green: 14/255, blue: 28/255),
                            Color(red: 8/255, green: 28/255, blue: 55/255)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    for: .widget
                )
        }
        .configurationDisplayName("Wave Dashboard")
        .description("Wave height, direction, wind, and sea temperature.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Bundle

@main
struct WavesWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWaveWidget()
        HomeScreenWaveWidget()
    }
}
