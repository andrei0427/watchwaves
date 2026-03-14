import SwiftUI

// MARK: - Section model

private struct WebcamSection: Identifiable {
    let letter: String
    let cameras: [WebcamEntry]
    var id: String { letter }

    static func build() -> [WebcamSection] {
        let sorted = WebcamEntry.coastal.sorted { $0.name < $1.name }
        var dict: [String: [WebcamEntry]] = [:]
        for entry in sorted {
            let key = String(entry.name.prefix(1)).uppercased()
            dict[key, default: []].append(entry)
        }
        return dict.keys.sorted().map { WebcamSection(letter: $0, cameras: dict[$0]!) }
    }
}

// MARK: - Section rows (extracted to keep body type-check fast)

private struct WebcamSectionRows: View {
    let section: WebcamSection

    var body: some View {
        Section {
            ForEach(section.cameras) { entry in
                NavigationLink {
                    WebcamSnapshotView(entry: entry)
                } label: {
                    Text(entry.name)
                        .font(.system(size: 14, weight: .medium))
                }
                .id(entry.id)
            }
        } header: {
            Text(section.letter)
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.cyan)
        }
    }
}

// MARK: - List View

struct WebcamListView: View {
    private let sections = WebcamSection.build()

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .trailing) {
                cameraList
                letterStrip(proxy: proxy)
            }
        }
        .navigationTitle("Webcams")
    }

    private var cameraList: some View {
        List {
            ForEach(sections) { section in
                WebcamSectionRows(section: section)
            }
        }
    }

    private func letterStrip(proxy: ScrollViewProxy) -> some View {
        VStack(spacing: 1) {
            ForEach(sections) { section in
                Text(section.letter)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.cyan)
                    .frame(width: 16, height: 16)
                    .onTapGesture {
                        if let firstId = section.cameras.first?.id {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(firstId, anchor: .top)
                            }
                        }
                    }
            }
        }
        .padding(.trailing, 1)
        .background(Color.black.opacity(0.01))
    }
}

// MARK: - Snapshot View

struct WebcamSnapshotView: View {
    let entry: WebcamEntry
    @State private var image: Image?
    @State private var lastFetched: Date?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "camera.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.3))
                    Text(entry.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            VStack {
                Spacer()
                VStack(spacing: 2) {
                    Text(entry.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let lastFetched {
                        Text(lastFetched.formatted(date: .omitted, time: .standard))
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(.bottom, 6)
            }
        }
        .navigationBarHidden(true)
        .onTapGesture { dismiss() }
        .task {
            await refreshLoop()
        }
    }

    private func refreshLoop() async {
        while !Task.isCancelled {
            await loadSnapshot()
            try? await Task.sleep(for: .seconds(8))
        }
    }

    private func loadSnapshot() async {
        let urlString = entry.snapshotURL.absoluteString + "?t=\(Int(Date().timeIntervalSince1970))"
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let uiImage = UIImage(data: data) else { return }
        image = Image(uiImage: uiImage)
        lastFetched = Date()
    }
}
