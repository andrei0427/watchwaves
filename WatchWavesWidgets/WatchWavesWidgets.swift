import SwiftUI
import WidgetKit

struct WaveWidget: Widget {
    let kind: String = "WaveWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaveTimelineProvider()) { entry in
            WaveWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Wave Conditions")
        .description("Current wave height, direction, and period.")
        .supportedFamilies([
            .accessoryCorner,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
        ])
    }
}

struct WaveWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: WaveTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCorner:
            CornerComplicationView(entry: entry)
        case .accessoryCircular:
            CircularComplicationView(entry: entry)
        case .accessoryRectangular:
            RectangularComplicationView(entry: entry)
        case .accessoryInline:
            InlineComplicationView(entry: entry)
        default:
            Text(entry.heightString)
        }
    }
}

@main
struct WatchWavesWidgetBundle: WidgetBundle {
    var body: some Widget {
        WaveWidget()
    }
}
