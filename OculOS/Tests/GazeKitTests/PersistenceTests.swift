import Foundation
import Testing
@testable import GazeKit
@testable import OculOSUI

@Suite struct PersistenceTests {
    @Test func olderCalibrationFileStillLoads() throws {
        var rng = SeededRandom(seed: 4)
        let samples = CalibrationTests.calibrationSamples(.init(), rng: &rng)
        let model = try GazeCalibration.fit(samples: samples, geometry: CalibrationTests.geometry)
        let stored = StoredCalibration(model: model, samples: samples, displayID: 1, displayName: "Display",
                                       screenSize: CGSize(width: 1512, height: 982))
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(stored)) as? [String: Any] ?? [:]
        json["clickSamples"] = nil // fields added after the first release
        json["validation"] = nil
        let old = try JSONDecoder().decode(StoredCalibration.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(old.clickSamples.isEmpty)
        #expect(old.samples.count == samples.count)
        #expect(old.displayID == 1)
    }
}
