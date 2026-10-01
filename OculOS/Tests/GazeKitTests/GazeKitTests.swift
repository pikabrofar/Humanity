import CoreGraphics
import Testing
@testable import GazeKit

@Suite struct CalibrationTests {
    static let geometry = ScreenGeometry(widthMM: 300, heightMM: 195, imageAspect: 16 / 9)

    /// Ground-truth physical setup used to synthesize features.
    struct World {
        var cameraX = 0.52, gap = 8.0, scale = 1.1
        /// Vision's yaw sign is opposite to the model's convention; the fit must learn that.
        var yawSign = -1.0
        var pupilNoise = 0.002
        enum Appearance { case none, informative, noise }
        var appearance = Appearance.none
        /// Simulated CNN: accurate gaze angles, but swapped and sign-flipped vs. the model's axes.
        var network = false

        struct Head { var x = 0.0, y = -60.0, z = 600.0, yaw = 0.0, pitch = 0.0 }

        func features(looking target: CGPoint, head: Head, noise: Double? = nil, rng: inout SeededRandom) -> GazeFeatures {
            let noise = noise ?? pupilNoise
            let focal = 0.5 / tan(geometry.cameraFOV / 2)
            let faceSize = scale * focal * GazeCalibration.faceWidthMM / head.z
            let center = CGPoint(x: 0.5 + head.x * focal / head.z, y: 0.5 + head.y * geometry.imageAspect * focal / head.z)
            let point = SIMD3(-(Double(target.x) - cameraX) * geometry.widthMM, -(gap + Double(target.y) * geometry.heightMM), 0)
            let d = point - SIMD3(head.x, head.y, head.z)
            let theta = atan2(-d.x, -d.z), phi = atan2(d.y, (d.x * d.x + d.z * d.z).squareRoot())
            // Eye-in-head rotation is what the pupil sees; the head supplies the rest.
            let te = theta - head.yaw, pe = phi - head.pitch
            let eye = EyeFeatures(
                pupil: CGPoint(x: 0.5 - 0.3 * te + 0.05 * te * te + rng.gaussian() * noise, y: 0.15 * pe + rng.gaussian() * noise),
                openness: 0.28 + 0.08 * pe
            )
            var patch: [Float] = []
            if appearance != .none {
                patch = (0..<120).map { _ in Float(rng.next()) }
                if appearance == .informative {
                    // Two "pixels" that track eye rotation cleanly, like the iris edge would.
                    patch[0] = Float(0.5 + te + rng.gaussian() * 0.002)
                    patch[1] = Float(0.5 + pe + rng.gaussian() * 0.002)
                }
            }
            return GazeFeatures(
                timestamp: 0, left: eye, right: eye,
                yaw: yawSign * head.yaw + rng.gaussian() * 0.005, pitch: head.pitch + rng.gaussian() * 0.005, roll: 0,
                faceCenter: center, faceSize: faceSize, isBlinking: false, appearance: patch,
                networkGaze: network ? CGPoint(x: -phi + rng.gaussian() * 0.01, y: theta + rng.gaussian() * 0.01) : nil
            )
        }
    }

    /// Nine still-head targets plus a head-motion phase on the center dot.
    static func calibrationSamples(_ world: World, rng: inout SeededRandom, glanceRate: Int = 0) -> [CalibrationSample] {
        var samples: [CalibrationSample] = []
        for gy in [0.08, 0.5, 0.92] {
            for gx in [0.08, 0.5, 0.92] {
                let target = CGPoint(x: gx, y: gy)
                for i in 0..<30 {
                    let lookedAt = glanceRate > 0 && i % glanceRate == 0 ? CGPoint(x: rng.next(), y: rng.next()) : target
                    let head = World.Head(x: rng.gaussian() * 3, y: -60 + rng.gaussian() * 3, z: 600 + rng.gaussian() * 5)
                    samples.append(CalibrationSample(features: world.features(looking: lookedAt, head: head, rng: &rng), target: target))
                }
            }
        }
        for _ in 0..<150 {
            let head = World.Head(x: (rng.next() - 0.5) * 160, y: -60 + (rng.next() - 0.5) * 80, z: 500 + rng.next() * 200,
                                  yaw: (rng.next() - 0.5) * 0.5, pitch: (rng.next() - 0.5) * 0.3)
            let center = CGPoint(x: 0.5, y: 0.5)
            samples.append(CalibrationSample(features: world.features(looking: center, head: head, rng: &rng), target: center))
        }
        return samples
    }

