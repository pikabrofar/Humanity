import CoreGraphics
import Foundation

/// One training pair: the features observed while the user fixated `target`.
public struct CalibrationSample: Codable, Sendable {
    public var features: GazeFeatures
    /// Target position in normalized screen coordinates (0...1, origin top-left).
    public var target: CGPoint

    public init(features: GazeFeatures, target: CGPoint) {
        self.features = features
        self.target = target
    }
}

public enum CalibrationError: Error, LocalizedError {
    case notEnoughSamples(Int)
    case notEnoughTargets(Int)
    case singular

    public var errorDescription: String? {
        switch self {
        case .notEnoughSamples(let n): "Only \(n) usable samples were captured. Make sure your face is visible and well lit."
        case .notEnoughTargets(let n): "Only \(n) calibration points had usable data; at least 5 are needed."
        case .singular: "The calibration data was degenerate. Try again and follow each dot with your eyes."
        }
    }
}

/// Physical setup known before calibration.
public struct ScreenGeometry: Codable, Sendable, Equatable {
    public var widthMM: Double
    public var heightMM: Double
    /// Camera image width / height.
    public var imageAspect: Double
    /// Horizontal field of view of the camera, in radians.
    // ponytail: fixed typical webcam FOV; the fitted distance scale absorbs the error.
    public var cameraFOV: Double

    public init(widthMM: Double, heightMM: Double, imageAspect: Double, cameraFOV: Double = 72 * .pi / 180) {
        self.widthMM = widthMM
        self.heightMM = heightMM
        self.imageAspect = imageAspect
        self.cameraFOV = cameraFOV
    }
}

/// Geometric, head-pose-aware gaze model.
///
/// Camera frame: origin at the camera, x along the image's +x, y up, z toward
/// the user, in millimetres. The screen is the plane z = 0 (webcams sit in the
/// screen's plane), hanging below the camera.
///
/// Per frame:
/// 1. Head position from the face box: distance from its apparent size, lateral
///    offset from its image position (pinhole model).
/// 2. Gaze angles = polynomial of eye-in-head features + weighted head yaw/pitch.
/// 3. The gaze ray from the head is intersected with the screen plane.
///
/// Calibration fits the eye mapping and the physical layout: where the camera
/// sits relative to the screen, a distance scale, and how Vision's head angles
/// map to gaze. Head movement then shifts the ray origin and direction
/// physically, not through a learned correlation, so it extrapolates to head
/// positions not seen during calibration.
///
/// Optionally, a WebGazer-style appearance model on eye-patch pixels corrects
/// the residual gaze angles. It is only kept when it lowers held-out error.
public struct GazeCalibration: Codable, Sendable {
    public private(set) var geometry: ScreenGeometry
    private(set) var params: [Double]
    /// Means of eye x, eye y, openness at calibration; eye features are centered on them.
    private(set) var featureMean: [Double]
    private(set) var appearance: AppearanceModel?
    /// CNN terms are only used when every training sample had CNN output;
    /// a model fit partly without it would weight the CNN on too little data.
    public private(set) var usesNetwork = false
    public private(set) var report: CalibrationReport
    public private(set) var createdAt: Date

    enum P: Int, CaseIterable {
        case a0, a1, a2, a3, a4          // horizontal eye angle polynomial
        case b0, b1, b2, b3, b4, b5      // vertical eye angle polynomial
        case yaw, pitch                  // head rotation weights
        case cameraX, gap, scale         // physical layout
        case netT0, netT1, netP0, netP1  // CNN gaze angles → horizontal / vertical
    }

    static func thetaWeights(_ p: [Double]) -> [Double] {
        [p[0], p[1], p[2], p[3], p[4], p[P.yaw.rawValue], p[P.netT0.rawValue], p[P.netT1.rawValue]]
    }

    static func phiWeights(_ p: [Double]) -> [Double] {
        [p[5], p[6], p[7], p[8], p[9], p[10], p[P.pitch.rawValue], p[P.netP0.rawValue], p[P.netP1.rawValue]]
    }

    private enum CodingKeys: String, CodingKey {
        case geometry, params, featureMean, appearance, usesNetwork, report, createdAt
    }

