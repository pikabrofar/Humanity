import AppKit
import SwiftUI

/// Design tokens. The interface is monochrome; `signal` is reserved for live
/// data (gaze, pupils, tracking state) so it always means "this is moving".
enum Theme {
    static let signal = Color(red: 1.0, green: 0.42, blue: 0.14)
    static let record = Color(red: 1.0, green: 0.26, blue: 0.22)
    /// Page background: white in light mode, near-black in dark mode.
    static let canvas = Color(nsColor: .textBackgroundColor)
    static let hairline = Color.primary.opacity(0.09)
    /// Low-contrast fill for wells, tracks and selections.
    static let wash = Color.primary.opacity(0.05)
    /// Selected segment of a segmented control.
    static let thumb = Color(nsColor: NSColor(name: nil) { $0.isDark ? NSColor(white: 1, alpha: 0.16) : .white })
    /// The camera viewport stays dark in both appearances.
    static let viewport = Color(white: 0.07)
    static let radius: CGFloat = 14
}

extension NSAppearance {
    var isDark: Bool { bestMatch(from: [.darkAqua, .aqua]) == .darkAqua }
}

extension Font {
    /// Section labels: small, uppercase, tracked out.
    static let eyebrow = Font.system(size: 10.5, weight: .semibold)
    /// Live numeric readouts.
    static let readout = Font.system(size: 20, weight: .light).monospacedDigit()
    /// Large numbers, e.g. calibration accuracy.
    static let figure = Font.system(size: 30, weight: .light).monospacedDigit()
    /// Text drawn over the camera viewport.
    static let hud = Font.system(size: 10.5, weight: .medium, design: .monospaced)
}

/// Small uppercase section label.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(0.9)
            .foregroundStyle(.secondary)
    }
}

struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// A labeled value, e.g. "Yaw +3°".
struct Readout: View {
    let label: String
    let value: String
    var font: Font = .readout

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(font).lineLimit(1)
        }
    }
}

/// Filled when active, hollow otherwise.
struct StatusDot: View {
    var active: Bool
    var color: Color = Theme.signal

    var body: some View {
        Circle()
            .fill(active ? color : .clear)
            .overlay(Circle().strokeBorder(active ? color : Color.secondary, lineWidth: 1.2))
            .frame(width: 7, height: 7)
    }
}

/// Pulsing dot for recording state.
struct RecordingIndicator: View {
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(Theme.record)
            .frame(width: 8, height: 8)
            .opacity(pulse ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = true }
    }
}

// MARK: Buttons and toggles

/// Solid high-contrast capsule: black on light, white on dark.
struct PrimaryButtonStyle: ButtonStyle {
    var large = false

    func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(configuration: configuration, large: large)
    }

    // Not named `Body`: that would collide with ButtonStyle's associated type.
    private struct PrimaryButton: View {
        let configuration: ButtonStyleConfiguration
        let large: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: large ? 13.5 : 12.5, weight: .semibold))
                .foregroundStyle(.background)
                .padding(.horizontal, large ? 18 : 14)
                .frame(height: large ? 34 : 28)
                .background(Capsule().fill(.foreground))
                .opacity(isEnabled ? (configuration.isPressed ? 0.75 : 1) : 0.3)
                .contentShape(Capsule())
        }
    }
}

/// Low-key capsule on a faint wash.
struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration)
    }

    private struct QuietButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.14 : hovering ? 0.1 : 0.06)))
                .opacity(isEnabled ? 1 : 0.35)
                .contentShape(Capsule())
                .onHover { hovering = $0 }
        }
    }
}

/// A compact switch that lights up in the signal color.
struct SignalSwitchStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 9) {
                configuration.label
                Capsule()
                    .fill(configuration.isOn ? Theme.signal : Color.primary.opacity(0.2))
                    .frame(width: 28, height: 16)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle().fill(.white).padding(2).shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    }
                    .animation(.snappy(duration: 0.18), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

/// On/off chip, for filters that can be combined.
struct ChipToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(configuration.isOn ? HierarchicalShapeStyle.primary : .secondary)
                .padding(.horizontal, 12)
                .frame(height: 26)
                .background(Capsule().fill(configuration.isOn ? Color.primary.opacity(0.09) : .clear))
                .overlay(Capsule().strokeBorder(configuration.isOn ? .clear : Theme.hairline))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
    }
}

/// Text-only picker: the selected option is bright, the others recede.
struct InlinePicker<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i]
                Button { selection = option.value } label: {
                    Text(option.label)
                        .foregroundStyle(option.value == selection ? HierarchicalShapeStyle.primary : .tertiary)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy(duration: 0.15), value: selection)
    }
}

/// Pill-shaped segmented control with a sliding thumb.
struct SegmentedTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    @Namespace private var thumb

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i]
                let selected = option.value == selection
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(selected ? HierarchicalShapeStyle.primary : .secondary)
                        .padding(.horizontal, 14)
                        .frame(height: 24)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Theme.thumb)
                                    .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
                                    .matchedGeometryEffect(id: "thumb", in: thumb)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Theme.wash))
    }
}

// MARK: Window

/// Gives SwiftUI views access to their hosting `NSWindow`.
struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView { ConfiguringView(configure: configure) }
    func updateNSView(_ view: NSView, context: Context) {}

    private final class ConfiguringView: NSView {
        let configure: (NSWindow) -> Void

        init(configure: @escaping (NSWindow) -> Void) {
            self.configure = configure
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { configure(window) }
        }
    }
}

extension TimeInterval {
    var clockString: String {
        let total = Int(self)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
