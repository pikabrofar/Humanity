import SwiftUI

/// Shows a recording's heatmap over the live desktop. Click or Esc to dismiss.
struct HeatmapOverlayView: View {
    let recording: Recording
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HeatmapCanvas(recording: recording, background: nil, showHeatmap: true, showScanpath: false, placeholder: false)
            HStack(spacing: 10) {
                Text(recording.name).fontWeight(.semibold)
                Text("Click or press Esc to close").foregroundStyle(.white.opacity(0.6))
            }
            .font(.system(size: 12.5))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Capsule().fill(.black.opacity(0.75)))
            .padding(.top, 48)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
    }
}