    /// Rejects calibrations saved by a version with a different parameter layout.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        params = try c.decode([Double].self, forKey: .params)
        guard params.count == P.allCases.count else {
            throw DecodingError.dataCorruptedError(forKey: .params, in: c, debugDescription: "Incompatible model version")
        }
        geometry = try c.decode(ScreenGeometry.self, forKey: .geometry)
        featureMean = try c.decode([Double].self, forKey: .featureMean)
        appearance = try c.decodeIfPresent(AppearanceModel.self, forKey: .appearance)
        usesNetwork = try c.decodeIfPresent(Bool.self, forKey: .usesNetwork) ?? false
        report = try c.decode(CalibrationReport.self, forKey: .report)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    init(geometry: ScreenGeometry, params: [Double], featureMean: [Double], appearance: AppearanceModel?,
         report: CalibrationReport, createdAt: Date) {
        self.geometry = geometry
        self.params = params
        self.featureMean = featureMean
        self.appearance = appearance
        self.report = report
        self.createdAt = createdAt
    }

    /// Nominal width of Vision's face box. Only its ratio to `scale` matters.
    static let faceWidthMM = 150.0

    // MARK: Estimated layout

    /// Camera's horizontal position along the screen's top edge (0 = left, 1 = right).
    public var cameraPosition: Double { params[P.cameraX.rawValue] }
    /// Vertical distance from the camera down to the screen's top edge, in mm.
    public var cameraGapMM: Double { params[P.gap.rawValue] }
    /// Learned weights applied to Vision's yaw and pitch.
    public var headRotationWeights: (yaw: Double, pitch: Double) { (params[P.yaw.rawValue], params[P.pitch.rawValue]) }
    /// Ridge penalty of the appearance correction, or nil when it's disabled.
    public var appearanceRidge: Double? { appearance?.ridge }

    /// Head position in the camera frame, in mm.
    public func headPosition(_ f: GazeFeatures) -> SIMD3<Double> {
        Self.headPosition(f, geometry: geometry, scale: params[P.scale.rawValue])
    }

    /// Predicts the normalized on-screen gaze point.
    public func predict(_ features: GazeFeatures) -> CGPoint {
        var f = features
        if !usesNetwork { f.networkGaze = nil }
        return Self.project(f, params, featureMean, geometry, appearance)
    }

    // MARK: Model

    static func headPosition(_ f: GazeFeatures, geometry: ScreenGeometry, scale: Double) -> SIMD3<Double> {
        let focal = 0.5 / tan(geometry.cameraFOV / 2) // in image widths
        let z = scale * focal * faceWidthMM / max(f.faceSize, 0.01)
        return SIMD3(
            (Double(f.faceCenter.x) - 0.5) / focal * z,
            (Double(f.faceCenter.y) - 0.5) / geometry.imageAspect / focal * z,
            z
        )
    }

    /// Angle-space design rows; shared by the forward model and the linear initialization.
    /// CNN angles enter both rows: the fit learns which output is which axis and its sign.
    static func thetaRow(_ f: GazeFeatures, _ mean: [Double]) -> [Double] {
        let cx = Double(f.eye.x) - mean[0], cy = Double(f.eye.y) - mean[1]
        let net = f.networkGaze ?? .zero
        return [1, cx, cy, cx * cx, cx * cy, f.yaw, Double(net.x), Double(net.y)]
    }

    static func phiRow(_ f: GazeFeatures, _ mean: [Double]) -> [Double] {
        let cx = Double(f.eye.x) - mean[0], cy = Double(f.eye.y) - mean[1], co = f.openness - mean[2]
        let net = f.networkGaze ?? .zero
        return [1, cy, co, cx, cy * cy, cx * cx, f.pitch, Double(net.x), Double(net.y)]
    }

    static func angles(_ f: GazeFeatures, _ p: [Double], _ mean: [Double], _ appearance: AppearanceModel?) -> (Double, Double) {
        var theta = dot(thetaRow(f, mean), thetaWeights(p))
        var phi = dot(phiRow(f, mean), phiWeights(p))
        if let (dt, dp) = appearance?.correction(f) {
            theta += dt
            phi += dp
        }
        return (theta, phi)
    }

