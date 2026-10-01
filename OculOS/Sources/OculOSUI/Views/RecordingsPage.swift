import GazeKit
import SwiftUI
import UniformTypeIdentifiers

struct RecordingsPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        HStack(spacing: 0) {
            List(selection: $model.selectedRecordingID) {
                ForEach(model.recordings.recordings) { recording in
                    RecordingRow(recording: recording)
                        .tag(recording.id)
                        .contextMenu {
                            Button("Delete", role: .destructive) { model.recordings.delete(recording.id) }
                        }
                }
            }
            .frame(width: 240)
            .overlay {
                if model.recordings.recordings.isEmpty {
                    ContentUnavailableView {
                        Label("No Recordings", systemImage: "flame")
                    } description: {
                        Text("Press Record (⌥⌘R) to capture where you look.")
                    }
                }
            }

            Divider()

            if let recording = model.recordings.recordings.first(where: { $0.id == model.selectedRecordingID }) {
                RecordingDetail(recording: recording)
                    .id(recording.id)
            } else {
                ContentUnavailableView("Select a Recording", systemImage: "square.stack")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Recordings")
        .toolbar {
            ToolbarItem { RecordButton() }
        }
    }
}

private struct RecordingRow: View {
    let recording: Recording

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(recording.name).lineLimit(1)
            Text("\(recording.duration.clockString) · \(recording.samples.count) samples")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }
}

private struct RecordingDetail: View {
    @Environment(AppModel.self) private var model
    let recording: Recording

    @State private var showHeatmap = true
    @State private var showScanpath = false
    @State private var name = ""

    var body: some View {
        let fixations = recording.fixations()
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TextField("Name", text: $name)
                    .textFieldStyle(.plain)
                    .font(.title2.weight(.semibold))
                    .onSubmit { model.recordings.rename(recording.id, to: name) }
                Spacer()
                Menu {
                    Button("Heatmap Image (PNG)…") { model.export(recording, as: .png) }
                    Button("Gaze Samples (CSV)…") { model.export(recording, as: .commaSeparatedText) }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .fixedSize()
                Button {
                    model.showHeatmapOverlay(recording)
                } label: {
                    Label("Show on Screen", systemImage: "rectangle.inset.filled.on.rectangle")
                }
            }

            HeatmapCanvas(recording: recording, background: model.recordings.screenshot(for: recording),
                          showHeatmap: showHeatmap, showScanpath: showScanpath, fixations: fixations)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator))
                .frame(maxWidth: .infinity)

            HStack(spacing: 20) {
                Toggle("Heatmap", isOn: $showHeatmap)
                Toggle("Scanpath", isOn: $showScanpath)
                Spacer()
                stat(recording.duration.clockString, "duration")
                stat("\(recording.samples.count)", "samples")
                stat("\(fixations.count)", "fixations")
                if !fixations.isEmpty {
                    let mean = fixations.map(\.duration).reduce(0, +) / Double(fixations.count)
                    stat(String(format: "%.0f ms", mean * 1000), "mean fixation")
                }
            }
            .toggleStyle(.checkbox)
            Spacer(minLength: 0)
        }
        .padding(20)
        .onAppear { name = recording.name }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(value).font(.callout.weight(.medium).monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Heatmap and/or scanpath drawn over the recording's screenshot, a dark
/// placeholder, or nothing (for the on-screen overlay).
struct HeatmapCanvas: View {
    let recording: Recording
    let background: NSImage?
    var showHeatmap = true
    var showScanpath = false
    var placeholder = true
    var fixations: [Fixation] = []

    @State private var heatmap: CGImage?

    var body: some View {
        ZStack {
            if let background {
                Image(nsImage: background).resizable()
            } else if placeholder {
                Rectangle().fill(Color(white: 0.1))
                    .overlay(alignment: .bottomTrailing) {
                        Text("Enable “Capture screenshot” in Settings to see what you were looking at")
                            .font(.caption).foregroundStyle(.white.opacity(0.4)).padding(10)
                    }
            }
            if showHeatmap, let heatmap {
                Image(decorative: heatmap, scale: 1).resizable().interpolation(.high)
                    .transition(.opacity)
            }
            if showScanpath {
                ScanpathView(fixations: fixations, screenSize: recording.screenSize)
            }
        }
        .aspectRatio(recording.aspectRatio, contentMode: .fit)
        .task(id: recording.id) {
            let points = recording.samples.map(\.point), aspect = recording.aspectRatio
            let image = await Task.detached(priority: .userInitiated) {
                HeatmapRenderer.render(points: points, aspectRatio: aspect)
            }.value
            withAnimation { heatmap = image }
        }
    }
}

private struct ScanpathView: View {
    let fixations: [Fixation]
    let screenSize: CGSize

    var body: some View {
        Canvas { context, size in
            let sx = size.width / screenSize.width, sy = size.height / screenSize.height
            let points = fixations.map { CGPoint(x: $0.center.x * sx, y: $0.center.y * sy) }

            var path = Path()
            path.addLines(points)
            context.stroke(path, with: .color(.white.opacity(0.55)), lineWidth: 1.5)

            let labeled = fixations.count <= 50
            for (i, (fixation, p)) in zip(fixations, points).enumerated() {
                let radius = max(5, min(28, sqrt(fixation.duration) * 22))
                let circle = Path(ellipseIn: CGRect(center: p, radius: radius))
                context.fill(circle, with: .color(.accentColor.opacity(0.45)))
                context.stroke(circle, with: .color(.white.opacity(0.9)), lineWidth: 1)
                if labeled {
                    context.draw(Text("\(i + 1)").font(.system(size: 10, weight: .bold)).foregroundColor(.white), at: p)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
