import CoreML
import Vision

/// Appearance-based gaze CNN (e.g. L2CS-Net converted with
/// `scripts/convert_l2cs.py`) run on the face crop.
///
/// Expected model: one image input (the face, any size; Vision scales it) and
/// one output with two values, gaze angles in radians. Which value is yaw and
/// which is pitch, and their signs, don't matter: calibration learns a linear
/// map from both to screen angles.
public final class GazeNetwork: @unchecked Sendable {
    private let request: VNCoreMLRequest

    public init(compiledModelAt url: URL) throws {
        let config = MLModelConfiguration()
        config.computeUnits = .all
        let model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
        request = VNCoreMLRequest(model: model)
        request.imageCropAndScaleOption = .scaleFill
    }

    /// Compiles a `.mlpackage`/`.mlmodel` and returns the `.mlmodelc` location.
    public static func compile(_ url: URL) async throws -> URL {
        try await MLModel.compileModel(at: url)
    }

    /// - Parameter face: Face bounding box in normalized Vision coordinates.
    func predict(face: CGRect, imageSize: CGSize, handler: VNImageRequestHandler) -> CGPoint? {
        // Square crop in pixels, slightly enlarged like the detector crops the model was trained on.
        let side = max(face.width * imageSize.width, face.height * imageSize.height) * 1.1
        let center = CGPoint(x: face.midX * imageSize.width, y: face.midY * imageSize.height)
        let roi = CGRect(x: (center.x - side / 2) / imageSize.width, y: (center.y - side / 2) / imageSize.height,
                         width: side / imageSize.width, height: side / imageSize.height)
            .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !roi.isNull, roi.width > 0.02 else { return nil }
        request.regionOfInterest = roi

        guard (try? handler.perform([request])) != nil,
              let array = (request.results?.first as? VNCoreMLFeatureValueObservation)?.featureValue.multiArrayValue,
              array.count >= 2
        else { return nil }
        return CGPoint(x: array[0].doubleValue, y: array[1].doubleValue)
    }
}