    static func project(_ f: GazeFeatures, _ p: [Double], _ mean: [Double], _ g: ScreenGeometry,
                        _ appearance: AppearanceModel? = nil) -> CGPoint {
        let head = headPosition(f, geometry: g, scale: p[P.scale.rawValue])
        let (theta, phi) = angles(f, p, mean, appearance)
        let t = min(max(theta, -1.2), 1.2), ph = min(max(phi, -1.2), 1.2)
        // Ray from head along (-sinθ cosφ, sinφ, -cosθ cosφ), intersected with z = 0.
        let x = head.x - head.z * tan(t)
        let y = head.y + head.z * tan(ph) / cos(t)
        // Screen x runs opposite to camera x (the camera faces the user).
        return CGPoint(x: p[P.cameraX.rawValue] - x / g.widthMM, y: (-y - p[P.gap.rawValue]) / g.heightMM)
    }

    /// Gaze angles needed to hit `target` from the head position (inverse of `project`).
    static func requiredAngles(_ f: GazeFeatures, target: CGPoint, _ p: [Double], _ g: ScreenGeometry) -> (Double, Double) {
        let head = headPosition(f, geometry: g, scale: p[P.scale.rawValue])
        let point = SIMD3(-(Double(target.x) - p[P.cameraX.rawValue]) * g.widthMM,
                          -(p[P.gap.rawValue] + Double(target.y) * g.heightMM), 0)
        let d = point - head
        return (atan2(-d.x, -d.z), atan2(d.y, (d.x * d.x + d.z * d.z).squareRoot()))
    }

    // MARK: Fitting

    /// - Parameters:
    ///   - validation: Held-out samples. When given, the appearance correction's
    ///     ridge penalty is chosen on them, or the correction is dropped.
    ///   - appearanceRidge: Reuse a previously chosen penalty (for refits without validation data).
    public static func fit(
        samples: [CalibrationSample],
        geometry: ScreenGeometry,
        validation: [CalibrationSample] = [],
        appearanceRidge: Double? = nil
    ) throws -> GazeCalibration {
        var usable = samples.filter { !$0.features.isBlinking && $0.features.faceSize > 0.01 }
        let usesNetwork = !usable.isEmpty && usable.allSatisfy { $0.features.networkGaze != nil }
        if !usesNetwork {
            for i in usable.indices { usable[i].features.networkGaze = nil }
        }
        let targetCount = Set(usable.map { TargetKey($0.target) }).count
        guard usable.count >= 20 else { throw CalibrationError.notEnoughSamples(usable.count) }
        guard targetCount >= 5 else { throw CalibrationError.notEnoughTargets(targetCount) }

        let n = Double(usable.count)
        let mean = [
            usable.reduce(0) { $0 + Double($1.features.eye.x) } / n,
            usable.reduce(0) { $0 + Double($1.features.eye.y) } / n,
            usable.reduce(0) { $0 + $1.features.openness } / n,
        ]

        // Robust fit (IRLS with Huber weights). People don't fixate perfectly:
        // they drift, make corrective saccades, and glance away. Moderate misses
        // count linearly instead of quadratically; gross ones (> 5σ) are dropped.
        var weights = [Double](repeating: 1, count: usable.count)
        var fitted: [Double]?
        for _ in 0..<3 {
            let p = try solve(usable, weights: weights, mean: mean, geometry: geometry, start: fitted)
            fitted = p
            let errors = usable.map { errorMM(project($0.features, p, mean, geometry), $0.target, geometry) }
            // Median of a 2D Gaussian error magnitude ≈ 1.177σ.
            let sigma = max(errors.median / 1.177, 2)
            weights = errors.map { $0 > 5 * sigma ? 0 : min(1, 2 * sigma / max($0, 1e-9)) }
        }
        let params = fitted!
        let training = zip(usable, weights).filter { $0.1 > 0 }.map(\.0)
        guard training.count >= 20 else { throw CalibrationError.notEnoughSamples(training.count) }

        var model = GazeCalibration(geometry: geometry, params: params, featureMean: mean, appearance: nil,
                                    report: CalibrationReport(points: [], rmsError: 0), createdAt: Date())
        model.usesNetwork = usesNetwork

        let ridges: [Double] = validation.isEmpty ? (appearanceRidge.map { [$0] } ?? []) : [0.003, 0.01, 0.03, 0.1, 0.3, 1]
        if !ridges.isEmpty {
            // Residual angles the geometric model leaves unexplained.
            let residuals = training.map { s -> (Double, Double) in
                let required = requiredAngles(s.features, target: s.target, params, geometry)
                let base = angles(s.features, params, mean, nil)
                return (required.0 - base.0, required.1 - base.1)
            }
            let candidates = AppearanceModel.fit(training.map(\.features), residuals: residuals, ridges: ridges)
            if validation.isEmpty {
                model.appearance = candidates.first
            } else {
                var bestError = model.validate(validation).accuracyDegrees
                for candidate in candidates {
                    var trial = model
                    trial.appearance = candidate
                    let error = trial.validate(validation).accuracyDegrees
                    if error < bestError {
                        bestError = error
                        model.appearance = candidate
                    }
                }
            }
        }

        model.report = CalibrationReport(model: model, samples: training)
        return model
    }

