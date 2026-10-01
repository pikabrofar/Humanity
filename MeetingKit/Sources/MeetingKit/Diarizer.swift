import CoreML
import FluidAudio
import Foundation

public protocol SpeakerDiarizer: Sendable {
    func diarize(_ audioURL: URL) async throws -> Diarization
}

/// FluidAudio's offline pipeline (pyannote community-1 segmentation, WeSpeaker
/// embeddings, VBx clustering), run once on the finished system-audio track. Offline
/// beats streaming here: it sees the whole meeting before deciding how many voices exist.
public struct FluidDiarizer: SpeakerDiarizer {
    /// Set when the user knows how many remote people spoke; otherwise it's estimated.
    public var expectedSpeakers: Int?

    public init(expectedSpeakers: Int? = nil) {
        self.expectedSpeakers = expectedSpeakers
    }

    public func diarize(_ audioURL: URL) async throws -> Diarization {
        var config = OfflineDiarizerConfig.default
        config.clustering.numSpeakers = expectedSpeakers
        let manager = OfflineDiarizerManager(config: config)
        // First use downloads the Core ML models from Hugging Face into
        // FluidAudio's cache. Audio is processed locally and never uploaded.
        // `.all` lets Core ML use the GPU: on macOS 14 the CPU-only BNNS path can crash
        // (FluidAudio issue #878).
        let models = MLModelConfiguration()
        models.computeUnits = .all
        try await manager.prepareModels(configuration: models)
        let result = try await manager.process(audioURL)

        let segments = result.segments.map {
            SpeakerSegment(start: Double($0.startTimeSeconds), end: Double($0.endTimeSeconds), speaker: $0.speakerId)
        }
        var centroids = result.speakerDatabase ?? [:]
        for segment in result.segments where centroids[segment.speakerId] == nil {
            centroids[segment.speakerId] = segment.embedding
        }
        return Diarization(segments: segments, centroids: centroids)
    }
}
