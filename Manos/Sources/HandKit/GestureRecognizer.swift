import CoreGraphics
import Foundation

public enum ScrollPhase: Sendable, Equatable { case began, changed, ended }

/// Direction the hand flicked. Up means "next", like swiping up on a phone.
public enum FlickDirection: Sendable, Equatable { case up, down }

/// What the recognizer asks the system to do. Points are global display
/// coordinates (origin top-left).
public enum GestureEvent: Sendable, Equatable {
    case move(CGPoint)
    case down(CGPoint, clicks: Int)
    case drag(CGPoint)
    case up(CGPoint, clicks: Int)
    case rightClick(CGPoint)
    case scroll(dx: Double, dy: Double, phase: ScrollPhase)
    case flick(FlickDirection)
    case paused(Bool)
}

/// Turns a stream of hand poses into pointer events.
///
/// Gestures: move the palm to point; thumb–index pinch to click, hold and move
/// to drag; thumb–middle pinch to right-click, hold and move to scroll; fist to
/// clutch (reposition the hand without moving the cursor); curl middle, ring and
/// little fingers to anchor the pointer, then pinch thumb + index to click there; hold an open palm
/// still for 1.5 s to pause or resume; hold two fingers up (V) and flick up/down for next/previous.
///
/// Guards against accidental input ("Midas touch"):
/// - nothing happens until a hand has been steady in view for 250 ms;
/// - pinches need two consecutive frames and use enter/exit hysteresis;
/// - a click needs the fingers to have opened since the last one, so a hand that
///   arrives already pinched (holding a pen or a mug) or a pinch held past
///   `maxHold` never clicks by itself;
/// - while the fingers close, the pointer slows to a quarter speed, and the
///   click lands where the cursor was when closing began (50–250 ms earlier),
///   undoing the hand motion that pinching causes (it causes ~30% of mid-air
///   pointing errors; Wolf et al., CHI 2020);
/// - a held pinch only becomes a drag after moving past a slop distance;
/// - losing the hand for 200 ms releases any held button;
/// - positions are measured from the image centre in palm units, so leaning
///   toward or away from the camera doesn't move the cursor.
public struct GestureRecognizer: Sendable {
    public enum State: Sendable, Equatable {
        case idle, engaging, hovering, pressing, dragging, rightPending, scrolling, clutched
        /// Pinch-click while anchored: the pointer can't move.
        case anchoredPressing
    }

    public private(set) var state = State.idle
    public private(set) var isPaused = false
    public var profile: HandProfile { didSet { mapper.sensitivity = profile.sensitivity } }
    public var mapper: PointerMapper
    public var doubleClickInterval: TimeInterval = 0.5

    static let engageDwell = 0.25
    static let lostTimeout = 0.2
    static let rightClickMaxDuration = 0.3
    /// Long enough that a relaxed open hand resting still doesn't pause by accident.
    static let pauseHold = 1.5
    /// Bounds for rewinding a click to the start of the pinch motion.
    static let rewindRange = 0.05...0.25
    /// Pointer gain while fingers are closing toward a pinch.
    static let closingDamping = 0.25
    static let maxHold = 15.0
    /// No frames at all for this long with a button down (camera unplugged,
    /// taken over or stalled): the host should `releaseAll()`.
    public static let stallTimeout = 0.5

    /// Whether a held button or an open scroll should be released because frames stopped arriving.
    public func isStalled(lastFrame: TimeInterval, now: TimeInterval) -> Bool {
        (isButtonDown || state == .scrolling) && now - lastFrame > Self.stallTimeout
    }
    /// Palm widths of movement before a held pinch becomes a drag or scroll.
    static let slop = 0.12
    /// Time constant for following the palm's size (distance to the camera).
    static let scaleSmoothing = 0.2
    /// Speed below which an open palm counts as still, palm widths/s.
    static let stillSpeed = 0.5
    /// A pinch is closing when the thumb–index gap shrank by this much (palm
    /// units) within `closingWindow`; a slow drift toward the threshold isn't one.
    static let closingDrop = 0.15
    static let closingWindow = 0.15
    /// Scroll travel (palm widths) after which a mostly one-axis stroke locks to that axis.
    static let scrollAxisDecision = 0.25
    static let doubleClickRadius = 6.0
    /// A flick must happen within this window. It is also how long the V pose
    /// stays armed after it was last seen, which rides through frames that
    /// motion blur makes Vision misread or drop.
    static let flickWindow = 0.3
    /// Peak fingertip speed a flick must reach, palm widths/s. Real flicks peak
    /// well above 7; a steady drag covering `flickDistance` in 0.3 s is ~3.5.
    static let flickSpeed = 5.0
    /// Repeated flicks in the same direction (skimming several videos).
    static let flickRepeatDelay = 0.4
    /// The hand's return after a flick is also fast; ignore the opposite
    /// direction for a while so it doesn't undo the flick.
    static let flickReverseDelay = 0.9
    /// Cursor stays put while the hand settles after a flick.
    static let flickFreeze = 0.4

