import CoreGraphics
import Foundation
import Testing
@testable import GazeKit

/// Blinks, noise and gaps: the things that make a webcam gaze cursor jump or click on its own.
@Suite struct StabilityTests {
    func blinks(_ detector: inout BlinkDetector, _ openness: [Double], from t: inout Double) -> [Bool] {
        openness.map { o in
            t += 1.0 / 30
            return detector.update(openness: o, at: t)
        }
    }

    @Test func blinkHoldsTheHalfOpenFramesAroundIt() {
        var detector = BlinkDetector(), t = 0.0
        _ = blinks(&detector, Array(repeating: 0.3, count: 30), from: &t)
        // Closing, shut, reopening: the half-open frames on the way back up (0.20,
        // 0.24) read as looking down, so they belong to the blink too.
        let held = blinks(&detector, [0.24, 0.12, 0.04, 0.03, 0.03, 0.08, 0.15, 0.20, 0.24, 0.27, 0.29], from: &t)
        #expect(held == [false, true, true, true, true, true, true, true, true, false, false])
    }

    @Test func eyesThatStayShutStayABlink() {
        var detector = BlinkDetector(), t = 0.0
        _ = blinks(&detector, Array(repeating: 0.3, count: 30), from: &t)
        let shut = blinks(&detector, Array(repeating: 0.04, count: 60), from: &t)
        #expect(shut.allSatisfy { $0 })
        // …and never became the baseline: open eyes are open again.
        let open = blinks(&detector, Array(repeating: 0.3, count: 10), from: &t)
        #expect(open.suffix(5).allSatisfy { !$0 })
    }

    @Test func blinkBaselineFollowsASquint() {
        var detector = BlinkDetector(), t = 0.0
        let open = blinks(&detector, Array(repeating: 0.3, count: 30), from: &t)
        #expect(!open.contains(true))
        // Squinting for 2 s: a blink at first, then the new normal.
        let squint = blinks(&detector, Array(repeating: 0.15, count: 60), from: &t)
        #expect(squint.first == true && squint.last == false)
        let blink = blinks(&detector, [0.03, 0.03, 0.03], from: &t)
        #expect(blink.allSatisfy { $0 })
    }

    @Test func outliersOnOppositeSidesAreNoise() {
        var stabilizer = FixationStabilizer(radius: 60), t = 0.0
        func update(_ x: Double, _ y: Double) -> CGPoint { t += 1.0 / 30; return stabilizer.update(CGPoint(x: x, y: y), at: t) }
        for _ in 0..<10 { _ = update(500, 400) }
        // Both just outside the radius, close to each other, but their mean is this fixation.
        _ = update(563, 400)
        let out = update(520, 458)
        #expect(out.distance(to: CGPoint(x: 500, y: 400)) < 20)
    }

    @Test func outsideSamplesAcrossAGapDontConfirmEachOther() {
        var stabilizer = FixationStabilizer(radius: 60), t = 0.0
        for _ in 0..<10 { t += 1.0 / 30; _ = stabilizer.update(CGPoint(x: 500, y: 400), at: t) }
        _ = stabilizer.update(CGPoint(x: 500, y: 520), at: t + 0.033)
        let out = stabilizer.update(CGPoint(x: 505, y: 515), at: t + 0.333) // the face was lost in between
        #expect(out == CGPoint(x: 500, y: 400))
    }

    @Test func aBlinkDiscardsThePendingSample() {
        var stabilizer = FixationStabilizer(radius: 60), t = 0.0
        func update(_ x: Double, _ y: Double) -> CGPoint { t += 1.0 / 30; return stabilizer.update(CGPoint(x: x, y: y), at: t) }
        for _ in 0..<10 { _ = update(500, 400) }
        // The lid closing reads as a glance down; so does the first frame after it reopens.
        _ = update(500, 520)
        stabilizer.discardPending()
        #expect(update(500, 515) == CGPoint(x: 500, y: 400))
    }

    @Test func dwellDoesNotCountClosedEyes() {
        var dwell = Dwell(duration: 1, radius: 50)
        dwell.maxGap = 0.1
        let p = CGPoint(x: 100, y: 100)
        var t = 0.0
        var early = false
        for _ in 0..<15 { t += 1.0 / 30; early = early || dwell.update(p, at: t) } // 0.5 s of looking
        t += 1.0 // eyes closed: no gaze updates
        early = early || dwell.update(p, at: t)
        #expect(!early)
        #expect(dwell.progress < 0.65)
        var fired = false
        for _ in 0..<20 { t += 1.0 / 30; fired = fired || dwell.update(p, at: t) } // the rest of the dwell
        #expect(fired)
    }

    @Test func fixationsDontSpanGaps() {
        var samples: [GazeSample] = []
        for i in 0..<30 { samples.append(GazeSample(t: Double(i) / 30, x: 100, y: 100)) }
        // 3 s looking at the keyboard (no samples), then back at the same place.
        for i in 0..<30 { samples.append(GazeSample(t: 4 + Double(i) / 30, x: 100, y: 100)) }
        let fixations = FixationDetector(maxDispersion: 30, minDuration: 0.1).detect(samples)
        #expect(fixations.count == 2)
        #expect(fixations.allSatisfy { $0.duration < 1.1 })
        #expect(FixationDetector(maxDispersion: 30).detect([]).isEmpty)
    }

    func frames(_ points: [CGPoint], end: TimeInterval = 10) -> [(features: GazeFeatures, predicted: CGPoint)] {
        let eye = EyeFeatures(pupil: CGPoint(x: 0.5, y: 0), openness: 0.3)
        return points.enumerated().map { i, p in
            let f = GazeFeatures(timestamp: end - Double(points.count - 1 - i) / 30, left: eye, right: eye, yaw: 0, pitch: 0,
                                 roll: 0, faceCenter: CGPoint(x: 0.5, y: 0.5), faceSize: 0.3, isBlinking: false)
            return (f, p)
        }
    }

    @Test func clickLearningKeepsOnlyASteadyLookNearTheClick() {
        let ppd = 50.0, target = CGPoint(x: 700, y: 400)
        // Steady, 1.5° from the click: learned.
        let steady = frames(Array(repeating: CGPoint(x: 760, y: 420), count: 9))
        #expect(ClickLearning.select(steady, target: target, pointsPerDegree: ppd, accuracyDegrees: 2).count == 9)
        // Steady but 10° away: the user was looking elsewhere.
        let away = frames(Array(repeating: CGPoint(x: 1200, y: 400), count: 9))
        #expect(ClickLearning.select(away, target: target, pointsPerDegree: ppd, accuracyDegrees: 2).isEmpty)
        // A 600 pt sweep through the target: a saccade, not a fixation.
        let sweep = frames((0..<9).map { CGPoint(x: 400 + Double($0) * 75, y: 400) })
        #expect(ClickLearning.select(sweep, target: target, pointsPerDegree: ppd, accuracyDegrees: 2).isEmpty)
        // Only the last 0.3 s count: frames from half a second earlier don't.
        let earlier = frames(Array(repeating: CGPoint(x: 700, y: 400), count: 5), end: 9.4)
        let recent = frames(Array(repeating: CGPoint(x: 700, y: 400), count: 6))
        #expect(ClickLearning.select(earlier + recent, target: target, pointsPerDegree: ppd, accuracyDegrees: 2).count == 6)
    }
}
