import SwiftUI
import WidgetKit

struct InlineComplicationView: View {
    let entry: WaveTimelineEntry

    var body: some View {
        Label(entry.inlineString, systemImage: "water.waves")
    }
}
