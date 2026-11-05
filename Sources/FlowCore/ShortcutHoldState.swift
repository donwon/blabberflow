import Foundation

public enum ShortcutHoldTransition: Equatable { case pressed, released, cancelled }

public struct ShortcutModifiers: OptionSet {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let control = Self(rawValue: 1 << 0)
    public static let shift = Self(rawValue: 1 << 1)
    public static let command = Self(rawValue: 1 << 2)
    public static let option = Self(rawValue: 1 << 3)
    public static let function = Self(rawValue: 1 << 4)
}

/// A deliberate modifier-only hold, leaving ordinary keyboard shortcuts alone.
public struct ModifierShortcutHoldState {
    /// Kept as the legacy three-key preset; each instance can choose its own chord.
    public static let required: ShortcutModifiers = [.control, .shift, .command]
    public static let activationDelay: TimeInterval = 0.3
    public let requiredModifiers: ShortcutModifiers
    private enum Phase { case ready, arming(TimeInterval), held, awaitingRelease }
    private var phase: Phase
    public var isHeld: Bool { if case .held = phase { return true }; return false }
    public var armingDeadline: TimeInterval? {
        if case let .arming(started) = phase { return started + Self.activationDelay }
        return nil
    }
    public var awaitsFullRelease: Bool { if case .ready = phase { return false }; return true }

    public init(required: ShortcutModifiers = Self.required, initialModifiers: ShortcutModifiers = []) {
        requiredModifiers = required
        // Registering while keys are down must never create an accidental recording.
        phase = initialModifiers.intersection(required).isEmpty ? .ready : .awaitingRelease
    }

    public mutating func update(
        _ modifiers: ShortcutModifiers,
        mayStart: Bool = true,
        nonModifierDown: Bool = false,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> ShortcutHoldTransition? {
        guard !requiredModifiers.isEmpty else { return nil }
        let allReleased = modifiers.intersection(requiredModifiers).isEmpty
        let hasExtraModifier = !modifiers.subtracting(requiredModifiers).isEmpty
        let exactChord = modifiers == requiredModifiers
        switch phase {
        case .ready:
            // A prefix of an ordinary shortcut remains suppressed even after
            // its letter/arrow/extra modifier is released.
            if !allReleased && (nonModifierDown || hasExtraModifier) {
                phase = .awaitingRelease
            } else if mayStart && exactChord {
                phase = .arming(now)
            }
        case let .arming(started):
            if nonModifierDown || hasExtraModifier || !exactChord {
                phase = allReleased ? .ready : .awaitingRelease
            } else if mayStart && now >= started + Self.activationDelay {
                phase = .held
                return .pressed
            }
        case .held:
            if nonModifierDown || hasExtraModifier {
                phase = allReleased ? .ready : .awaitingRelease
                return .cancelled
            }
            if !exactChord {
                phase = allReleased ? .ready : .awaitingRelease
                return .released
            }
        case .awaitingRelease:
            if allReleased { phase = .ready }
        }
        return nil
    }
}

/// Carbon can repeat its pressed event; callbacks still form a single down/up pair.
public struct KeyShortcutHoldState {
    private enum Phase { case ready, held, awaitingRelease }
    private var phase: Phase
    public var isHeld: Bool { phase == .held }
    public var awaitsFullRelease: Bool { phase != .ready }
    public init(initiallyDown: Bool = false) { phase = initiallyDown ? .awaitingRelease : .ready }
    public mutating func update(isDown: Bool, mayStart: Bool = true) -> ShortcutHoldTransition? {
        if isDown {
            guard phase == .ready && mayStart else { return nil }
            phase = .held; return .pressed
        }
        let wasHeld = phase == .held
        phase = .ready
        return wasHeld ? .released : nil
    }
}
