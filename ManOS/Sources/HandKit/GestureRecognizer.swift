import CoreGraphics
import Foundation

public enum ScrollPhase: Sendable, Equatable { case began, changed, ended }

/// What the recognizer asks the system to do. Points are global display
/// coordinates (origin top-left).
public enum GestureEvent: Sendable, Equatable {
    case move(CGPoint)
    case down(CGPoint, clicks: Int)
    case drag(CGPoint)
    case up(CGPoint, clicks: Int)
    case rightClick(CGPoint)
    case scroll(dx: Double, dy: Double, phase: ScrollPhase)
    case paused(Bool)
}

/// Turns a stream of hand poses into pointer events.
///
/// Gestures: move the palm to point; thumb–index pinch to click, hold and move
/// to drag; thumb–middle pinch to right-click, hold and move to scroll; fist to
/// clutch (reposition the hand without moving the cursor); hold an open palm
/// still for 1 s to pause or resume.
///
/// Guards against accidental input ("Midas touch"):
/// - nothing happens until a hand has been steady in view for 250 ms;
/// - pinches need two consecutive frames and use enter/exit hysteresis;
/// - the click lands where the cursor was ~100 ms before the pinch, undoing
///   the small hand motion that pinching causes;
/// - a held pinch only becomes a drag after moving past a slop distance;
/// - losing the hand for 200 ms releases any held button.
public struct GestureRecognizer: Sendable {
    public enum State: Sendable, Equatable {
        case idle, engaging, hovering, pressing, dragging, rightPending, scrolling, clutched
    }

    public private(set) var state = State.idle
    public private(set) var isPaused = false
    public var profile: HandProfile { didSet { mapper.sensitivity = profile.sensitivity } }
    public var mapper: PointerMapper
    public var doubleClickInterval: TimeInterval = 0.5

    static let engageDwell = 0.25
    static let lostTimeout = 0.2
    static let rightClickMaxDuration = 0.3
    static let pauseHold = 1.0
    static let clickBackdate = 0.1
    static let maxHold = 15.0
    /// Palm widths of movement before a held pinch becomes a drag or scroll.
    static let slop = 0.12
    static let doubleClickRadius = 6.0

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

    /// 0 = fingers apart, 1 = at the click threshold. Drives the on-screen pinch ring.
    public private(set) var pinchProgress = 0.0

    public init(profile: HandProfile = HandProfile(), mapper: PointerMapper) {
        self.profile = profile
        self.mapper = mapper
        self.mapper.sensitivity = profile.sensitivity
    }

    public var isButtonDown: Bool { state == .pressing || state == .dragging }

    /// Call when the physical mouse moved the cursor, so hand control resumes from there.
    public mutating func setCursor(_ point: CGPoint) {
        mapper.cursor = point
        history.removeAll()
    }

    /// Ends any press or scroll and disengages. Use for kill switches and shutdown.
    public mutating func releaseAll() -> [GestureEvent] {
        let events = releaseEvents()
        state = .idle
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
        }
        // Palm units against a slowly adapting reference: robust to leaning in or out.
        referenceScale += (pose.scale - referenceScale) * 0.02
        let raw = pose.anchor
        let anchor = filter.filter(CGPoint(x: raw.x / referenceScale, y: raw.y / referenceScale), at: t)
        let speed = lastAnchor.map { anchor.distance(to: $0) } ?? 0
        lastAnchor = anchor

        let dIndex = pose.indexPinch, dMiddle = pose.middlePinch
        indexFrames = dIndex < profile.pinchEnter ? indexFrames + 1 : 0
        middleFrames = dMiddle < profile.pinchEnter && dIndex > profile.pinchExit ? middleFrames + 1 : 0
        let far = profile.pinchExit + 0.4
        pinchProgress = min(max((far - dIndex) / (far - profile.pinchEnter), 0), 1)

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
            if t - stateSince >= Self.engageDwell { state = .hovering }

        case .hovering:
            if pose.isFist {
                state = .clutched
            } else if indexFrames >= 2 {
                let point = backdatedCursor(at: t - Self.clickBackdate)
                mapper.cursor = point
                clicks = lastUp.map { t - $0.0 <= doubleClickInterval && point.distance(to: $0.1) <= Self.doubleClickRadius }
                    == true ? clicks + 1 : 1
                events.append(.down(point, clicks: clicks))
                state = .pressing
                stateSince = t
                pressAnchor = anchor
            } else if middleFrames >= 2 {
                state = .rightPending
                stateSince = t
                pressAnchor = anchor
            } else {
                let before = mapper.cursor
                let point = mapper.update(anchor, at: t)
                history.append((t, point))
                if history.count > 10 { history.removeFirst() }
                if point != before { events.append(.move(point)) }
            }

        case .pressing, .dragging:
            if dIndex > profile.pinchExit || t - stateSince > Self.maxHold {
                events.append(.up(mapper.cursor, clicks: clicks))
                lastUp = (t, mapper.cursor)
                state = .hovering
                mapper.track(anchor, at: t)
            } else if state == .pressing {
                if anchor.distance(to: pressAnchor) > Self.slop {
                    // Start from the press point so the slop distance isn't lost.
                    mapper.track(pressAnchor, at: t)
                    events.append(.drag(mapper.update(anchor, at: t)))
                    state = .dragging
                } else {
                    mapper.track(anchor, at: t) // absorb tremor while held
                }
            } else {
                events.append(.drag(mapper.update(anchor, at: t)))
            }

        case .rightPending:
            if dMiddle > profile.pinchExit {
                if t - stateSince <= Self.rightClickMaxDuration { events.append(.rightClick(mapper.cursor)) }
                state = .hovering
                mapper.track(anchor, at: t)
            } else if anchor.distance(to: pressAnchor) > Self.slop {
                state = .scrolling
                scrollLast = pressAnchor
                events.append(.scroll(dx: 0, dy: 0, phase: .began))
                events.append(scrollEvent(to: anchor))
            }

        case .scrolling:
            if dMiddle > profile.pinchExit {
                events.append(.scroll(dx: 0, dy: 0, phase: .ended))
                state = .hovering
                mapper.track(anchor, at: t)
            } else {
                events.append(scrollEvent(to: anchor))
            }

        case .clutched:
            mapper.track(anchor, at: t)
            if !pose.isFist { state = .hovering }
        }
        return events
    }

    private mutating func scrollEvent(to anchor: CGPoint) -> GestureEvent {
        let sign = profile.invertScroll ? -1.0 : 1.0
        let dx = Double(anchor.x - scrollLast.x), dy = Double(anchor.y - scrollLast.y)
        scrollLast = anchor
        return .scroll(dx: dx * profile.scrollSpeed * sign, dy: dy * profile.scrollSpeed * sign, phase: .changed)
    }

    private mutating func checkPauseToggle(_ pose: HandPose, stillness: Double, at t: TimeInterval) -> [GestureEvent] {
        guard pose.isOpenPalm else {
            palmSince = nil
            palmLatched = false
            return []
        }
        // `stillness` is palm widths moved this frame; ~0.5 palm/s at 30 fps.
        guard stillness < 0.017 else {
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
        case .pressing, .dragging: [.up(mapper.cursor, clicks: clicks)]
        case .scrolling: [.scroll(dx: 0, dy: 0, phase: .ended)]
        default: []
        }
    }
}