    private var stateSince: TimeInterval = 0
    private var lastSeen: TimeInterval?
    private var filter = OneEuroFilter2D(minCutoff: 1.0, beta: 0.8)
    private var referenceScale = 0.1
    private var indexFrames = 0
    private var middleFrames = 0
    private var pressAnchor = CGPoint.zero
    private var scrollLast = CGPoint.zero
    private var lastAnchor: CGPoint?
    private var history: [(TimeInterval, CGPoint)] = []
    private var clicks = 0
    private var lastUp: (TimeInterval, CGPoint)?
    private var palmSince: TimeInterval?
    private var palmLatched = false
    /// When the thumb and index started closing in on a pinch.
    private var closingSince: TimeInterval?
    /// Recent fingertip positions (palm units) while flicks are armed.
    private var flickSamples: [(TimeInterval, CGPoint)] = []
    private var lastFlick: (time: TimeInterval, direction: FlickDirection)?
    /// Last three raw fingertip points; their median drops single-frame landmark glitches.
    private var flickRecent: [CGPoint] = []
    private var vSignFrames = 0
    private var vSignLast = -TimeInterval.infinity
    private var freezeUntil: TimeInterval = 0
    /// Set once the hand is in the anchor grip with fingers apart, so a fist that
    /// closes with thumb on index doesn't click.
    private var anchorArmed = false
    private var rebasing = false
    /// Fingers opened since the last press, or since the hand appeared.
    private var pinchArmed = false
    private var middleArmed = false
    /// When hovering last began; a click never rewinds to before it.
    private var hoverSince: TimeInterval = 0
    private var lastFrameTime: TimeInterval?
    private var scaleTime: TimeInterval?
    /// Recent thumb–index gaps, for spotting a pinch as it closes.
    private var aperture: [(TimeInterval, Double)] = []
    private var closingMin = 0.0
    private var closingMinTime: TimeInterval = 0
    private enum ScrollAxis { case free, vertical, horizontal }
    private var scrollAxis = ScrollAxis.free
    private var scrollTravel = (x: 0.0, y: 0.0)

    /// Camera image width / height (pose x runs from 0 to this). Positions are
    /// measured from the image centre: leaning in scales the image about it, so
    /// positions in palm units from there stay put. Set it from the camera.
    public var imageAspect = 16.0 / 9 {
        didSet { if imageAspect != oldValue { rebasing = true } }
    }

    /// 0 = fingers apart, 1 = at the click threshold. Drives the on-screen pinch ring.
    public private(set) var pinchProgress = 0.0
    /// Two fingers are up: the pointer holds still and a vertical flick pages.
    public private(set) var isFlickReady = false

    public init(profile: HandProfile = HandProfile(), mapper: PointerMapper) {
        self.profile = profile
        self.mapper = mapper
        self.mapper.sensitivity = profile.sensitivity
    }

    public var isButtonDown: Bool { state == .pressing || state == .dragging || state == .anchoredPressing }

    /// Call when the physical mouse moved the cursor, so hand control resumes from there.
    public mutating func setCursor(_ point: CGPoint) {
        mapper.cursor = point
        history.removeAll()
    }

    /// Resume after a pause (e.g. from the hotkey), without a palm gesture.
    public mutating func resume() {
        isPaused = false
        palmSince = nil
    }

    /// The pose source changed (Vision switched between a crop and the full
    /// frame), so landmarks may shift a little: re-reference on the next frame
    /// instead of moving the cursor by the shift.
    public mutating func rebase() { rebasing = true }

    /// Ends any press or scroll and disengages. Use for kill switches and shutdown.
    public mutating func releaseAll() -> [GestureEvent] {
        let events = releaseEvents()
        state = .idle
        isFlickReady = false
        return events
    }

