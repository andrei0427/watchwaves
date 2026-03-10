import SwiftUI
import WidgetKit

struct RectangularComplicationView: View {
    let entry: WaveTimelineEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                    .font(.caption2)
                Text("Waves")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(entry.heightString)
                .font(.system(.title3, design: .rounded, weight: .bold))

            HStack(spacing: 6) {
                if let dir = entry.directionLabel {
                    Text(dir)
                }
                Text(entry.periodString)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
