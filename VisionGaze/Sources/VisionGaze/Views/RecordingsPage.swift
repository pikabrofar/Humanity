import GazeKit
import SwiftUI
import UniformTypeIdentifiers

struct RecordingsPage: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            RecordingList()
                .frame(width: 264)
            Rectangle().fill(Theme.hairline).frame(width: 1)
            if let recording = model.recordings.recordings.first(where: { $0.id == model.selectedRecordingID }) {
                RecordingDetail(recording: recording)
                    .id(recording.id)
            } else {
                Text(model.recordings.recordings.isEmpty ? "" : "Select a recording")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct RecordingList: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let recordings = model.recordings.recordings
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Eyebrow("Recordings")
                Spacer()
                Text("\(recordings.count)").font(.eyebrow).monospacedDigit().foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)
            .padding(.bottom, 12)

            if recordings.isEmpty {
                VStack(spacing: 6) {
                    Text("No recordings yet").font(.system(size: 13, weight: .semibold))
                    Text("Press ⌥⌘R in any app to record where you look.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(recordings) { recording in
                            RecordingRow(recording: recording, selected: recording.id == model.selectedRecordingID)
                                .onTapGesture { model.selectedRecordingID = recording.id }
                                .contextMenu {
                                    Button("Delete", role: .destructive) { model.recordings.delete(recording.id) }
                                }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .focusable()
                .focusEffectDisabled()
                .onKeyPress(.upArrow) { select(offset: -1) }
                .onKeyPress(.downArrow) { select(offset: 1) }
                .onDeleteCommand {
                    if let id = model.selectedRecordingID { model.recordings.delete(id) }
                }
            }
        }
    }

    private func select(offset: Int) -> KeyPress.Result {
        let recordings = model.recordings.recordings
        guard !recordings.isEmpty else { return .ignored }
        let current = recordings.firstIndex { $0.id == model.selectedRecordingID } ?? -offset
        model.selectedRecordingID = recordings[min(max(current + offset, 0), recordings.count - 1)].id
        return .handled
    }
}

private struct RecordingRow: View {
    let recording: Recording
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(recording.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Text("\(recording.duration.clockString) · \(recording.samples.count.formatted()) samples")
                .font(.system(size: 11.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(selected ? Color.primary.opacity(0.07) : .clear))
        .contentShape(Rectangle())
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
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 22, weight: .semibold))
                        .onSubmit { model.recordings.rename(recording.id, to: name) }
                    Text("\(recording.date.formatted(date: .abbreviated, time: .shortened)) · \(Int(recording.screenSize.width)) × \(Int(recording.screenSize.height)) pt")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 20)
                HStack(spacing: 8) {
                    Button("Show on Screen") { model.showHeatmapOverlay(recording) }
                        .buttonStyle(QuietButtonStyle())
                    Menu {
                        Button("Heatmap Image (PNG)…") { model.export(recording, as: .png) }
                        Button("Gaze Samples (CSV)…") { model.export(recording, as: .commaSeparatedText) }
                    } label: {
                        Text("Export")
                    }
                    .menuStyle(.button)
                    .buttonStyle(QuietButtonStyle())
                    .menuIndicator(.hidden)
                    .fixedSize()
                }
            }

            HeatmapCanvas(recording: recording, background: model.recordings.screenshot(for: recording),
                          showHeatmap: showHeatmap, showScanpath: showScanpath, fixations: fixations)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
                .frame(maxWidth: .infinity)

            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Toggle("Heatmap", isOn: $showHeatmap)
                    Toggle("Scanpath", isOn: $showScanpath)
                }
                .toggleStyle(ChipToggleStyle())
                Spacer(minLength: 20)
                HStack(spacing: 28) {
                    stat(recording.duration.clockString, "Duration")
                    stat(recording.samples.count.formatted(), "Samples")
                    stat("\(fixations.count)", "Fixations")
                    if !fixations.isEmpty {
                        let mean = fixations.map(\.duration).reduce(0, +) / Double(fixations.count)
                        stat(String(format: "%.0f ms", mean * 1000), "Mean fixation")
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .onAppear { name = recording.name }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        Readout(label: label, value: value, font: .system(size: 16, weight: .regular).monospacedDigit())
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
                Rectangle().fill(Theme.viewport)
                    .overlay(alignment: .bottomLeading) {
                        Text("Turn on “Capture screenshot” in Settings to see what you were looking at.")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.35)).padding(12)
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
            context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)

            let labeled = fixations.count <= 50
            for (i, (fixation, p)) in zip(fixations, points).enumerated() {
                let radius = max(5, min(28, sqrt(fixation.duration) * 22))
                let circle = Path(ellipseIn: CGRect(center: p, radius: radius))
                context.fill(circle, with: .color(Theme.signal.opacity(0.4)))
                context.stroke(circle, with: .color(Theme.signal), lineWidth: 1)
                if labeled {
                    context.draw(Text("\(i + 1)").font(.system(size: 10, weight: .semibold, design: .monospaced)).foregroundColor(.white), at: p)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
