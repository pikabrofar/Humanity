import AppKit
import Foundation
import GazeKit

/// A calibration bound to the display it was recorded on.
struct StoredCalibration: Codable {
    var model: GazeCalibration
    /// Samples from the explicit 9-point calibration.
    var samples: [CalibrationSample]
    /// Samples learned from clicks, newest last.
    var clickSamples: [CalibrationSample] = []
    static let maxClickSamples = 400
    /// Held-out accuracy from the calibration's validation points.
    var validation: ValidationResult?
    var displayID: CGDirectDisplayID
    var displayName: String
    /// Whether the samples include CNN gaze angles.
    var usedNetwork: Bool { samples.contains { $0.features.networkGaze != nil } }
    var screenSize: CGSize

    /// RMS error in screen points.
    var errorPoints: Double { model.report.rmsError * Double(screenSize.width) }

    /// RMS error in degrees of visual angle at the calibration distance.
    var errorDegrees: Double {
        let mm = model.report.rmsError * model.geometry.widthMM
        return atan(mm / model.calibrationDistanceMM) * 180 / .pi
    }

    /// Held-out accuracy when available (honest), else training error (optimistic).
    var accuracyDegrees: Double { validation?.accuracyDegrees ?? errorDegrees }

    var quality: String {
        switch accuracyDegrees {
        case ..<1.5: return "Excellent"
        case ..<2.5: return "Good"
        case ..<4: return "Fair"
        default: return "Poor"
        }
    }
}

enum AppPaths {
    static let support: URL = {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VisionGaze", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    static let recordings: URL = {
        let url = support.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()
}

/// The installed gaze CNN lives in ~/Library/Application Support/VisionGaze/Models.
enum ModelStore {
    private static var directory: URL { AppPaths.support.appendingPathComponent("Models", isDirectory: true) }
    static var compiledURL: URL { directory.appendingPathComponent("GazeCNN.mlmodelc") }
    private static var nameURL: URL { directory.appendingPathComponent("name.txt") }

    static var displayName: String {
        (try? String(contentsOf: nameURL, encoding: .utf8)) ?? "GazeCNN"
    }

    static func install(compiled: URL, name: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: compiledURL.path) { try fm.removeItem(at: compiledURL) }
        try fm.copyItem(at: compiled, to: compiledURL)
        try name.write(to: nameURL, atomically: true, encoding: .utf8)
    }

    static func remove() {
        try? FileManager.default.removeItem(at: directory)
    }
}

enum CalibrationStore {
    private static var url: URL { AppPaths.support.appendingPathComponent("calibration.json") }

    static func load() -> StoredCalibration? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StoredCalibration.self, from: data)
    }

    /// Serial, so saves land on disk in the order they were made.
    private static let saveQueue = DispatchQueue(label: "VisionGaze.CalibrationStore", qos: .utility)

    static func saveInBackground(_ calibration: StoredCalibration?) {
        saveQueue.async { save(calibration) }
    }

    static func waitForSaves() {
        saveQueue.sync {}
    }

    static func save(_ calibration: StoredCalibration?) {
        if let calibration, let data = try? JSONEncoder().encode(calibration) {
            try? data.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

/// Typed UserDefaults keys. Kept deliberately small; SwiftUI's @AppStorage
/// doesn't work inside @Observable models.
enum Defaults {
    enum Key: String {
        case cameraID, pupilRefinement, stability, responsiveness
        case showCursor, cursorStyle, cursorSize
        case hideWhileRecording, captureScreenshot, learnFromClicks
    }

    static func string(_ key: Key) -> String? { UserDefaults.standard.string(forKey: key.rawValue) }
    static func bool(_ key: Key, default value: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key.rawValue) as? Bool ?? value
    }
    static func double(_ key: Key, default value: Double) -> Double {
        UserDefaults.standard.object(forKey: key.rawValue) as? Double ?? value
    }
    static func set(_ value: Any?, _ key: Key) { UserDefaults.standard.set(value, forKey: key.rawValue) }
}
