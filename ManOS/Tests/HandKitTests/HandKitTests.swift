import CoreGraphics
import Foundation
import Testing
@testable import HandKit

/// Builds a synthetic hand. `pinch` is the thumb–index distance and `middle`
/// the thumb–middle distance, in palm units.
func hand(at anchor: CGPoint = CGPoint(x: 0.9, y: 0.5), scale: Double = 0.1,
          pinch: Double = 1.2, middle: Double = 1.2, fist: Bool = false, open: Bool = false,
          grip: Bool = false, tipsUp: Double = 0, t: TimeInterval) -> HandPose {
    let s = CGFloat(scale)
    func at(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: anchor.x + dx * s, y: anchor.y + dy * s) }
    // Palm triangle with unit-ish sides around the anchor.
    var j: [HandPose.Joint: CGPoint] = [
        .wrist: at(0, -0.75), .indexMCP: at(-0.4, 0.25), .middleMCP: at(0, 0.3), .ringMCP: at(0.25, 0.28), .littleMCP: at(0.45, 0.2),
    ]
    let fingers: [(HandPose.Joint, HandPose.Joint, CGFloat)] = [
        (.indexPIP, .indexTip, -0.4), (.middlePIP, .middleTip, 0), (.ringPIP, .ringTip, 0.25), (.littlePIP, .littleTip, 0.45),
    ]
    for (pip, tip, x) in fingers {
        j[pip] = at(x, 0.7)
        let curled = fist || (grip && tip != .indexTip)
        j[tip] = curled ? at(x * 0.5, 0.0) : at(x * (open ? 1.6 : 1), 1.3 + CGFloat(tipsUp))
    }
    // Thumb tip placed at the requested distance from the index / middle tips.
    let indexTip = j[.indexTip]!
    j[.thumbTip] = CGPoint(x: indexTip.x - CGFloat(pinch) * s, y: indexTip.y)
    if middle < pinch, let m = j[.middleTip] {
        j[.thumbTip] = CGPoint(x: m.x + CGFloat(middle) * s, y: m.y) // index stays clear of the thumb
    }
    return HandPose(joints: j, chirality: .right, timestamp: t)!
}

let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

func recognizer() -> GestureRecognizer {
    GestureRecognizer(mapper: PointerMapper(bounds: screen, cursor: CGPoint(x: 720, y: 450)))
}

/// Feeds `frames` at 30 fps starting at `start`, returns all events.
func run(_ r: inout GestureRecognizer, from start: Double, frames: Int, pose: (Double) -> HandPose?) -> [GestureEvent] {
    (0..<frames).flatMap { i -> [GestureEvent] in
        let t = start + Double(i) / 30
        return r.update(pose(t), at: t)
    }
}

@Suite struct GestureTests {
    @Test func poseGeometry() {
        let h = hand(t: 0)
        #expect(abs(h.indexPinch - 1.2) < 0.2)
        #expect(!h.isFist && !h.isOpenPalm)
        #expect(hand(fist: true, t: 0).isFist)
        #expect(hand(open: true, t: 0).isOpenPalm)
    }

    @Test func nothingBeforeEngageDwell() {
        var r = recognizer()
        let events = run(&r, from: 0, frames: 6, pose: { hand(pinch: 0.1, t: $0) })
        #expect(events.isEmpty)
        #expect(r.state == .engaging)
    }

