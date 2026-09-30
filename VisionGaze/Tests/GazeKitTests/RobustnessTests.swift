import CoreGraphics
import Foundation
import Testing
@testable import GazeKit

@Suite struct RobustnessTests {
    @Test func blinkDetectorFlagsShortBlinks() {
        var detector = BlinkDetector()
        var t = 0.0
        // `update` is mutating, so call it outside #expect.
        func step(_ openness: Double) -> Bool {
            defer { t += 1 / 30 }
            return detector.update(openness: openness, timestamp: t)
        }
        for _ in 0..<30 { let blink = step(0.30); #expect(!blink) }
        // A 200 ms blink is flagged throughout, then tracking resumes.
        for _ in 0..<6 { let blink = step(0.10); #expect(blink) }
        let reopened = step(0.30)
        #expect(!reopened)
    }

    @Test func blinkDetectorRecoversFromSustainedSquint() {
        var detector = BlinkDetector()
        var t = 0.0
        // An inflated start (wide-eyed), then a lasting squint.
        let first = detector.update(openness: 0.35, timestamp: t)
        #expect(!first)
        var lastBlink = t
        for _ in 0..<60 {
            t += 1 / 30
            if detector.update(openness: 0.20, timestamp: t) { lastBlink = t }
        }
        // Before the fix every later frame was a "blink" and tracking stopped for good.
        #expect(lastBlink < 0.45)
        let squinting = detector.update(openness: 0.20, timestamp: t + 1 / 30)
        #expect(!squinting)
    }

    @Test func blinkBaselineIgnoresWideEyedFirstFrame() {
        var detector = BlinkDetector()
        var t = 0.0
        _ = detector.update(openness: 0.60, timestamp: t)
        for _ in 0..<20 { t += 1 / 30; _ = detector.update(openness: 0.30, timestamp: t) }
        #expect(abs((detector.baseline ?? 0) - 0.30) < 0.02)
    }

    @Test func solverToleranceScalesWithMatrix() throws {
        // Well conditioned but tiny: an absolute 1e-12 pivot threshold rejects it.
        let x = try #require(LinearAlgebra.solve([[1e-13, 0], [0, 1e-13]], [1e-13, 2e-13]))
        #expect(abs(x[0] - 1) < 1e-9 && abs(x[1] - 2) < 1e-9)
        // Singular at mm² scale: rows differ only by rounding-level noise.
        #expect(LinearAlgebra.solve([[1e6, 2e6], [2e6, 4e6 + 1e-9]], [1, 2]) == nil)
    }

    @Test func rollFallbackIsNearLevel() {
        #expect(abs(FaceFeatureExtractor.wrapToHalfTurn(.pi - 0.1) - (-0.1)) < 1e-12)
        #expect(abs(FaceFeatureExtractor.wrapToHalfTurn(-.pi + 0.1) - 0.1) < 1e-12)
        #expect(abs(FaceFeatureExtractor.wrapToHalfTurn(0.2) - 0.2) < 1e-12)
    }

    @Test func rejectsMalformedCalibrationFiles() throws {
        let model = GazeCalibration(
            geometry: ScreenGeometry(widthMM: 300, heightMM: 195, imageAspect: 16 / 9),
            params: [Double](repeating: 0, count: GazeCalibration.P.allCases.count),
            featureMean: [0, 0, 0], appearance: nil,
            report: CalibrationReport(points: [], rmsError: 0), createdAt: Date()
        )
        let data = try JSONEncoder().encode(model)
        _ = try JSONDecoder().decode(GazeCalibration.self, from: data)

        func decode(_ edit: (inout [String: Any]) -> Void) throws -> GazeCalibration {
            var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
            edit(&json)
            return try JSONDecoder().decode(GazeCalibration.self, from: JSONSerialization.data(withJSONObject: json))
        }
        #expect(throws: DecodingError.self) { try decode { $0["featureMean"] = [0, 0] } }
        #expect(throws: DecodingError.self) {
            try decode { $0["appearance"] = ["mean": [0, 0, 0], "weights": [[0, 0, 0], [0, 0]], "ridge": 1] }
        }
    }
}