    @Test func recoversLayoutAndGeneralizesToNewTargets() throws {
        var rng = SeededRandom(seed: 42)
        let world = World()
        let model = try GazeCalibration.fit(samples: Self.calibrationSamples(world, rng: &rng), geometry: Self.geometry)
        #expect(model.report.rmsError < 0.03) // noise floor: 0.002 pupil noise ≈ 0.02
        #expect(abs(model.cameraPosition - world.cameraX) < 0.03)

        for target in [CGPoint(x: 0.3, y: 0.7), CGPoint(x: 0.75, y: 0.25)] {
            let f = world.features(looking: target, head: .init(), noise: 0, rng: &rng)
            #expect(model.predict(f).distance(to: target) < 0.03)
        }
    }

    /// The point of the geometric model: head movement after calibration.
    @Test func compensatesHeadMovement() throws {
        var rng = SeededRandom(seed: 3)
        let world = World()
        let model = try GazeCalibration.fit(samples: Self.calibrationSamples(world, rng: &rng), geometry: Self.geometry)

        let moved: [World.Head] = [
            .init(x: 90, y: -40, z: 520, yaw: 0.15, pitch: 0.05),
            .init(x: -70, y: -90, z: 700, yaw: -0.2, pitch: -0.1),
        ]
        for head in moved {
            for target in [CGPoint(x: 0.2, y: 0.2), CGPoint(x: 0.8, y: 0.6), CGPoint(x: 0.5, y: 0.9)] {
                let f = world.features(looking: target, head: head, noise: 0, rng: &rng)
                #expect(model.predict(f).distance(to: target) < 0.05, "head \(head) target \(target)")
            }
        }
        let z = model.headPosition(world.features(looking: CGPoint(x: 0.5, y: 0.5), head: .init(), noise: 0, rng: &rng)).z
        #expect(abs(z - 600) < 60)
    }

    static func validationSamples(_ world: World, rng: inout SeededRandom) -> [CalibrationSample] {
        [CGPoint(x: 0.25, y: 0.25), CGPoint(x: 0.75, y: 0.3), CGPoint(x: 0.5, y: 0.6), CGPoint(x: 0.3, y: 0.8)].flatMap { target in
            (0..<25).map { _ in CalibrationSample(features: world.features(looking: target, head: .init(), rng: &rng), target: target) }
        }
    }

    /// Pursuit-style data: hundreds of unique targets along a path.
    static func pursuitSamples(_ world: World, rng: inout SeededRandom) -> [CalibrationSample] {
        (0..<400).map { i in
            let t = Double(i) / 400 * 2 * .pi
            let target = CGPoint(x: 0.5 + 0.42 * sin(2 * t), y: 0.5 + 0.4 * sin(3 * t + .pi / 2))
            return CalibrationSample(features: world.features(looking: target, head: .init(), rng: &rng), target: target)
        }
    }

    @Test func validationReportsDegrees() throws {
        var rng = SeededRandom(seed: 11)
        let world = World()
        let model = try GazeCalibration.fit(samples: Self.calibrationSamples(world, rng: &rng), geometry: Self.geometry)
        let result = model.validate(Self.validationSamples(world, rng: &rng))
        #expect(result.points.count == 4)
        #expect(result.accuracyDegrees < 1.5)
        #expect(result.precisionDegrees > 0 && result.precisionDegrees < 3)
    }

    @Test func appearanceCorrectionKeptOnlyWhenItHelps() throws {
        var rng = SeededRandom(seed: 5)
        var world = World()
        world.pupilNoise = 0.02 // landmark pupils bad…
        world.appearance = .informative // …but the eye patch is clean
        var training = Self.calibrationSamples(world, rng: &rng) + Self.pursuitSamples(world, rng: &rng)
        var validation = Self.validationSamples(world, rng: &rng)
        let helped = try GazeCalibration.fit(samples: training, geometry: Self.geometry, validation: validation)
        #expect(helped.appearanceRidge != nil)

        let geometricOnly = try GazeCalibration.fit(samples: training, geometry: Self.geometry)
        #expect(helped.validate(validation).accuracyDegrees < geometricOnly.validate(validation).accuracyDegrees)

        world.appearance = .noise
        training = Self.calibrationSamples(world, rng: &rng) + Self.pursuitSamples(world, rng: &rng)
        validation = Self.validationSamples(world, rng: &rng)
        let noisy = try GazeCalibration.fit(samples: training, geometry: Self.geometry, validation: validation)
        let baseline = try GazeCalibration.fit(samples: training, geometry: Self.geometry)
        // Selection never makes held-out error worse than the geometric model alone.
        #expect(noisy.validate(validation).accuracyDegrees <= baseline.validate(validation).accuracyDegrees + 1e-9)
    }

