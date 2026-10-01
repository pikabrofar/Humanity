import SwiftUI

/// Shows a recording's heatmap over the live desktop. Click or Esc to dismiss.
struct HeatmapOverlayView: View {
    let recording: Recording
    let dismiss: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            HeatmapCanvas(recording: recording, background: nil, showHeatmap: true, showScanpath: false, placeholder: false)
            Text("\(recording.name) — click or press Esc to close")
                .font(.callout.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 48)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: dismiss)
    }
}