    /// Tobii-style data quality on held-out samples: accuracy is the angle
    /// between each target and the median gaze on it; precision is the RMS of
    /// sample-to-sample angular distances.
    public func validate(_ samples: [CalibrationSample]) -> ValidationResult {
        var order: [TargetKey] = []
        var groups: [TargetKey: [CalibrationSample]] = [:]
        for s in samples where !s.features.isBlinking {
            let key = TargetKey(s.target)
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(s)
        }

        var points: [CalibrationReport.Point] = []
        var accuracies: [Double] = []
        var squaredSteps: [Double] = []
        for key in order {
            guard let group = groups[key], group.count >= 3 else { continue }
            let predictions = group.map { predict($0.features) }
            let distance = group.map { headPosition($0.features).z }.reduce(0, +) / Double(group.count)
            let median = CGPoint(x: predictions.map { Double($0.x) }.median, y: predictions.map { Double($0.y) }.median)
            let target = group[0].target
            accuracies.append(degrees(from: median, to: target, distance: distance))
            for (a, b) in zip(predictions, predictions.dropFirst()) {
                squaredSteps.append(pow(degrees(from: a, to: b, distance: distance), 2))
            }
            points.append(.init(target: target, predicted: median, error: median.distance(to: target)))
        }
        return ValidationResult(
            accuracyDegrees: accuracies.isEmpty ? .infinity : accuracies.reduce(0, +) / Double(accuracies.count),
            precisionDegrees: squaredSteps.isEmpty ? 0 : (squaredSteps.reduce(0, +) / Double(squaredSteps.count)).squareRoot(),
            points: points
        )
    }

    private func degrees(from a: CGPoint, to b: CGPoint, distance: Double) -> Double {
        let mm = hypot(Double(a.x - b.x) * geometry.widthMM, Double(a.y - b.y) * geometry.heightMM)
        return atan(mm / distance) * 180 / .pi
    }

    static func errorMM(_ a: CGPoint, _ b: CGPoint, _ g: ScreenGeometry) -> Double {
        hypot(Double(a.x - b.x) * g.widthMM, Double(a.y - b.y) * g.heightMM)
    }

