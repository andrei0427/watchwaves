import SwiftUI

struct ContentView: View {
    @State private var viewModel = WaveViewModel()
    @State private var showForecast = false
    @State private var showMap = false
    @State private var mapVisible = false  // deferred — lets sheet appear before constructing the heavy map
    @State private var mapLoaded = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            TabView {
                conditionsTab
                    .tag(0)
                compassTab
                    .tag(1)
                WebcamListView(
                    condition: viewModel.currentCondition,
                    useMetric: viewModel.preferences.useMetricUnits
                )
                .tag(2)
            }
            .tabViewStyle(.verticalPage)
        }
        .task {
            NSLog("[WatchWaves] ContentView .task firing")
            await viewModel.loadData()
            NSLog("[WatchWaves] ContentView .task completed")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.loadData() }
            }
        }
        .onAppear { viewModel.locationService.startHeadingUpdates() }
        .onDisappear { viewModel.locationService.stopHeadingUpdates() }
    }

    // MARK: - Tab 1: Conditions → forecast sheet on tap

    @ViewBuilder
    private var conditionsTab: some View {
        if let condition = viewModel.currentCondition {
            CurrentConditionsView(
                mode: .conditions,
                condition: condition,
                useMetric: viewModel.preferences.useMetricUnits,
                coastDirection: viewModel.selectedCoast?.direction,
                heading: viewModel.locationService.heading,
                lastUpdated: DataStore.shared.lastUpdateTime,
                beachName: viewModel.nearestBeachName,
                coastBearing: viewModel.coastBearing,
                coastDistanceKm: viewModel.coastDistanceKm,
                onTap: { showForecast = true }
            )
            .sheet(isPresented: $showForecast) {
                ForecastView(
                    forecast: viewModel.forecast,
                    useMetric: viewModel.preferences.useMetricUnits,
                    lastUpdated: DataStore.shared.lastUpdateTime,
                    onRefresh: { await viewModel.loadData() }
                )
            }
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

    // MARK: - Tab 2: Compass → map sheet on tap

    @ViewBuilder
    private var compassTab: some View {
        if let condition = viewModel.currentCondition {
            CurrentConditionsView(
                mode: .compass,
                condition: condition,
                useMetric: viewModel.preferences.useMetricUnits,
                coastDirection: viewModel.selectedCoast?.direction,
                heading: viewModel.locationService.heading,
                lastUpdated: DataStore.shared.lastUpdateTime,
                beachName: viewModel.nearestBeachName,
                coastBearing: viewModel.coastBearing,
                coastDistanceKm: viewModel.coastDistanceKm,
                onTap: { showMap = true }
            )
            .sheet(isPresented: $showMap) {
                mapSheet
            }
        } else if viewModel.isLoading {
            VStack(spacing: 8) {
                ProgressView()
                Image(systemName: "location.circle")
                    .font(.title2)
                    .foregroundStyle(.cyan.opacity(0.4))
            }
        } else {
            Image(systemName: "location.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Map Sheet (shown when compass is tapped)

    @ViewBuilder
    private var mapSheet: some View {
        ZStack {
            // Only constructed after sheet has appeared, so the spinner shows first
            if mapVisible,
               let detection = viewModel.coastDetection,
               let condition = viewModel.currentCondition {
                WaveMapView(
                    detection: detection,
                    condition: condition,
                    selectedCoast: viewModel.selectedCoast,
                    useMetric: viewModel.preferences.useMetricUnits
                )
                .onAppear {
                    withAnimation(.easeOut(duration: 0.3)) { mapLoaded = true }
                }
            }

            // Loading overlay — shown until map fires onAppear
            if !mapLoaded {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading map...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.opacity)
            }
        }
        .task {
            // Short delay lets the sheet animate in with the spinner before MapKit initialises
            try? await Task.sleep(for: .milliseconds(80))
            mapVisible = true
        }
        .onChange(of: showMap) { _, shown in
            if !shown { mapVisible = false; mapLoaded = false }
        }
    }
}

#Preview {
    ContentView()
}
