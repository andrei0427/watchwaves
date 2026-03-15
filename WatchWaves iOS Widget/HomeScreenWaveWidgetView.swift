import SwiftUI
import WidgetKit

struct HomeScreenWaveWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: WaveTimelineEntry

    var body: some View {
        switch family {
        case .systemMedium: mediumView
        default:            smallView
        }
    }

    // MARK: - Small (2×2)

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "water.waves")
                    .font(.system(size: 10))
                    .foregroundStyle(.cyan)
                Text("WatchWaves")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Text(entry.heightString)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            if let dir = entry.directionLabel {
                Text(dir)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.cyan)
            }

            Spacer(minLength: 0)

            Text(entry.periodString)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Medium (4×2)

    private var mediumView: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: wave
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "water.waves")
                        .font(.system(size: 10))
                        .foregroundStyle(.cyan)
                    Text("Waves")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                }
                Text(entry.heightString)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let dir = entry.directionLabel {
                    Text(dir)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                Spacer(minLength: 0)
                Text(entry.periodString)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1)
                .padding(.vertical, 4)

            // Right: wind + SST
            VStack(alignment: .leading, spacing: 10) {
                if let wind = entry.compactWindString, let windDir = entry.windDirectionLabel {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "wind")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                            Text("Wind")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Text("\(wind) \(windDir)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                if let sst = entry.seaSurfaceTemperature {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            Image(systemName: "thermometer.medium")
                                .font(.system(size: 9))
                                .foregroundStyle(.orange.opacity(0.6))
                            Text("Sea")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Text(WaveFormatter.temperatureString(sst, useMetric: entry.useMetric))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 14)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
