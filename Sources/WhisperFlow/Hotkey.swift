import AppKit
import Carbon
import FlowCore

final class Hotkey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var releaseTimer: Timer?
    private var armingTimer: Timer?
    private var shortcut: DictationShortcut?
    private var modifierState = ModifierShortcutHoldState()
    private var keyState = KeyShortcutHoldState()
    private var generation: UInt = 0
    private var callbackHeld = false
    private var pendingCancellation = false
    var onPress: (() -> Void)?
    var onRelease: (() -> Void)?
    var onCancel: (() -> Void)?

    func register(_ shortcut: DictationShortcut) -> Bool {
        let shouldCancel = pendingCancellation
        let wasHeld = removeBinding()
        if wasHeld { if shouldCancel { onCancel?() } else { onRelease?() } }
        self.shortcut = shortcut
        if shortcut.isModifierOnly {
            guard AXIsProcessTrusted() else { self.shortcut = nil; return false }
            modifierState = ModifierShortcutHoldState(required: shortcut.modifiers, initialModifiers: Self.modifiers(from: NSEvent.modifierFlags))
            let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .systemDefined]
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                self?.handleObservedEvent(event)
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                self?.handleObservedEvent(event)
                return event // Observe only; the front app keeps its normal keyboard behavior.
            }
            guard globalMonitor != nil && localMonitor != nil else { _ = removeBinding(); return false }
            updateReleaseTimer()
            return true
        }

        let key = Self.keyCode(for: shortcut)
        keyState = KeyShortcutHoldState(initiallyDown: CGEventSource.keyState(.combinedSessionState, key: key))
        var events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event = event, let context = context else { return OSStatus(eventNotHandledErr) }
            let owner = Unmanaged<Hotkey>.fromOpaque(context).takeUnretainedValue()
            let kind = GetEventKind(event)
            guard kind == UInt32(kEventHotKeyPressed) || kind == UInt32(kEventHotKeyReleased) else { return OSStatus(eventNotHandledErr) }
            owner.handleKey(isDown: kind == UInt32(kEventHotKeyPressed))
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { _ = removeBinding(); return false }
        let id = EventHotKeyID(signature: 0x57464C57, id: 1)
        let modifiers = shortcut == .commandOptionShiftSpace ? cmdKey | optionKey | shiftKey : controlKey | shiftKey
        // Exclusive registration makes conflicts visible instead of invoking multiple handlers.
        guard RegisterEventHotKey(UInt32(key), UInt32(modifiers), id, GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference) == noErr else {
            _ = removeBinding(); return false
        }
        updateReleaseTimer()
        return true
    }

    static func modifiers(from flags: NSEvent.ModifierFlags) -> ShortcutModifiers {
        var modifiers: ShortcutModifiers = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.function) { modifiers.insert(.function) }
        // Caps Lock and device-specific flags do not change the shortcut.
        return modifiers
    }

    private static func keyCode(for shortcut: DictationShortcut) -> CGKeyCode {
        CGKeyCode(shortcut == .controlShiftD ? kVK_ANSI_D : kVK_Space)
    }

    /// Only a boolean is retained; typed characters and key identities are never recorded.
    static func hasNonModifierKeyDown(
        isDown: (CGKeyCode) -> Bool = { CGEventSource.keyState(.combinedSessionState, key: $0) }
    ) -> Bool {
        let modifierKeys = Set([kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
                                kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
                                kVK_CapsLock, kVK_Function].map(CGKeyCode.init))
        return (0..<128).contains { key in
            let code = CGKeyCode(key)
            return !modifierKeys.contains(code) && isDown(code)
        }
    }

    private func handleObservedEvent(_ event: NSEvent) {
        if event.type == .flagsChanged {
            handleModifiers(event.modifierFlags)
        } else {
            // Letters, arrows, and system/media keys belong to the user's normal
            // shortcut. Cancel dictation without consuming or inspecting them.
            let flags = event.type == .systemDefined ? NSEvent.modifierFlags : event.modifierFlags
            handleModifiers(flags, mayStart: false, nonModifierDown: true)
        }
    }

    private func handleModifiers(_ flags: NSEvent.ModifierFlags, mayStart: Bool = true, nonModifierDown: Bool? = nil) {
        guard shortcut?.isModifierOnly == true else { return }
        dispatchTransition(modifierState.update(Self.modifiers(from: flags), mayStart: mayStart,
                                               nonModifierDown: nonModifierDown ?? Self.hasNonModifierKeyDown()))
        updateArmingTimer()
        updateReleaseTimer()
    }
    private func handleKey(isDown: Bool, mayStart: Bool = true) {
        guard shortcut?.isModifierOnly == false else { return }
        dispatchTransition(keyState.update(isDown: isDown, mayStart: mayStart))
        updateReleaseTimer()
    }
    func dispatchTransition(_ transition: ShortcutHoldTransition?) {
        guard let transition = transition else { return }
        if transition == .cancelled { pendingCancellation = true }
        let expectedGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.generation == expectedGeneration else { return }
            if transition == .pressed {
                self.callbackHeld = true
                self.onPress?()
            } else if self.callbackHeld {
                self.callbackHeld = false
                if transition == .cancelled {
                    self.pendingCancellation = false
                    self.onCancel?()
                } else {
                    self.onRelease?()
                }
            }
        }
    }

    private func updateArmingTimer() {
        armingTimer?.invalidate(); armingTimer = nil
        guard let deadline = modifierState.armingDeadline else { return }
        let expectedGeneration = generation
        let timer = Timer(timeInterval: max(0.001, deadline - ProcessInfo.processInfo.systemUptime), repeats: false) { [weak self] _ in
            guard let self = self, self.generation == expectedGeneration else { return }
            self.armingTimer = nil
            // Validate both the chord and any pre-held letter/arrow again before
            // starting. Merely pressing the modifiers is not enough.
            self.handleModifiers(NSEvent.modifierFlags)
        }
        armingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private func updateReleaseTimer() {
        let awaitsRelease = shortcut?.isModifierOnly == true ? modifierState.awaitsFullRelease : keyState.awaitsFullRelease
        if !awaitsRelease { releaseTimer?.invalidate(); releaseTimer = nil; return }
        guard releaseTimer == nil else { return }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let shortcut = self.shortcut else { return }
            // Recover a lost release event. Polling is never allowed to begin a recording.
            if shortcut.isModifierOnly {
                self.handleModifiers(NSEvent.modifierFlags, mayStart: false)
            } else {
                self.handleKey(isDown: CGEventSource.keyState(.combinedSessionState, key: Self.keyCode(for: shortcut)), mayStart: false)
            }
        }
        releaseTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    @discardableResult private func removeBinding() -> Bool {
        // A queued release may not have reached the controller yet. Match the
        // callback it actually received, even if physical hold state is already up.
        let wasHeld = callbackHeld
        callbackHeld = false
        pendingCancellation = false
        generation &+= 1
        releaseTimer?.invalidate(); releaseTimer = nil
        armingTimer?.invalidate(); armingTimer = nil
        if let reference = reference { UnregisterEventHotKey(reference); self.reference = nil }
        if let handler = handler { RemoveEventHandler(handler); self.handler = nil }
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor); globalMonitor = nil }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor); localMonitor = nil }
        shortcut = nil
        modifierState = ModifierShortcutHoldState(); keyState = KeyShortcutHoldState()
        return wasHeld
    }
    deinit { removeBinding() }
}