    public mutating func update(_ pose: HandPose?, at t: TimeInterval) -> [GestureEvent] {
        guard let pose else {
            if let lastSeen, t - lastSeen > Self.lostTimeout, state != .idle {
                return releaseAll()
            }
            return []
        }
        lastSeen = t

        if state == .idle {
            state = .engaging
            stateSince = t
            referenceScale = pose.scale
            filter.reset()
            lastAnchor = nil
            lastFrameTime = nil
            scaleTime = nil
            // A hand that shows up already pinched must open before it can click.
            pinchArmed = false
            middleArmed = false
            aperture.removeAll()
            closingSince = nil
        }
        // Follow the palm's size with a short time constant (frame-rate independent).
        // A rebase (new hand or pose source) starts from this frame's size.
        let follow = rebasing ? 1 : scaleTime.map { 1 - exp(-max(t - $0, 0) / Self.scaleSmoothing) } ?? 1
        scaleTime = t
        referenceScale += (pose.scale - referenceScale) * follow
        // Palm units from the image centre: leaning in scales the image about the
        // centre, so these coordinates don't change when only the distance does.
        let center = CGPoint(x: imageAspect / 2, y: 0.5), scale = referenceScale
        func palmUnits(_ p: CGPoint) -> CGPoint { CGPoint(x: (p.x - center.x) / scale, y: (p.y - center.y) / scale) }
        if rebasing { filter.reset() }
        let anchor = filter.filter(palmUnits(pose.anchor), at: t)
        if rebasing {
            rebasing = false
            mapper.track(anchor, at: t)
            (lastAnchor, pressAnchor, scrollLast) = (anchor, anchor, anchor)
        }
        // Unfiltered fingertips: the filter would blunt exactly the fast motion a flick is.
        let flickPoint = palmUnits(pose.fingertipCenter)
        let dt = lastFrameTime.map { max(t - $0, 1e-3) } ?? 1.0 / 30
        lastFrameTime = t
        let speed = lastAnchor.map { anchor.distance(to: $0) / dt } ?? 0 // palm widths / s
        lastAnchor = anchor

        let dIndex = pose.indexPinch, dMiddle = pose.middlePinch
        let enter = profile.pinchEnter, exit = profile.releaseThreshold
        indexFrames = dIndex < enter ? indexFrames + 1 : 0
        middleFrames = dMiddle < enter && dIndex > exit ? middleFrames + 1 : 0
        if dIndex > exit { pinchArmed = true }
        if dMiddle > exit { middleArmed = true }
        let far = exit + 0.4
        pinchProgress = min(max((far - dIndex) / (far - enter), 0), 1)
        trackClosing(dIndex, at: t, enter: enter, exit: exit)
        mapper.damping = closingSince != nil && state == .hovering ? Self.closingDamping : 1

        // Flicks need the V pose (pointing never makes it), held for two frames.
        if pose.isVSign, dIndex > exit, dMiddle > exit {
            if t - vSignLast > Self.flickWindow { vSignFrames = 0 }
            vSignFrames += 1
            vSignLast = t
        }
        isFlickReady = profile.flickEnabled && !isPaused && state == .hovering
            && vSignFrames >= 2 && t - vSignLast <= Self.flickWindow
        if !isFlickReady {
            flickSamples.removeAll()
            flickRecent.removeAll()
        }

        var events: [GestureEvent] = []
        if state == .hovering || isPaused {
            events += checkPauseToggle(pose, stillness: speed, at: t)
        }
        if isPaused {
            mapper.track(anchor, at: t)
            return events
        }

        switch state {
        case .idle, .engaging:
            mapper.track(anchor, at: t)
            if t - stateSince >= Self.engageDwell { beginHover(at: t) }

        case .hovering:
            if isFlickReady {
                // The pointer holds still in the V pose, so a flick can't move it.
                mapper.track(anchor, at: t)
                if let direction = detectFlick(flickPoint, at: t) {
                    freezeUntil = t + Self.flickFreeze // the hand settles or drops the V
                    events.append(.flick(direction))
                }
            } else if pose.isFist || pose.isAnchorGrip {
                state = .clutched
                anchorArmed = false
                // A fist can close thumb on index: open again before the next click.
                pinchArmed = false
                middleArmed = false
            } else if indexFrames >= 2, pinchArmed {
                pinchArmed = false
                // Rewind to where closing began, but never to before this hover:
                // the cursor may have been somewhere else entirely then.
                let onset = max(closingSince ?? t - 0.1, hoverSince)
                let rewind = min(max(t - onset, Self.rewindRange.lowerBound), Self.rewindRange.upperBound)
                let point = backdatedCursor(at: max(t - rewind, hoverSince))
                mapper.cursor = point
                clicks = nextClickCount(at: point, time: t)
                events.append(.down(point, clicks: clicks))
                state = .pressing
                stateSince = t
                pressAnchor = anchor
            } else if middleFrames >= 2, middleArmed {
                middleArmed = false
                state = .rightPending
                stateSince = t
                pressAnchor = anchor
            } else if t < freezeUntil {
                mapper.track(anchor, at: t)
            } else {
                let before = mapper.cursor
                let point = mapper.update(anchor, at: t)
                history.append((t, point))
                if history.count > 20 { history.removeFirst() }
                if point != before { events.append(.move(point)) }
            }

        case .pressing, .dragging:
            if dIndex > exit || t - stateSince > Self.maxHold {
                events.append(.up(mapper.cursor, clicks: clicks))
                lastUp = (t, mapper.cursor)
                beginHover(at: t)
                mapper.track(anchor, at: t)
            } else if state == .pressing {
                if anchor.distance(to: pressAnchor) > Self.slop {
                    // Start from the press point so the slop distance isn't lost. Its
                    // time is the press time, so the first drag's speed (and gain) is real.
                    mapper.track(pressAnchor, at: stateSince)
                    events.append(.drag(mapper.update(anchor, at: t)))
                    state = .dragging
                } else {
                    mapper.track(anchor, at: t) // absorb tremor while held
                }
            } else {
                events.append(.drag(mapper.update(anchor, at: t)))
            }

        case .rightPending:
            if dMiddle > exit {
                if t - stateSince <= Self.rightClickMaxDuration { events.append(.rightClick(mapper.cursor)) }
                beginHover(at: t)
                mapper.track(anchor, at: t)
            } else if anchor.distance(to: pressAnchor) > Self.slop {
                state = .scrolling
                scrollLast = pressAnchor
                scrollAxis = .free
                scrollTravel = (0, 0)
                events.append(.scroll(dx: 0, dy: 0, phase: .began))
                events.append(scrollEvent(to: anchor))
            }

        case .scrolling:
            if dMiddle > exit {
                events.append(.scroll(dx: 0, dy: 0, phase: .ended))
                beginHover(at: t)
                mapper.track(anchor, at: t)
            } else {
                events.append(scrollEvent(to: anchor))
            }

        case .clutched:
            mapper.track(anchor, at: t)
            if pose.isAnchorGrip, dIndex > exit { anchorArmed = true }
            if anchorArmed, indexFrames >= 2 {
                clicks = nextClickCount(at: mapper.cursor, time: t)
                events.append(.down(mapper.cursor, clicks: clicks))
                state = .anchoredPressing
                stateSince = t
                anchorArmed = false
            } else if !pose.isFist, !pose.isAnchorGrip {
                beginHover(at: t)
            }

        case .anchoredPressing:
            mapper.track(anchor, at: t)
            if dIndex > exit || t - stateSince > Self.maxHold {
                events.append(.up(mapper.cursor, clicks: clicks))
                lastUp = (t, mapper.cursor)
                state = .clutched
            }
        }
        return events
    }

