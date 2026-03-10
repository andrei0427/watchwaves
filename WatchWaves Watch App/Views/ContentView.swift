import SwiftUI

struct ContentView: View {
    @State private var viewModel = WaveViewModel()
    @State private var selectedTab = 1

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                if let detection = viewModel.coastDetection {
                    WaveMapView(
                        detection: detection,
                        condition: viewModel.currentCondition,
                        selectedCoast: viewModel.selectedCoast
                    )
                    .tag(0)
                }

                mainPage
                    .tag(1)

                if !viewModel.forecast.isEmpty {
                    ForecastView(
                        forecast: viewModel.forecast,
                        useMetric: viewModel.preferences.useMetricUnits,
                        lastUpdated: DataStore.shared.lastUpdateTime,
                        onRefresh: { await viewModel.loadData() }
                    )
                    .tag(2)
                }
            }
            .tabViewStyle(.verticalPage)
        }
        .task {
            NSLog("[WatchWaves] ContentView .task firing")
            await viewModel.loadData()
            NSLog("[WatchWaves] ContentView .task completed")
        }
        .onAppear { viewModel.locationService.startHeadingUpdates() }
        .onDisappear { viewModel.locationService.stopHeadingUpdates() }
    }

    @ViewBuilder
    private var mainPage: some View {
        if let condition = viewModel.currentCondition {
            CurrentConditionsView(
                condition: condition,
                useMetric: viewModel.preferences.useMetricUnits,
                coastDirection: viewModel.selectedCoast?.direction,
                heading: viewModel.locationService.heading,
                lastUpdated: DataStore.shared.lastUpdateTime,
                beachName: viewModel.nearestBeachName,
                coastBearing: viewModel.coastBearing,
                coastDistanceKm: viewModel.coastDistanceKm
            )
        } else if viewModel.isLoading {
            VStack(spacing: 8) {
                ProgressView()
                Text("Detecting coast...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task { await viewModel.loadData() }
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "water.waves")
                    .font(.largeTitle)
                    .foregroundStyle(.cyan)
                Button("Load Waves") {
                    Task { await viewModel.loadData() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ContentView()
}
