import AppKit
import GazeKit
import Observation
import UniformTypeIdentifiers

struct Recording: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var date: Date
    var duration: TimeInterval
    /// Screen size in points at recording time.
    var screenSize: CGSize
    /// Samples with `t` relative to the recording start and normalized coordinates.
    var samples: [GazeSample]
    var hasScreenshot: Bool

    var aspectRatio: Double { Double(screenSize.width / max(screenSize.height, 1)) }

    func fixations() -> [Fixation] {
        // I-DT in points: ~60 pt ≈ 1.5° at 60 cm on a typical laptop.
        let points = samples.map {
            GazeSample(t: $0.t, x: $0.x * Double(screenSize.width), y: $0.y * Double(screenSize.height))
        }
        return FixationDetector(maxDispersion: 60, minDuration: 0.12).detect(points)
    }

    func csv() -> String {
        var lines = ["t_seconds,x_norm,y_norm,x_pt,y_pt"]
        lines.reserveCapacity(samples.count + 1)
        for s in samples {
            lines.append(String(format: "%.4f,%.5f,%.5f,%.1f,%.1f",
                                s.t, s.x, s.y, s.x * Double(screenSize.width), s.y * Double(screenSize.height)))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Persists recordings as JSON (plus an optional PNG screenshot) in
/// ~/Library/Application Support/OculOS/Recordings.
@MainActor @Observable
final class RecordingStore {
    private(set) var recordings: [Recording] = []
    @ObservationIgnored private var screenshotCache: [UUID: NSImage] = [:]

    init() {
        let decoder = JSONDecoder()
        let files = (try? FileManager.default.contentsOfDirectory(at: AppPaths.recordings, includingPropertiesForKeys: nil)) ?? []
        recordings = files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? decoder.decode(Recording.self, from: Data(contentsOf: $0)) }
            .sorted { $0.date > $1.date }
    }

    func add(_ recording: Recording, screenshot: CGImage?) {
        var recording = recording
        if let screenshot, Self.writePNG(screenshot, to: pngURL(recording.id)) {
            recording.hasScreenshot = true
        }
        recordings.insert(recording, at: 0)
        save(recording)
    }

    func rename(_ id: UUID, to name: String) {
        guard let index = recordings.firstIndex(where: { $0.id == id }) else { return }
        recordings[index].name = name
        save(recordings[index])
    }

    func delete(_ id: UUID) {
        recordings.removeAll { $0.id == id }
        screenshotCache[id] = nil
        try? FileManager.default.removeItem(at: jsonURL(id))
        try? FileManager.default.removeItem(at: pngURL(id))
    }

    func screenshot(for recording: Recording) -> NSImage? {
        guard recording.hasScreenshot else { return nil }
        if let cached = screenshotCache[recording.id] { return cached }
        let image = NSImage(contentsOf: pngURL(recording.id))
        screenshotCache[recording.id] = image
        return image
    }

    private func save(_ recording: Recording) {
        guard let data = try? JSONEncoder().encode(recording) else { return }
        try? data.write(to: jsonURL(recording.id), options: .atomic)
    }

    private func jsonURL(_ id: UUID) -> URL { AppPaths.recordings.appendingPathComponent("\(id.uuidString).json") }
    private func pngURL(_ id: UUID) -> URL { AppPaths.recordings.appendingPathComponent("\(id.uuidString).png") }

    @discardableResult
    static func writePNG(_ image: CGImage, to url: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
}

/// Samples being collected for an in-progress recording.
struct ActiveRecording {
    var startDate = Date()
    var firstTimestamp: TimeInterval?
    var samples: [GazeSample] = []
    var screenSize: CGSize
    var screenshot: CGImage?

    mutating func append(_ sample: GazeSample) {
        let start = firstTimestamp ?? sample.t
        firstTimestamp = start
        samples.append(GazeSample(t: sample.t - start, x: sample.x, y: sample.y))
    }
}
