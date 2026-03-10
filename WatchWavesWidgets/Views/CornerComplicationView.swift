import SwiftUI
import WidgetKit

struct CornerComplicationView: View {
    let entry: WaveTimelineEntry

    var body: some View {
        Text(entry.heightString)
            .font(.title3)
            .widgetLabel {
                Label(entry.inlineString, systemImage: "water.waves")
            }
    }
}
