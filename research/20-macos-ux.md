# UX/UI Design for Humanity macOS Utilities

## Summary

The best macOS utilities (Raycast, CleanShot X, Rectangle, Ice, Bartender) stay out of the way. Each has a monochrome menu bar icon that shows state, explains permissions before macOS asks for them, keeps Settings to a few grouped tabs, and gives feedback in small HUDs that never take focus. Humanity apps need Camera, Microphone, Speech Recognition and Accessibility permissions, so the first-run flow is the screen that matters most. On macOS 26, Liquid Glass belongs only on floating controls and HUDs, never on content. These notes come from limited research (about 10 lookups). The Apple HIG pages render with JavaScript and could not be fetched, so the HIG points are paraphrased from search snippets and established practice.

## Key findings

- **Menu bar extras.** According to the HIG, only a menu bar extra may use a symbol as its title. Users pick which extras stay visible, and the system hides extras when space runs out. Use a template image or SF Symbol and expect to be hidden (Ice and Bartender exist for this reason). `MenuBarExtra` has two styles: `.menu` (a native pulldown) and `.window` (a popover-style panel).
- **Opening Settings from an agent app.** In an `LSUIElement` app, `SettingsLink` cannot run code when clicked, so the Settings window can open *behind* other apps. The fix is a Button that activates the app first and then calls `@Environment(\.openSettings)`.
- **Permission priming.** Raycast, Wispr Flow and superwhisper explain each permission in plain language before the system prompt appears. Accessibility can't be granted from a prompt: the user has to flip a switch in System Settings. Good onboarding deep-links to the right pane, polls `AXIsProcessTrusted()`, and moves to the next step on its own without a relaunch. Sandboxed builds may never show up in the Accessibility list.
- **Settings organization.** Community HIG extras: use a grouped `Form` (`.formStyle(.grouped)`), disable (don't remove) the minimize/zoom buttons, keep the window in the Window menu, and give tabs SF Symbols.
- **Liquid Glass (macOS 26).** APIs: `.glassEffect(_:in:isEnabled:)` with `.regular`, `.clear` and `.identity`, which you can chain with `.tint()` and `.interactive()`; `GlassEffectContainer(spacing:)`; `.glassEffectID(_:in:)` for morphing; and `.buttonStyle(.glass)` / `.glassProminent`. Glass is for the navigation and control layer only, never for lists or content. `NavigationSplitView` sidebars get the floating glass look automatically when built with Xcode 26. Respect `accessibilityReduceTransparency` by switching to `.identity`. Use `.ultraThinMaterial` as the fallback before macOS 26.
- **App icons.** macOS 26 draws icons from a layered Icon Composer `.icon` file (up to 4 depth groups). The system adds the squircle, specular edge, shadow and the dark, clear and tinted variants. Xcode also builds a flattened `.icns` fallback. Icons that aren't squircles get put inside a gray container.
- **Localization.** String Catalogs (`.xcstrings`) are filled automatically from SwiftUI string literals (`LocalizedStringKey`) and `LocalizedStringResource` at build time.

## Recommendations (ranked)

1. **Build a shared Quick Setup checklist.** One window shows one row per permission. Each row has an SF Symbol, a single sentence on why it's needed ("Camera: tracks your gaze; frames never leave this Mac"), a live status pill (Not granted / Granted), and one button. Accessibility rows deep-link to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, poll every 1 s, and check themselves off. Never fire a system prompt before the user has seen its row. Make Setup reopenable from the menu bar and from Settings.
2. **Make the menu bar icon the status display.** Use a template SF Symbol whose variant shows state: `eye` / `eye.slash` for off, a filled symbol plus `.symbolEffect(.pulse)` while active, and a badge for "permission missing". The first menu row should be the main on/off toggle with its shortcut shown. Settings…, Quick Setup and Quit go at the bottom.
3. **Activate the app before opening Settings.** Wrap `openSettings()` in a Button that calls `NSApp.activate()` first, so Settings never opens behind other windows.
4. **Use the HUD overlay pattern.** Build HUDs as a borderless `NSPanel` with `.nonactivatingPanel`, `ignoresMouseEvents = true`, level `.statusBar`, and `collectionBehavior` set to `[.canJoinAllSpaces, .fullScreenAuxiliary]`. Use a glass capsule (`.glassEffect(.regular, in: .capsule)`) with high-contrast symbols, and fade it out automatically after about 1.5 s. Respect Reduce Motion and Reduce Transparency, and never steal focus.
5. **Keep glass to chrome only.** Apply glass to HUDs, floating toolbars and the gaze cursor. Leave the calibration views, gesture lists and transcript content opaque. Group neighbouring glass controls in a `GlassEffectContainer`.
6. **Standardize Settings tabs.** Use the same tabs in all three apps: General (launch at login via `SMAppService`, menu bar icon), the core feature (Tracking / Gestures / Dictation), Shortcuts, Permissions (a mirror of the Setup checklist), and About. Use grouped `Form`s and explain non-obvious toggles in footers.
7. **Design empty and error states.** Use `ContentUnavailableView` in the sidebar main window, for example "No camera detected" or "Accessibility not granted". Each should come with a primary action button and never be a blank pane.
8. **Use one icon family.** Create layered Icon Composer `.icon` files that share a background glass tile and use a different foreground glyph per app (eye, hand, waveform). Check all of them in the Clear and Tinted modes.
9. **Make README visuals work hard.** Put a short (under 10 s) MP4 or GIF at the top of each README showing the HUD responding in real time. Add light and dark screenshots with `<picture>` and `prefers-color-scheme`, plus a "Permissions and privacy" section that matches the Setup copy.
10. **Localize from day one.** Use SwiftUI string literals and `String(localized:)` everywhere, add a `Localizable.xcstrings`, and avoid concatenating strings (use interpolation so translators get the whole sentence). Permission purpose strings (`NSCameraUsageDescription` and the others) go in `InfoPlist.xcstrings`.

## Sources

- https://developers.apple.com/design/human-interface-guidelines/components/system-experiences/the-menu-bar/
- https://developer.apple.com/documentation/SwiftUI/MenuBarExtra
- https://github.com/sindresorhus/human-interface-guidelines-extras
- https://github.com/joaodavidsilva/brightboi/issues/78
- https://github.com/orchetect/SettingsAccess
- https://nilcoalescing.com/blog/BuildAMacOSMenuBarUtilityInSwiftUI/
- https://github.com/humanitas-labs/parrot/issues/51
- https://github.com/ryan-stoffel/quoth/issues/66
- https://github.com/lwouis/alt-tab-macos/issues/127
- https://developer.apple.com/forums/thread/810677
- https://www.conor.fyi/writing/liquid-glass-reference
- https://github.com/conorluddy/LiquidGlassReference
- https://github.com/Dimillian/Skills/blob/main/swiftui-liquid-glass/SKILL.md
- https://basicappleguy.com/basicappleblog/icon-composer
- https://github.com/scottdensmore/ControlPlane/issues/276
- https://tanaschita.com/swiftui-localization/
- https://www.fline.dev/the-missing-string-catalogs-faq-for-xcode-15/
