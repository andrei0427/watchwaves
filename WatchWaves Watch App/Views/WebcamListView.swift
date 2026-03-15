import SwiftUI
import AVKit
import AVFoundation
#if os(watchOS)
import WatchKit
#endif

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

// MARK: - Webcam View (live stream preferred, snapshot fallback)

struct WebcamSnapshotView: View {
    let entry: WebcamEntry
    @Environment(\.dismiss) private var dismiss

    // Live stream
    @State private var player: AVPlayer?
    // Snapshot fallback
    @State private var image: Image?
    @State private var lastFetched: Date?
    // Loading state
    @State private var resolving = false
    // Zoom state (snapshot only, iOS)
    #if os(iOS)
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    #endif

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .disabled(true)
                    #if os(iOS)
                    .scaleEffect(scale)
                    .offset(offset)
                    #endif
            } else if let image {
                #if os(iOS)
                image
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(scale)
                    .offset(offset)
                    .clipped()
                    .ignoresSafeArea()
                #else
                image
                    .resizable()
                    .scaledToFill()
                    .clipped()
                    .ignoresSafeArea()
                #endif
            } else {
                VStack(spacing: 6) {
                    if resolving {
                        ProgressView()
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    Text(entry.name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Gesture overlay — sits above content, below UI labels
            #if os(iOS)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newScale = max(1, lastScale * value)
                            scale = newScale
                            // As we zoom out, pull offset proportionally toward center
                            if lastScale > 1 {
                                let progress = (newScale - 1) / (lastScale - 1)
                                offset = CGSize(
                                    width: lastOffset.width * progress,
                                    height: lastOffset.height * progress
                                )
                            }
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                            if scale <= 1 {
                                scale = 1; lastScale = 1
                                offset = .zero; lastOffset = .zero
                            }
                        }
                        .simultaneously(with:
                            DragGesture()
                                .onChanged { value in
                                    guard scale > 1 else { return }
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(duration: 0.3)) {
                        scale = 1; lastScale = 1
                        offset = .zero; lastOffset = .zero
                    }
                }
                .onTapGesture { dismiss() }
            #endif

            // Overlays
            VStack {
                HStack {
                    if player != nil {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(.red)
                                .frame(width: 5, height: 5)
                            Text("LIVE")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                    }
                    Spacer()
                }
                .padding(.top, 6)
                .padding(.horizontal, 6)

                Spacer()
                // Name label — shown over snapshot only
                if player == nil {
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
                        #if os(iOS)
                        Text(scale > 1 ? "Double-tap to reset · Tap to close" : "Tap to close")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.4))
                        #endif
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 6)
                }
            }
        }
        .navigationBarHidden(true)
        .task { await start() }
        .onDisappear { player?.pause() }
    }

    // MARK: - Start

    private func start() async {
        guard let pageURL = entry.pageURL else {
            await snapshotLoop(); return
        }
        resolving = true
        if let streamURL = await resolveStreamURL(from: pageURL) {
            resolving = false
            let p = AVPlayer(url: streamURL)
            p.play()
            player = p
        } else {
            resolving = false
            await snapshotLoop()
        }
    }

    // MARK: - Live stream URL extraction

    private func resolveStreamURL(from pageURL: URL) async -> URL? {
        var request = URLRequest(url: pageURL)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8) else { return nil }

        // Pattern 1: relative m3u8 URL in Clappr player config, e.g. source:'livee.m3u8?a=TOKEN'
        if let range = html.range(of: #"live[e]?\.m3u8\?a=[a-z0-9]+"#, options: .regularExpression) {
            let matched = String(html[range])
            if let token = matched.components(separatedBy: "?a=").last {
                return URL(string: "https://hd-auth.skylinewebcams.com/live.m3u8?a=\(token)")
            }
        }

        // Pattern 2: full absolute m3u8 URL
        if let range = html.range(of: #"https://hd-auth\.skylinewebcams\.com/live[e]?\.m3u8\?a=[a-z0-9]+"#, options: .regularExpression) {
            return URL(string: String(html[range]))
        }

        // Pattern 3: token in webcam.js script reference
        if let range = html.range(of: #"(?<=webcam\.js\?a=)[a-z0-9]+"#, options: .regularExpression) {
            return URL(string: "https://hd-auth.skylinewebcams.com/live.m3u8?a=\(String(html[range]))")
        }

        return nil
    }

    // MARK: - Snapshot fallback

    private func snapshotLoop() async {
        while !Task.isCancelled {
            await loadSnapshot()
            try? await Task.sleep(for: .seconds(30))
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