    /// Linear initialization in angle space with a nominal layout (unless
    /// warm-started), then weighted Levenberg–Marquardt on on-screen error (mm).
    static func solve(_ samples: [CalibrationSample], weights: [Double], mean: [Double],
                      geometry g: ScreenGeometry, start: [Double]?) throws -> [Double] {
        var p: [Double]
        if let start {
            p = start
        } else {
            p = [Double](repeating: 0, count: P.allCases.count)
            p[P.cameraX.rawValue] = 0.5
            p[P.gap.rawValue] = 10
            p[P.scale.rawValue] = 1

            let angles = samples.map { requiredAngles($0.features, target: $0.target, p, g) }
            guard let wt = ridgeSolve(samples.map { thetaRow($0.features, mean) }, angles.map(\.0),
                                      penalty: [0, 1e-6, 1e-6, 1e-4, 1e-4, 1e-3, 1e-4, 1e-4]),
                  let wp = ridgeSolve(samples.map { phiRow($0.features, mean) }, angles.map(\.1),
                                      penalty: [0, 1e-6, 1e-6, 1e-6, 1e-4, 1e-4, 1e-3, 1e-4, 1e-4])
            else { throw CalibrationError.singular }
            p.replaceSubrange(0...4, with: wt[0...4])
            p.replaceSubrange(5...10, with: wp[0...5])
            p[P.yaw.rawValue] = wt[5]
            p[P.netT0.rawValue] = wt[6]
            p[P.netT1.rawValue] = wt[7]
            p[P.pitch.rawValue] = wp[6]
            p[P.netP0.rawValue] = wp[7]
            p[P.netP1.rawValue] = wp[8]
        }
        let root = weights.map { $0.squareRoot() }

        // Priors keep weakly observed parameters physical. A 1σ deviation costs
        // as much as every sample being 5 mm further off.
        let priors: [(P, Double, Double)] = [
            (.cameraX, 0.5, 0.05), (.gap, 10, 15), (.scale, 1, 0.15),
            (.yaw, 0, 3), (.pitch, 0, 3),
            // Curvature terms: webcam pupil noise makes them overfit with weak priors.
            (.a3, 0, 3), (.a4, 0, 3), (.b3, 0, 3), (.b4, 0, 3), (.b5, 0, 3),
            (.netT0, 0, 5), (.netT1, 0, 5), (.netP0, 0, 5), (.netP1, 0, 5),
        ]
        let priorWeight = Double(samples.count).squareRoot() * 5
        let residuals = { (p: [Double]) -> [Double] in
            var r: [Double] = []
            r.reserveCapacity(samples.count * 2 + priors.count)
            for (s, w) in zip(samples, root) {
                let q = project(s.features, p, mean, g)
                r.append(w * Double(q.x - s.target.x) * g.widthMM)
                r.append(w * Double(q.y - s.target.y) * g.heightMM)
            }
            for (param, mu, sigma) in priors { r.append(priorWeight * (p[param.rawValue] - mu) / sigma) }
            return r
        }
        return LinearAlgebra.levenbergMarquardt(p, residuals: residuals)
    }

    /// Solves (XᵀX + n·diag(penalty)) w = Xᵀy.
    static func ridgeSolve(_ rows: [[Double]], _ y: [Double], penalty: [Double]) -> [Double]? {
        let p = penalty.count, n = Double(rows.count)
        var a = [[Double]](repeating: [Double](repeating: 0, count: p), count: p)
        var b = [Double](repeating: 0, count: p)
        for (row, target) in zip(rows, y) {
            for i in 0..<p {
                b[i] += row[i] * target
                for j in i..<p { a[i][j] += row[i] * row[j] }
            }
        }
        for i in 0..<p {
            a[i][i] += n * penalty[i]
            for j in 0..<i { a[i][j] = a[j][i] }
        }
        return LinearAlgebra.solve(a, b)
    }

    /// Typical head distance during calibration, in mm.
    public var calibrationDistanceMM: Double { report.meanDistanceMM }
}

public struct ValidationResult: Codable, Sendable {
    /// Mean angular offset between targets and the median gaze on them.
    public var accuracyDegrees: Double
    /// RMS of sample-to-sample angular distances (jitter before smoothing).
    public var precisionDegrees: Double
    public var points: [CalibrationReport.Point]
}

/// Ridge regression from eye-patch pixels to residual gaze angles.
struct AppearanceModel: Codable, Sendable {
    var mean: [Double]
    /// Weights for the horizontal and vertical angle.
    var weights: [[Double]]
    var ridge: Double

    func correction(_ f: GazeFeatures) -> (Double, Double)? {
        guard f.appearance.count == mean.count else { return nil }
        var theta = 0.0, phi = 0.0
        for i in mean.indices {
            let x = Double(f.appearance[i]) - mean[i]
            theta += weights[0][i] * x
            phi += weights[1][i] * x
        }
        return (theta, phi)
    }