    @Test func pinchClicks() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        #expect(r.state == .hovering)
        let events = run(&r, from: 0.4, frames: 6, pose: { hand(pinch: 0.1, t: $0) })
            + run(&r, from: 0.6, frames: 3, pose: { hand(t: $0) })
        #expect(events.contains { if case .down(_, clicks: 1) = $0 { true } else { false } })
        #expect(events.contains { if case .up(_, clicks: 1) = $0 { true } else { false } })
        #expect(!events.contains { if case .drag = $0 { true } else { false } })
    }

    @Test func twoQuickPinchesDoubleClick() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        var events = run(&r, from: 0.4, frames: 3, pose: { hand(pinch: 0.1, t: $0) })
        events += run(&r, from: 0.5, frames: 3, pose: { hand(t: $0) })
        events += run(&r, from: 0.6, frames: 3, pose: { hand(pinch: 0.1, t: $0) })
        #expect(events.contains { if case .down(_, clicks: 2) = $0 { true } else { false } })
    }

    @Test func hysteresisIgnoresHoveringNearThreshold() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        // Between enter (0.30) and exit (0.45): never enters.
        let events = run(&r, from: 0.4, frames: 30, pose: { t in hand(pinch: Int(t * 30) % 2 == 0 ? 0.33 : 0.42, t: t) })
        #expect(!events.contains { if case .down = $0 { true } else { false } })
    }

    @Test func singleFrameDipIsDebounced() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 10, pose: { t in hand(pinch: abs(t - 0.5) < 0.01 ? 0.1 : 1.2, t: t) })
        #expect(!events.contains { if case .down = $0 { true } else { false } })
    }

    @Test func pinchAndMoveDrags() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        _ = run(&r, from: 0.4, frames: 3, pose: { hand(pinch: 0.1, t: $0) })
        let events = run(&r, from: 0.5, frames: 15, pose: { t in
            hand(at: CGPoint(x: 0.9 + (t - 0.5) * 0.2, y: 0.5), pinch: 0.1, t: t)
        }) + run(&r, from: 1.0, frames: 3, pose: { hand(at: CGPoint(x: 1.0, y: 0.5), t: $0) })
        let drags = events.compactMap { if case .drag(let p) = $0 { p } else { nil } }
        #expect(drags.count > 5)
        #expect(drags.last!.x > 720)
        #expect(events.contains { if case .up = $0 { true } else { false } })
    }

    @Test func clickRewindsToWhereClosingBegan() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        // Fingers start closing while the hand is still…
        _ = run(&r, from: 0.4, frames: 3, pose: { hand(pinch: 0.55, t: $0) })
        let whereClosingBegan = r.mapper.cursor
        // …then the hand drifts as the pinch completes (the "Heisenberg effect").
        let drift = run(&r, from: 0.5, frames: 3, pose: { t in
            hand(at: CGPoint(x: 0.9 + (t - 0.5) * 0.6, y: 0.5), pinch: 0.4, t: t)
        })
        let events = run(&r, from: 0.6, frames: 3, pose: { hand(at: CGPoint(x: 0.96, y: 0.5), pinch: 0.1, t: $0) })
        let down = events.compactMap { if case .down(let p, _) = $0 { p } else { nil } }.first
        #expect(down != nil)
        #expect(down!.distance(to: whereClosingBegan) < 10)
        // Damping kept the drift small even before the rewind.
        let drifted = drift.compactMap { if case .move(let p) = $0 { p } else { nil } }.last ?? whereClosingBegan
        #expect(drifted.distance(to: whereClosingBegan) < 120)
    }

    @Test func flickUpEmitsNextAndRestoresCursor() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let before = r.mapper.cursor
        // A quick wrist flick: 0.2 image units (2 palm widths at scale 0.1) in ~130 ms.
        let events = run(&r, from: 0.4, frames: 5, pose: { t in
            hand(at: CGPoint(x: 0.9, y: 0.5 + min(t - 0.4, 0.13) / 0.13 * 0.2), t: t)
        })
        #expect(events.contains(GestureEvent.flick(.up)))
        #expect(r.mapper.cursor.distance(to: before) < 40)
        // The hand returning down right after doesn't flick back.
        let back = run(&r, from: 0.6, frames: 6, pose: { t in
            hand(at: CGPoint(x: 0.9, y: 0.7 - min(t - 0.6, 0.13) / 0.13 * 0.2), t: t)
        })
        #expect(!back.contains(GestureEvent.flick(.down)))
    }

    @Test func slowVerticalMovementIsNotAFlick() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 60, pose: { t in hand(at: CGPoint(x: 0.9, y: 0.5 + (t - 0.4) * 0.15), t: t) })
        #expect(!events.contains { if case .flick = $0 { true } else { false } })
        #expect(events.contains { if case .move = $0 { true } else { false } })
    }

    @Test func flickDisabledByProfile() {
        var r = recognizer()
        r.profile.flickEnabled = false
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 5, pose: { t in
            hand(at: CGPoint(x: 0.9, y: 0.5 + min(t - 0.4, 0.13) / 0.13 * 0.2), t: t)
        })
        #expect(!events.contains { if case .flick = $0 { true } else { false } })
    }

    @Test func oldProfilesKeepTheirThresholds() throws {
        let json = #"{"pinchEnter":0.22,"pinchExit":0.4,"sensitivity":1.5,"scrollSpeed":600,"invertScroll":false}"#
        let p = try JSONDecoder().decode(HandProfile.self, from: Data(json.utf8))
        #expect(p.pinchEnter == 0.22 && p.flickEnabled)
    }

    @Test func anchoredGripClicksWithoutMovingThePointer() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        // Curl middle, ring and little fingers: pointer anchored, index still out.
        let anchoredMoves = run(&r, from: 0.4, frames: 10, pose: { t in
            hand(at: CGPoint(x: 0.9 + (t - 0.4) * 0.3, y: 0.5), grip: true, t: t)
        })
        #expect(r.state == .clutched)
        #expect(!anchoredMoves.contains { if case .move = $0 { true } else { false } })
        let held = r.mapper.cursor
        let click = run(&r, from: 0.8, frames: 4, pose: { hand(at: CGPoint(x: 1.0, y: 0.5), pinch: 0.1, grip: true, t: $0) })
            + run(&r, from: 0.95, frames: 3, pose: { hand(at: CGPoint(x: 1.0, y: 0.5), grip: true, t: $0) })
        #expect(click.contains(GestureEvent.down(held, clicks: 1)))
        #expect(click.contains(GestureEvent.up(held, clicks: 1)))
        #expect(r.state == .clutched)
    }

    @Test func fullFistWithThumbOnIndexDoesNotClick() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 15, pose: { hand(pinch: 0.1, fist: true, t: $0) })
        #expect(!events.contains { if case .down = $0 { true } else { false } })
    }

    @Test func wristFlickDetectedFromFingertips() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        // Palm stays put; only the fingers swing up (a wrist flick).
        let events = run(&r, from: 0.4, frames: 6, pose: { t in hand(tipsUp: min(t - 0.4, 0.13) / 0.13 * 1.6, t: t) })
        #expect(events.contains(GestureEvent.flick(.up)))
    }

    @Test func cursorStaysOnRealDisplays() {
        var m = PointerMapper(bounds: CGRect(x: 0, y: 0, width: 3360, height: 1380), cursor: .zero)
        m.displays = [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: 1440, y: 300, width: 1920, height: 1080)]
        #expect(m.clamp(CGPoint(x: 1500, y: 100)) == CGPoint(x: 1439, y: 100)) // gap above display 2
        #expect(m.clamp(CGPoint(x: 2000, y: 600)) == CGPoint(x: 2000, y: 600))  // on display 2
        #expect(m.clamp(CGPoint(x: 100, y: 1200)) == CGPoint(x: 100, y: 899))   // below display 1
    }

    @Test func lostHandReleasesButton() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        _ = run(&r, from: 0.4, frames: 3, pose: { hand(pinch: 0.1, t: $0) })
        #expect(r.isButtonDown)
        let events = run(&r, from: 0.5, frames: 10, pose: { _ in nil })
        #expect(events.contains { if case .up = $0 { true } else { false } })
        #expect(r.state == .idle)
    }

    @Test func middlePinchRightClicksOrScrolls() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        var events = run(&r, from: 0.4, frames: 4, pose: { hand(middle: 0.1, t: $0) })
        events += run(&r, from: 0.54, frames: 2, pose: { hand(t: $0) })
        #expect(events.contains { if case .rightClick = $0 { true } else { false } })

        events = run(&r, from: 1.0, frames: 20, pose: { t in
            hand(at: CGPoint(x: 0.9, y: 0.5 + (t - 1.0) * 0.3), middle: 0.1, t: t)
        }) + run(&r, from: 1.7, frames: 2, pose: { hand(at: CGPoint(x: 0.9, y: 0.7), t: $0) })
        #expect(events.first { if case .scroll(_, _, .began) = $0 { true } else { false } } != nil)
        #expect(events.contains { if case .scroll(_, let dy, .changed) = $0 { dy > 0 } else { false } })
        #expect(events.contains { if case .scroll(_, _, .ended) = $0 { true } else { false } })
    }

    @Test func fistClutchFreezesCursor() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 15, pose: { t in
            hand(at: CGPoint(x: 0.9 + (t - 0.4) * 0.3, y: 0.5), fist: true, t: t)
        })
        #expect(!events.contains { if case .move = $0 { true } else { false } })
    }

    @Test func stillOpenPalmTogglesPause() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let events = run(&r, from: 0.4, frames: 55, pose: { hand(open: true, t: $0) })
        #expect(events.contains(GestureEvent.paused(true)))
        #expect(r.isPaused)
        // A moving open palm doesn't toggle it back.
        _ = run(&r, from: 2.3, frames: 5, pose: { hand(t: $0) })
        let moving = run(&r, from: 2.5, frames: 55, pose: { t in hand(at: CGPoint(x: 0.9 + (t - 2) * 0.5, y: 0.5), open: true, t: t) })
        #expect(!moving.contains(GestureEvent.paused(false)))
    }

    @Test func scaleInvariant() {
        func path(_ scale: Double) -> [GestureEvent] {
            var r = recognizer()
            _ = run(&r, from: 0, frames: 12, pose: { hand(scale: scale, t: $0) })
            return run(&r, from: 0.4, frames: 20, pose: { t in
                hand(at: CGPoint(x: 0.9 + (t - 0.4) * 3 * scale, y: 0.5), scale: scale, t: t)
            })
        }
        let near = path(0.2).compactMap { if case .move(let p) = $0 { p } else { nil } }.last!
        let far = path(0.05).compactMap { if case .move(let p) = $0 { p } else { nil } }.last!
        #expect(near.distance(to: far) < 5)
    }

    @Test func accelerationIsMonotonicAndClamped() {
        var slow = PointerMapper(bounds: screen, cursor: CGPoint(x: 720, y: 450))
        var fast = slow
        slow.track(.zero, at: 0)
        fast.track(.zero, at: 0)
        let s = slow.update(CGPoint(x: 0.1, y: 0), at: 1)     // 0.1 palm/s
        let f = fast.update(CGPoint(x: 0.1, y: 0), at: 0.02)  // 5 palm/s
        #expect(f.x - 720 > (s.x - 720) * 3)
        var edge = PointerMapper(bounds: screen, cursor: CGPoint(x: 1430, y: 450))
        edge.track(.zero, at: 0)
        #expect(edge.update(CGPoint(x: 5, y: 0), at: 0.1).x <= 1439)
    }

    @Test func profileFromMeasurements() {
        let p = HandProfile.calibrated(open: 1.4, pinched: 0.1)
        #expect(p.pinchEnter > 0.1 && p.pinchEnter < p.pinchExit && p.pinchExit < 1.4)
    }

    @Test func oneEuroSmoothsNoise() {
        var f = OneEuroFilter(minCutoff: 1, beta: 0.8)
        var values: [Double] = []
        for i in 0..<60 { values.append(f.filter(i % 2 == 0 ? 0.52 : 0.48, at: Double(i) / 30)) }
        let tail = values.suffix(20)
        #expect(tail.max()! - tail.min()! < 0.02)
    }

    @Test func roiCoversSmallHandAndSkipsBigOnes() throws {
        let aspect = 16.0 / 9
        let h = hand(at: CGPoint(x: 1.2, y: 0.4), scale: 0.05, t: 0)
        let roi = try #require(HandPose.regionOfInterest(around: [h], imageAspect: aspect))
        for p in h.joints.values { #expect(roi.contains(CGPoint(x: 1 - p.x / aspect, y: p.y))) } // unmirrored
        #expect(HandPose.regionOfInterest(around: [hand(scale: 0.3, t: 0)], imageAspect: aspect) == nil)
        #expect(HandPose.regionOfInterest(around: [], imageAspect: aspect) == nil)
    }

    @Test func chiralityVoteIgnoresFlickers() {
        var vote = ChiralityVote()
        func frame(_ i: Int, right: HandPose.Chirality, left: HandPose.Chirality) -> [HandPose.Chirality] {
            var a = hand(t: Double(i) / 30), b = hand(at: CGPoint(x: 0.3, y: 0.5), t: Double(i) / 30)
            (a.chirality, b.chirality) = (right, left)
            return vote.apply([a, b]).map(\.chirality)
        }
        // Every fourth frame Vision swaps the labels.
        let labels = (0..<20).map { i in i % 4 == 3 ? frame(i, right: .left, left: .right) : frame(i, right: .right, left: .left) }
        #expect(labels.allSatisfy { $0 == [.right, .left] })
        // A consistent change still wins.
        let later = (20..<32).map { frame($0, right: .left, left: .left) }
        #expect(later.last == [.left, .left])
    }

    @Test func fatigueCountsContinuousUse() {
        var f = FatigueTimer()
        var used = 0.0
        // Active with a 5 s pause every minute: short pauses aren't a rest.
        for s in stride(from: 0.0, through: 1300, by: 1) { used = f.update(active: s.truncatingRemainder(dividingBy: 60) > 5, at: s) }
        #expect(used >= FatigueTimer.breakAfter)
        _ = f.update(active: false, at: 1310)
        #expect(f.update(active: false, at: 1316) == 0) // 16 s rest resets
        #expect(f.update(active: true, at: 1317) == 0)
    }

    @Test func rebaseAbsorbsSourceShift() {
        var r = recognizer()
        _ = run(&r, from: 0, frames: 12, pose: { hand(t: $0) })
        let before = r.mapper.cursor
        r.rebase()
        _ = r.update(hand(at: CGPoint(x: 0.905, y: 0.5), t: 0.4), at: 0.4) // 0.05 palm jump from a crop switch
        #expect(r.mapper.cursor == before)
        _ = r.update(hand(at: CGPoint(x: 0.91, y: 0.5), t: 0.433), at: 0.433)
        #expect(r.mapper.cursor != before) // real motion still moves
    }
}