    @Test func pursuitFilterDropsInattentiveWindows() {
        var rng = SeededRandom(seed: 2)
        let world = World()
        let followed = Self.pursuitSamples(world, rng: &rng)
        // Same targets, but the eyes wander elsewhere.
        let ignored = followed.map { s in
            CalibrationSample(features: world.features(looking: CGPoint(x: rng.next(), y: rng.next()), head: .init(), rng: &rng), target: s.target)
        }
        #expect(PursuitFilter.attended(followed).count > followed.count * 8 / 10)
        #expect(PursuitFilter.attended(ignored).count < ignored.count / 5)
    }

    @Test func usesNetworkGazeWhenAvailable() throws {
        var rng = SeededRandom(seed: 21)
        var world = World()
        world.pupilNoise = 0.02 // poor landmark pupils
        let without = try GazeCalibration.fit(samples: Self.calibrationSamples(world, rng: &rng), geometry: Self.geometry)
        let validationWithout = Self.validationSamples(world, rng: &rng)
        world.network = true
        let with = try GazeCalibration.fit(samples: Self.calibrationSamples(world, rng: &rng), geometry: Self.geometry)
        let validationWith = Self.validationSamples(world, rng: &rng)
        #expect(with.validate(validationWith).accuracyDegrees < without.validate(validationWithout).accuracyDegrees / 2)
    }

    @Test func rejectsTooFewSamples() {
        var rng = SeededRandom(seed: 9)
        let samples = (0..<5).map { _ in
            CalibrationSample(features: World().features(looking: .zero, head: .init(), noise: 0, rng: &rng), target: .zero)
        }
        #expect(throws: CalibrationError.self) { try GazeCalibration.fit(samples: samples, geometry: Self.geometry) }
    }

    @Test func survivesGlancesAway() throws {
        var rng = SeededRandom(seed: 7)
        let samples = Self.calibrationSamples(World(), rng: &rng, glanceRate: 10)
        let model = try GazeCalibration.fit(samples: samples, geometry: Self.geometry)
        #expect(model.report.rmsError < 0.03)
    }
}

@Suite struct HumanErrorTests {
    static func sample(_ t: Double, eye: CGPoint) -> CalibrationSample {
        let e = EyeFeatures(pupil: eye, openness: 0.3)
        return CalibrationSample(
            features: GazeFeatures(timestamp: t, left: e, right: e, yaw: 0, pitch: 0, roll: 0,
                                   faceCenter: CGPoint(x: 0.5, y: 0.5), faceSize: 0.3, isBlinking: false),
            target: CGPoint(x: 0.5, y: 0.5))
    }

    /// Undershoot, corrective saccade ("refocusing"), then the real fixation.
    @Test func selectsFixationAfterCorrectiveSaccade() {
        var rng = SeededRandom(seed: 4)
        var samples: [CalibrationSample] = []
        var t = 0.0
        func add(_ n: Int, _ x: Double) {
            for _ in 0..<n {
                samples.append(Self.sample(t, eye: CGPoint(x: x + rng.gaussian() * 0.002, y: 0.05 + rng.gaussian() * 0.002)))
                t += 1.0 / 30
            }
        }
        add(9, 0.40)  // 0.3 s undershoot
        add(1, 0.52)  // corrective saccade
        add(30, 0.60) // 1 s on target
        let chosen = FixationSelector.longestFixation(samples)
        #expect(chosen.count >= 28)
        #expect(chosen.allSatisfy { abs($0.features.eye.x - 0.6) < 0.02 })
    }

    @Test func noFixationWhenEyesWander() {
        var rng = SeededRandom(seed: 8)
        let samples = (0..<60).map { i in Self.sample(Double(i) / 30, eye: CGPoint(x: 0.3 + rng.next() * 0.4, y: rng.next() * 0.2)) }
        #expect(FixationSelector.longestFixation(samples).count < 12)
    }

