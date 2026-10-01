import AVFoundation
import HandKit
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
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported, !connection.isVideoMirrored {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}

/// Hand skeletons over the (mirrored, aspect-fill) preview. The active hand is
/// drawn in the accent color, with the thumb–index line showing pinch state.
struct SkeletonOverlay: View {
    let hands: [HandPose]
    let active: HandPose?
    let imageSize: CGSize
    let pinching: Bool

    private static let bones: [[HandPose.Joint]] = [
        [.wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip],
        [.wrist, .indexMCP, .indexPIP, .indexDIP, .indexTip],
        [.wrist, .middleMCP, .middlePIP, .middleDIP, .middleTip],
        [.wrist, .ringMCP, .ringPIP, .ringDIP, .ringTip],
        [.wrist, .littleMCP, .littlePIP, .littleDIP, .littleTip],
        [.indexMCP, .middleMCP, .ringMCP, .littleMCP],
    ]

    var body: some View {
        Canvas { context, size in
            let map = mapper(for: size)
            for hand in hands {
                let isActive = hand == active
                let color: Color = isActive ? .accentColor : .white.opacity(0.5)
                for chain in Self.bones {
                    let points = chain.compactMap { hand[$0] }.map(map)
                    guard points.count > 1 else { continue }
                    var path = Path()
                    path.addLines(points)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: isActive ? 3 : 2, lineCap: .round, lineJoin: .round))
                }
                for p in hand.joints.values.map(map) {
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
                }
                if isActive, let thumb = hand[.thumbTip].map(map), let index = hand[.indexTip].map(map) {
                    var line = Path()
                    line.move(to: thumb)
                    line.addLine(to: index)
                    context.stroke(line, with: .color(pinching ? .green : .yellow), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                }
            }
        }
        .allowsHitTesting(false)
    }

    /// HandPose coordinates (mirrored, x scaled by aspect, y up) → view points.
    private func mapper(for size: CGSize) -> (CGPoint) -> CGPoint {
        let aspect = imageSize.width / max(imageSize.height, 1)
        let scale = max(size.width / imageSize.width, size.height / imageSize.height)
        let drawn = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let offset = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
        return { p in
            // The preview is mirrored too, so mirrored x maps straight across.
            CGPoint(x: offset.x + p.x / aspect * drawn.width, y: offset.y + (1 - p.y) * drawn.height)
        }
    }
}