    private func nextClickCount(at point: CGPoint, time t: TimeInterval) -> Int {
        lastUp.map { t - $0.0 <= doubleClickInterval && point.distance(to: $0.1) <= Self.doubleClickRadius } == true ? clicks + 1 : 1
    }

    /// A fast, mostly vertical fingertip stroke: at least `flickDistance` of
    /// travel within `flickWindow`, reaching `flickSpeed`. Positions are a
    /// median of three frames, so one frame of misplaced landmarks can't fire
    /// it. Frames where the hand was lost (motion blur) just leave a gap; the
    /// stroke is measured across it.
    private mutating func detectFlick(_ raw: CGPoint, at t: TimeInterval) -> FlickDirection? {
        flickRecent = Array((flickRecent + [raw]).suffix(3))
        guard flickRecent.count == 3 else { return nil }
        let p = CGPoint(x: flickRecent.map(\.x).sorted()[1], y: flickRecent.map(\.y).sorted()[1])
        flickSamples.append((t, p))
        flickSamples.removeAll { t - $0.0 > Self.flickWindow }
        // Measure from the window's far end, so the start of the stroke is never cut off.
        let ys = flickSamples.map(\.1.y)
        guard let lo = ys.indices.min(by: { ys[$0] < ys[$1] }), let hi = ys.indices.max(by: { ys[$0] < ys[$1] }) else { return nil }
        let start = p.y - ys[lo] >= ys[hi] - p.y ? lo : hi
        let dy = Double(p.y - ys[start]), dx = Double(p.x - flickSamples[start].1.x)
        let stroke = flickSamples[start...]
        let peak = zip(stroke, stroke.dropFirst()).map { a, b in abs(Double(b.1.y - a.1.y)) / max(b.0 - a.0, 1e-3) }.max() ?? 0
        guard abs(dy) >= profile.flickDistance, abs(dy) > 1.5 * abs(dx), peak >= Self.flickSpeed else { return nil }
        let direction: FlickDirection = dy > 0 ? .up : .down
        if let last = lastFlick {
            if last.direction != direction, t - last.time < Self.flickReverseDelay {
                // The hand coming back: discard it, so it can't fire once the delay ends.
                flickSamples = [(t, p)]
                return nil
            }
            if t - last.time < Self.flickRepeatDelay { return nil }
        }
        lastFlick = (t, direction)
        flickSamples = [(t, p)]
        return direction
    }