    @Test func estimatesPursuitLag() {
        let path = { (t: Double) in CGPoint(x: 0.5 + 0.4 * sin(t), y: 0.5 + 0.4 * sin(1.5 * t)) }
        let lag = 0.12
        let features = (0..<300).map { i -> GazeFeatures in
            let t = Double(i) / 30
            let p = path(t - lag)
            return Self.sample(100 + t, eye: CGPoint(x: 0.5 - 0.3 * (p.x - 0.5), y: 0.1 * p.y)).features
        }
        #expect(abs(PursuitFilter.estimateLag(features, start: 100, path: path) - lag) < 0.02)
    }

    @Test func removesCatchUpSaccades() {
        var samples = (0..<30).map { i in Self.sample(Double(i) / 30, eye: CGPoint(x: 0.4 + Double(i) * 0.001, y: 0)) }
        samples[15] = Self.sample(15.0 / 30, eye: CGPoint(x: 0.6, y: 0))
        let kept = PursuitFilter.removeSaccades(samples)
        #expect(!kept.contains { abs($0.features.eye.x - 0.6) < 1e-9 })
        #expect(kept.count >= 27)
    }
}

@Suite struct MathTests {
    @Test func solvesLinearSystem() throws {
        let x = try #require(LinearAlgebra.solve([[2, 1, -1], [-3, -1, 2], [-2, 1, 2]], [8, -11, -3]))
        #expect(abs(x[0] - 2) < 1e-9 && abs(x[1] - 3) < 1e-9 && abs(x[2] + 1) < 1e-9)
    }

    @Test func detectsSingularSystem() {
        #expect(LinearAlgebra.solve([[1, 2], [2, 4]], [1, 2]) == nil)
    }

    @Test func stabilizerHoldsFixationsAndConfirmsSaccades() {
        var stabilizer = FixationStabilizer(radius: 60, confirmSamples: 4)
        var rng = SeededRandom(seed: 1)
        var t = 0.0
        func noisy(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x + rng.gaussian() * 15, y: y + rng.gaussian() * 15) }
        func update(_ p: CGPoint) -> CGPoint { t += 1.0 / 30; return stabilizer.update(p, at: t) }

        var outputs: [CGPoint] = []
        for _ in 0..<60 { outputs.append(update(noisy(500, 400))) }
        // Settled output jitters far less than the raw 15 pt noise.
        let settled = outputs.suffix(30).map { Double($0.x) }
        #expect(PursuitFilter.standardDeviation(settled) < 6)

        // One glitch is ignored.
        let held = update(CGPoint(x: 900, y: 100))
        #expect(held.distance(to: CGPoint(x: 500, y: 400)) < 15)

