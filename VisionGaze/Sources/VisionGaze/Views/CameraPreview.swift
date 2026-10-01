import AVFoundation
import GazeKit
import SwiftUI

/// Mirrored live camera feed.
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            layer = previewLayer
            previewLayer.videoGravity = .resizeAspectFill
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            // The connection only exists once the session has an input.
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported, !connection.isVideoMirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}

/// Draws the face as corner brackets, eye contours as hairlines and pupils as
/// signal dots on top of `CameraPreview`, matching its aspect-fill, mirrored geometry.
struct LandmarkOverlay: View {
    let landmarks: FaceLandmarksSnapshot?
    let imageSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard let landmarks else { return }
            let map = mapper(for: size)

            let b = landmarks.faceBounds
            let face = CGRect(p1: map(CGPoint(x: b.minX, y: b.minY)), p2: map(CGPoint(x: b.maxX, y: b.maxY)))
            context.stroke(Self.brackets(around: face, length: min(face.width, face.height) * 0.12),
                           with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            for (contour, pupil) in [(landmarks.leftEye, landmarks.leftPupil), (landmarks.rightEye, landmarks.rightPupil)] {
                var eye = Path()
                eye.addLines(contour.map(map))
                eye.closeSubpath()
                context.stroke(eye, with: .color(.white.opacity(0.55)), lineWidth: 1)
                context.fill(Path(ellipseIn: CGRect(center: map(pupil), radius: 2.5)), with: .color(Theme.signal))
            }
        }
        .allowsHitTesting(false)
    }

    /// The four corners of `rect`, like a camera's focus box.
    static func brackets(around r: CGRect, length l: CGFloat) -> Path {
        var p = Path()
        p.addLines([CGPoint(x: r.minX, y: r.minY + l), CGPoint(x: r.minX, y: r.minY), CGPoint(x: r.minX + l, y: r.minY)])
        p.addLines([CGPoint(x: r.maxX - l, y: r.minY), CGPoint(x: r.maxX, y: r.minY), CGPoint(x: r.maxX, y: r.minY + l)])
        p.addLines([CGPoint(x: r.maxX, y: r.maxY - l), CGPoint(x: r.maxX, y: r.maxY), CGPoint(x: r.maxX - l, y: r.maxY)])
        p.addLines([CGPoint(x: r.minX + l, y: r.maxY), CGPoint(x: r.minX, y: r.maxY), CGPoint(x: r.minX, y: r.maxY - l)])
        return p
    }

    /// Normalized Vision point (origin bottom-left) → view point.
    private func mapper(for size: CGSize) -> (CGPoint) -> CGPoint {
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
        return { p in
            CGPoint(x: offset.x + (1 - p.x) * drawn.width, y: offset.y + (1 - p.y) * drawn.height)
        }
    }
}

private extension CGRect {
    init(p1: CGPoint, p2: CGPoint) {
        self.init(x: min(p1.x, p2.x), y: min(p1.y, p2.y), width: abs(p1.x - p2.x), height: abs(p1.y - p2.y))
    }
}
