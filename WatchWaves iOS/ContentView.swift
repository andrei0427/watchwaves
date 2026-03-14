import SwiftUI
import MapKit

// MARK: - Root

struct ContentView: View {
    @State private var viewModel = WaveViewModel()

    var body: some View {
        TabView {
            ConditionsTab(viewModel: viewModel)
                .tabItem { Label("Waves", systemImage: "water.waves") }

            CompassTab(viewModel: viewModel)
                .tabItem { Label("Compass", systemImage: "location.north.line") }

            MapTab(viewModel: viewModel)
                .tabItem { Label("Map", systemImage: "map") }

            NavigationStack {
                WebcamListView()
                    .navigationTitle("Webcams")
            }
            .tabItem { Label("Webcams", systemImage: "video") }
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.loadData() }
        .onAppear { viewModel.locationService.startHeadingUpdates() }
        .onDisappear { viewModel.locationService.stopHeadingUpdates() }
    }
}

// MARK: - Conditions Tab

struct ConditionsTab: View {
    let viewModel: WaveViewModel
    @State private var showForecast = false

    var body: some View {
        NavigationStack {
            ZStack {
                oceanBackground.ignoresSafeArea()
                Group {
                    if let condition = viewModel.currentCondition {
                        conditionsContent(condition)
                    } else if viewModel.isLoading {
                        loadingView
                    } else if let error = viewModel.errorMessage {
                        errorView(error)
                    } else {
                        emptyView
                    }
                }
            }
            .navigationTitle("WatchWaves")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .sheet(isPresented: $showForecast) {
                NavigationStack {
                    ForecastView(
                        forecast: viewModel.forecast,
                        useMetric: viewModel.preferences.useMetricUnits,
                        lastUpdated: DataStore.shared.lastUpdateTime
                    )
                    .background(Color(red: 5/255, green: 14/255, blue: 28/255).ignoresSafeArea())
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showForecast = false }
                        }
                    }
                }
                .preferredColorScheme(.dark)
            }
        }
    }

    private func conditionsContent(_ condition: WaveCondition) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                locationCard
                waveHeroCard(condition)
                if let ws = condition.windSpeed, let wd = condition.windDirection {
                    windCard(speed: ws, direction: wd)
                }
                if let h = condition.swellHeight, let p = condition.swellPeriod {
                    swellCard(height: h, direction: condition.swellDirection, period: p, label: "Primary Swell")
                }
                if let h = condition.secondarySwellHeight, let p = condition.secondarySwellPeriod, h > 0.1 {
                    swellCard(height: h, direction: condition.secondarySwellDirection, period: p, label: "Secondary Swell")
                }
                forecastButton
            }
            .padding()
        }
    }

    private var locationCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                if let name = viewModel.nearestBeachName {
                    Text(name)
                        .font(.headline).foregroundStyle(.white)
                } else if let coast = viewModel.selectedCoast?.direction {
                    Text("\(coast.label) Coast")
                        .font(.headline).foregroundStyle(.white)
                }
                if let dist = viewModel.coastDistanceKm {
                    Text(distanceString(dist))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer()
            if let updated = DataStore.shared.lastUpdateTime {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Updated")
                        .font(.caption2).foregroundStyle(.white.opacity(0.35))
                    Text(updated, style: .relative)
                        .font(.caption2).foregroundStyle(.white.opacity(0.45))
                }
            }
        }
        .padding()
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func waveHeroCard(_ condition: WaveCondition) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .bottom, spacing: 10) {
                Text(WaveFormatter.heightString(condition.waveHeight, useMetric: true))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 4) {
                    Text(condition.directionLabel)
                        .font(.title2.bold()).foregroundStyle(.white)
                    Text(WaveFormatter.periodString(condition.wavePeriod))
                        .font(.title3).foregroundStyle(.white.opacity(0.65))
                }
            }
            if let sst = condition.seaSurfaceTemperature {
                HStack(spacing: 6) {
                    Image(systemName: "thermometer.medium")
                    Text(WaveFormatter.temperatureString(sst, useMetric: true))
                }
                .font(.subheadline).foregroundStyle(.cyan.opacity(0.85))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28).padding(.horizontal)
        .background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.cyan.opacity(0.25), lineWidth: 1))
    }

    private func windCard(speed: Double, direction: Double) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "wind")
                .font(.title2).foregroundStyle(.white.opacity(0.6))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("Wind").font(.caption).foregroundStyle(.white.opacity(0.45))
                Text(WaveFormatter.windString(speed, useMetric: true))
                    .font(.title3.bold()).foregroundStyle(.white)
            }
            Spacer()
            DirectionIndicatorView(degrees: direction, size: 30)
                .frame(width: 30, height: 30)
        }
        .padding()
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private func swellCard(height: Double, direction: Double?, period: Double, label: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "water.waves")
                .font(.title2).foregroundStyle(.cyan.opacity(0.65))
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.white.opacity(0.45))
                HStack(spacing: 8) {
                    Text(WaveFormatter.heightString(height, useMetric: true))
                        .font(.title3.bold()).foregroundStyle(.white)
                    Text(WaveFormatter.periodString(period))
                        .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            if let dir = direction {
                DirectionIndicatorView(degrees: dir, size: 26)
                    .frame(width: 26, height: 26)
            }
        }
        .padding()
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
    }

    private var forecastButton: some View {
        Button {
            showForecast = true
        } label: {
            HStack {
                Image(systemName: "chart.bar.xaxis")
                Text("View Forecast")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption).foregroundStyle(.white.opacity(0.4))
            }
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding()
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.forecast.isEmpty)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5)
            Text("Detecting your nearest coast…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle).foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center).foregroundStyle(.secondary)
            Button("Retry") { Task { await viewModel.loadData() } }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "water.waves")
                .font(.system(size: 52)).foregroundStyle(.cyan)
            Button("Load Conditions") { Task { await viewModel.loadData() } }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var oceanBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 5/255, green: 14/255, blue: 28/255),
                Color(red: 8/255, green: 28/255, blue: 55/255)
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func distanceString(_ km: Double) -> String {
        km < 1 ? String(format: "%.0fm away", km * 1000) : String(format: "%.1fkm away", km)
    }
}

// MARK: - Compass Tab

struct CompassTab: View {
    let viewModel: WaveViewModel

    var body: some View {
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
                coastDistanceKm: viewModel.coastDistanceKm
            )
            .ignoresSafeArea()
        } else if viewModel.isLoading {
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5)
                Text("Loading conditions…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 5/255, green: 14/255, blue: 28/255).ignoresSafeArea())
        } else {
            Image(systemName: "location.north.line")
                .font(.system(size: 52)).foregroundStyle(.cyan)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 5/255, green: 14/255, blue: 28/255).ignoresSafeArea())
        }
    }
}

// MARK: - Map Tab

struct MapTab: View {
    let viewModel: WaveViewModel

    var body: some View {
        ZStack {
            if let detection = viewModel.coastDetection,
               let condition = viewModel.currentCondition {
                WaveMapView(
                    detection: detection,
                    condition: condition,
                    selectedCoast: viewModel.selectedCoast
                )
            } else if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Detecting coast…").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 5/255, green: 14/255, blue: 28/255).ignoresSafeArea())
            } else {
                Image(systemName: "map")
                    .font(.largeTitle).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(red: 5/255, green: 14/255, blue: 28/255).ignoresSafeArea())
            }
        }
    }
}