        // A real saccade is accepted after confirmSamples frames.
        var last = CGPoint.zero
        for _ in 0..<4 { last = update(noisy(1200, 700)) }
        #expect(last.distance(to: CGPoint(x: 1200, y: 700)) < 30)
    }

    @Test func stabilizerLooksOneSampleAhead() {
        var stabilizer = FixationStabilizer(radius: 60) // default: one-sample look-ahead
        var t = 0.0
        func update(_ x: Double, _ y: Double) -> CGPoint { t += 1.0 / 30; return stabilizer.update(CGPoint(x: x, y: y), at: t) }
        for _ in 0..<10 { _ = update(500, 400) }

        // An outlier is held for one frame, then dropped when gaze returns.
        #expect(update(900, 100) == CGPoint(x: 500, y: 400))
        #expect(update(500, 400) == CGPoint(x: 500, y: 400))
        // Two agreeing samples are a saccade: the cursor moves on the second.
        #expect(update(1200, 700) == CGPoint(x: 500, y: 400))
        #expect(update(1210, 700).distance(to: CGPoint(x: 1205, y: 700)) < 5)
    }

    @Test func stabilizerWindowFollowsDrift() {
        var stabilizer = FixationStabilizer(radius: 60)
        var t = 0.0, out = CGPoint.zero
        for _ in 0..<90 { t += 1.0 / 30; out = stabilizer.update(CGPoint(x: 500, y: 400), at: t) }
        // Gaze settles 40 pt away, inside the radius: only the last 450 ms count,
        // so after half a second the cursor has caught up (a whole-fixation mean
        // would still sit near 500).
        for _ in 0..<15 { t += 1.0 / 30; out = stabilizer.update(CGPoint(x: 540, y: 400), at: t) }
        #expect(out.x > 538)
    }

    @Test func dwellFiresOnceAndCancelsOnLeaving() {
        var dwell = Dwell(duration: 1, radius: 50)
        func fire(_ p: CGPoint?, at t: Double) -> Bool { dwell.update(p, at: t) }
        let p = CGPoint(x: 100, y: 100)
        #expect(!fire(p, at: 0))
        #expect(!fire(CGPoint(x: 130, y: 100), at: 0.5)) // small drift keeps the dwell
        #expect(abs(dwell.progress - 0.5) < 1e-9)
        #expect(fire(p, at: 1.0))
        #expect(!fire(p, at: 3.0)) // no repeat without a new fixation
        #expect(dwell.progress == 0)

        #expect(!fire(CGPoint(x: 300, y: 100), at: 3.1)) // leaving restarts
        #expect(!fire(CGPoint(x: 300, y: 100), at: 3.9))
        #expect(!fire(nil, at: 4.0)) // tracking lost cancels
        #expect(!fire(CGPoint(x: 300, y: 100), at: 4.5))
        #expect(fire(CGPoint(x: 300, y: 100), at: 5.5))
    }

    @Test func snapPicksNearestTargetWithinRadius() {
        let p = CGPoint(x: 500, y: 500)
        let near = CGRect(x: 540, y: 490, width: 40, height: 20) // 40 pt away
        let far = CGRect(x: 800, y: 490, width: 40, height: 20)
        let around = CGRect(x: 0, y: 0, width: 1000, height: 1000) // contains p
        #expect(GazeClick.nearest(to: p, in: [far, near], radius: 100) == CGPoint(x: 560, y: 500))
        #expect(GazeClick.nearest(to: p, in: [far], radius: 100) == nil)
        #expect(GazeClick.nearest(to: p, in: [near, around], radius: 100) == CGPoint(x: 500, y: 500))
        #expect(GazeClick.probes(around: p, radius: 200).count == 19)
        // 13" MacBook-class: ~1440 pt across 300 mm at 60 cm ≈ 50 pt per degree.
        let ppd = GazeClick.pointsPerDegree(widthPoints: 1440, widthMM: 300, distanceMM: 600)
        #expect(abs(ppd - 50.3) < 0.5)
    }

    @Test func detectsFixations() {
        var samples: [GazeSample] = []
        for i in 0..<30 { samples.append(GazeSample(t: Double(i) / 30, x: 100, y: 100)) }
        for i in 30..<60 { samples.append(GazeSample(t: Double(i) / 30, x: 500, y: 300)) }
        let fixations = FixationDetector(maxDispersion: 30, minDuration: 0.1).detect(samples)
        #expect(fixations.count == 2)
        #expect(fixations.first?.center == CGPoint(x: 100, y: 100))
    }

    @Test func eyeFeaturesAreRotationInvariant() {
        let contour = [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 2), CGPoint(x: 10, y: 0), CGPoint(x: 5, y: -2)]
        let pupil = CGPoint(x: 7, y: 0.5)
        let level = FaceFeatureExtractor.eyeFeatures(contour: contour, pupil: pupil, angle: 0)

        let angle = 0.3
        let rotate = { (p: CGPoint) in CGPoint(x: p.x * cos(angle) - p.y * sin(angle), y: p.x * sin(angle) + p.y * cos(angle)) }
        let tilted = FaceFeatureExtractor.eyeFeatures(contour: contour.map(rotate), pupil: rotate(pupil), angle: angle)

        #expect(abs(level.pupil.x - 0.7) < 1e-9)
        #expect(abs(tilted.pupil.x - level.pupil.x) < 1e-9)
        #expect(abs(tilted.pupil.y - level.pupil.y) < 1e-9)
    }

    @Test func heatmapRenders() throws {
        let image = try #require(HeatmapRenderer.render(points: [CGPoint(x: 0.5, y: 0.5)], aspectRatio: 16 / 10, resolution: 160))
        #expect(image.width == 160 && image.height == 100)
    }
}

/// Deterministic xorshift RNG so tests are reproducible.
struct SeededRandom {
    static var shared = SeededRandom(seed: 99)
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 | 1 }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return Double(state % 1_000_000) / 1_000_000
    }

    mutating func gaussian() -> Double {
        let u1 = max(next(), 1e-9), u2 = next()
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