    private mutating func scrollEvent(to anchor: CGPoint) -> GestureEvent {
        let sign = profile.invertScroll ? -1.0 : 1.0
        var dx = Double(anchor.x - scrollLast.x), dy = Double(anchor.y - scrollLast.y)
        scrollLast = anchor
        // A hand moving "straight down" drifts sideways too. Like a trackpad, lock a
        // stroke that is clearly one-axis to that axis; diagonal strokes stay free.
        scrollTravel.x += abs(dx)
        scrollTravel.y += abs(dy)
        if scrollAxis == .free, scrollTravel.x + scrollTravel.y >= Self.scrollAxisDecision {
            if scrollTravel.y >= 2 * scrollTravel.x { scrollAxis = .vertical } else if scrollTravel.x >= 2 * scrollTravel.y { scrollAxis = .horizontal }
        }
        if scrollAxis == .vertical { dx = 0 } else if scrollAxis == .horizontal { dy = 0 }
        return .scroll(dx: dx * profile.scrollSpeed * sign, dy: dy * profile.scrollSpeed * sign, phase: .changed)
    }

    /// Starts hovering. The cursor history restarts here, so a click right after a
    /// drag (or a clutch) can't rewind to where the cursor was before it.
    private mutating func beginHover(at t: TimeInterval) {
        state = .hovering
        hoverSince = t
        history = [(t, mapper.cursor)]
    }

    /// Closing = the gap shrank by `closingDrop` within `closingWindow` while near
    /// the threshold. It ends when the fingers open again, or stop closing without
    /// pinching. A fixed distance zone instead would keep damping a hand whose
    /// relaxed gap happens to sit near the threshold, and mistime the rewind.
    private mutating func trackClosing(_ d: Double, at t: TimeInterval, enter: Double, exit: Double) {
        aperture.append((t, d))
        aperture.removeAll { t - $0.0 > 0.4 }
        if closingSince == nil {
            let peak = aperture.filter { t - $0.0 <= Self.closingWindow }.max { $0.1 < $1.1 }
            if let peak, peak.1 - d >= Self.closingDrop, d < exit + 0.3 {
                closingSince = peak.0
                closingMin = d
                closingMinTime = t
            }
        } else if d < closingMin {
            closingMin = d
            closingMinTime = t
        } else if d > closingMin + 0.1 || (t - closingMinTime > 0.2 && d > enter) {
            closingSince = nil
        }
    }

    private mutating func checkPauseToggle(_ pose: HandPose, stillness: Double, at t: TimeInterval) -> [GestureEvent] {
        guard pose.isOpenPalm else {
            palmSince = nil
            palmLatched = false
            return []
        }
        // `stillness` is the palm's speed in palm widths per second.
        guard stillness < Self.stillSpeed else {
            palmSince = nil
            return []
        }
        let since = palmSince ?? t
        palmSince = since
        guard !palmLatched, t - since >= Self.pauseHold else { return [] }
        palmLatched = true // one toggle per palm hold
        isPaused.toggle()
        return [.paused(isPaused)]
    }

    private func backdatedCursor(at time: TimeInterval) -> CGPoint {
        history.last(where: { $0.0 <= time })?.1 ?? history.first?.1 ?? mapper.cursor
    }

    private func releaseEvents() -> [GestureEvent] {
        switch state {
        case .pressing, .dragging, .anchoredPressing: [.up(mapper.cursor, clicks: clicks)]
        case .scrolling: [.scroll(dx: 0, dy: 0, phase: .ended)]
        default: []
        }
    }
}
