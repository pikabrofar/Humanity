import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Carbon hot keys need no Accessibility
/// permission, unlike global NSEvent monitors.
public final class HotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void
    private let id: EventHotKeyID

    /// Every app-level handler sees every hot key press, so each instance gets a
    /// unique ID and ignores presses that aren't its own.
    private static var nextID: UInt32 = 1

    /// - Parameters:
    ///   - keyCode: A virtual key code such as `kVK_ANSI_R`.
    ///   - modifiers: Carbon modifier flags such as `cmdKey | optionKey`.
    public init?(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        self.action = action
        id = EventHotKeyID(signature: OSType(0x4855_4D4E), id: Self.nextID) // 'HUMN'
        Self.nextID += 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var pressed = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
            let hotKey = Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue()
            guard pressed.signature == hotKey.id.signature, pressed.id == hotKey.id.id else {
                return OSStatus(eventNotHandledErr) // someone else's hot key
            }
            hotKey.action()
            return noErr
        }, 1, &eventType, context, &handlerRef)
        guard installed == noErr else { return nil }

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
