// ponytail: copied from OculOS/ManOS, plus key-up events and an ID check;
// move to a shared package when it changes again.
import Carbon.HIToolbox

/// A system-wide keyboard shortcut. Carbon hot keys need no Accessibility
/// permission, unlike global NSEvent monitors, and they report key-up, which
/// hold-to-talk needs.
final class HotKey {
    private static let signature = OSType(0x4D52_4D52) // 'MRMR'
    private static var nextID: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let id: UInt32
    private let onPress: () -> Void
    private let onRelease: (() -> Void)?

    /// - Parameters:
    ///   - keyCode: A virtual key code such as `kVK_ANSI_D`.
    ///   - modifiers: Carbon modifier flags such as `cmdKey | optionKey`, or 0.
    init?(keyCode: Int, modifiers: Int, onPress: @escaping () -> Void, onRelease: (() -> Void)? = nil) {
        self.onPress = onPress
        self.onRelease = onRelease
        id = Self.nextID
        Self.nextID += 1

        var eventTypes = [kEventHotKeyPressed, kEventHotKeyReleased].map {
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32($0))
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            return Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().handle(event)
        }, eventTypes.count, &eventTypes, context, &handlerRef)
        guard installed == noErr else { return nil }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        let registered = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        guard registered == noErr else {
            RemoveEventHandler(handlerRef)
            return nil
        }
    }

    private func handle(_ event: EventRef) -> OSStatus {
        var hit = EventHotKeyID()
        let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                       nil, MemoryLayout<EventHotKeyID>.size, nil, &hit)
        // Every HotKey's handler sees every hot key event; pass on the ones that aren't ours.
        guard status == noErr, hit.signature == Self.signature, hit.id == id else { return OSStatus(eventNotHandledErr) }
        if GetEventKind(event) == UInt32(kEventHotKeyPressed) { onPress() } else { onRelease?() }
        return noErr
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
