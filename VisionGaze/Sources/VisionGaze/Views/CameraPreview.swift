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

/// Draws eye contours and pupils on top of `CameraPreview`, matching its
/// aspect-fill, mirrored geometry.
struct LandmarkOverlay: View {
    let landmarks: FaceLandmarksSnapshot?
    let imageSize: CGSize

    var body: some View {
        Canvas { context, size in
            guard let landmarks else { return }
            let map = mapper(for: size)

            var face = Path()
            let b = landmarks.faceBounds
            face.addRoundedRect(in: CGRect(p1: map(CGPoint(x: b.minX, y: b.minY)), p2: map(CGPoint(x: b.maxX, y: b.maxY))),
                                cornerSize: CGSize(width: 14, height: 14))
            context.stroke(face, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))

            for (contour, pupil) in [(landmarks.leftEye, landmarks.leftPupil), (landmarks.rightEye, landmarks.rightPupil)] {
                var eye = Path()
                eye.addLines(contour.map(map))
                eye.closeSubpath()
                context.stroke(eye, with: .color(.accentColor), lineWidth: 1.5)
                let p = map(pupil)
                context.fill(Path(ellipseIn: CGRect(center: p, radius: 3)), with: .color(.white))
                context.stroke(Path(ellipseIn: CGRect(center: p, radius: 6)), with: .color(.accentColor.opacity(0.8)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
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
