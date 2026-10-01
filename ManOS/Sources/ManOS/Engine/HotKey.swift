// ponytail: copied from VisionGaze; move to a shared package when a third app needs it.
import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Carbon hot keys need no Accessibility
/// permission, unlike global NSEvent monitors.
final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// - Parameters:
    ///   - keyCode: A virtual key code such as `kVK_ANSI_R`.
    ///   - modifiers: Carbon modifier flags such as `cmdKey | optionKey`.
    init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().action()
            return noErr
        }, 1, &eventType, context, &handlerRef)
        guard installed == noErr else { return nil }

        let id = EventHotKeyID(signature: OSType(0x4458_5452), id: 1) // 'DXTR'
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