    /// One model per ridge penalty, sharing the Gram matrix.
    static func fit(_ features: [GazeFeatures], residuals: [(Double, Double)], ridges: [Double]) -> [AppearanceModel] {
        let pairs = zip(features, residuals).filter { !$0.0.appearance.isEmpty }
        guard let dims = pairs.first?.0.appearance.count, pairs.count >= 50,
              pairs.allSatisfy({ $0.0.appearance.count == dims })
        else { return [] }
        let n = Double(pairs.count)

        var mean = [Double](repeating: 0, count: dims)
        for (f, _) in pairs { for i in 0..<dims { mean[i] += Double(f.appearance[i]) / n } }

        var gram = [[Double]](repeating: [Double](repeating: 0, count: dims), count: dims)
        var bt = [Double](repeating: 0, count: dims), bp = [Double](repeating: 0, count: dims)
        var x = [Double](repeating: 0, count: dims)
        for (f, r) in pairs {
            for i in 0..<dims { x[i] = Double(f.appearance[i]) - mean[i] }
            for i in 0..<dims {
                bt[i] += x[i] * r.0
                bp[i] += x[i] * r.1
                for j in i..<dims { gram[i][j] += x[i] * x[j] }
            }
        }
        for i in 0..<dims { for j in 0..<i { gram[i][j] = gram[j][i] } }

        return ridges.compactMap { ridge in
            var a = gram
            for i in 0..<dims { a[i][i] += ridge * n }
            guard let wt = LinearAlgebra.solve(a, bt), let wp = LinearAlgebra.solve(a, bp) else { return nil }
            return AppearanceModel(mean: mean, weights: [wt, wp], ridge: ridge)
        }
    }
}

/// Per-target accuracy of a fitted calibration, for display.
public struct CalibrationReport: Codable, Sendable {
    public struct Point: Codable, Sendable, Identifiable {
        public var target: CGPoint
        /// Mean prediction for the samples of this target.
        public var predicted: CGPoint
        /// Mean distance of individual predictions to the target (normalized units).
        public var error: Double
        public var id: String { "\(target.x),\(target.y)" }
    }

    public var points: [Point]
    /// Root-mean-square error over all samples, in normalized screen units.
    public var rmsError: Double
    /// Mean head distance over the samples, in mm.
    public var meanDistanceMM: Double = 600

    init(points: [Point], rmsError: Double) {
        self.points = points
        self.rmsError = rmsError
    }

    init(model: GazeCalibration, samples: [CalibrationSample]) {
        // Moving-target samples each have a unique target; only fixed targets are plotted.
        let groups = Dictionary(grouping: samples) { TargetKey($0.target) }.filter { $0.value.count >= 5 }
        points = groups.values.map { group in
            let predictions = group.map { model.predict($0.features) }
            let target = group[0].target
            return Point(
                target: target,
                predicted: predictions.centroid,
                error: predictions.map { $0.distance(to: target) }.reduce(0, +) / Double(predictions.count)
            )
        }.sorted { ($0.target.y, $0.target.x) < ($1.target.y, $1.target.x) }
        let squared = samples.map { pow(model.predict($0.features).distance(to: $0.target), 2) }
        rmsError = (squared.reduce(0, +) / Double(max(squared.count, 1))).squareRoot()
        meanDistanceMM = samples.map { model.headPosition($0.features).z }.reduce(0, +) / Double(max(samples.count, 1))
    }
}

/// Hashable wrapper so samples can be grouped by target.
private struct TargetKey: Hashable {
    let x: Int, y: Int
    init(_ p: CGPoint) {
        x = Int((p.x * 10_000).rounded())
        y = Int((p.y * 10_000).rounded())
    }
}

private func dot(_ a: [Double], _ b: [Double]) -> Double {
    zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
}

extension CGPoint {
    public func distance(to other: CGPoint) -> Double {
        Double(hypot(x - other.x, y - other.y))
    }
}

extension Array where Element == Double {
    var median: Double {
        guard !isEmpty else { return 0 }
        let s = sorted()
        return s.count.isMultiple(of: 2) ? (s[s.count / 2 - 1] + s[s.count / 2]) / 2 : s[s.count / 2]
    }
}
