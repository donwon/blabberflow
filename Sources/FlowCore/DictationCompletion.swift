import Foundation

/// Keeps recognition completion separate from the user's release gesture.
public struct DictationCompletion {
    public enum Action: Equatable {
        case waitForRecognition, waitForRelease, waitForModifiers, deliver, copyOnly
    }
    public private(set) var shortcutHeld: Bool
    public private(set) var transcriptReady = false
    private var modifierWaitStarted: Date?

    public init(holdToTalk: Bool) { shortcutHeld = holdToTalk }
    public mutating func release() { shortcutHeld = false }
    public mutating func markTranscriptReady() { transcriptReady = true }

    public mutating func action(modifiersDown: Bool, now: Date) -> Action {
        guard transcriptReady else { return .waitForRecognition }
        guard !shortcutHeld else { return .waitForRelease }
        guard modifiersDown else { return .deliver }
        if modifierWaitStarted == nil { modifierWaitStarted = now }
        // Never inject Cmd-V with physical Ctrl/Shift/Option still held. Keep
        // a recoverable copy if keys remain down rather than pasting much later.
        return now.timeIntervalSince(modifierWaitStarted!) >= 5 ? .copyOnly : .waitForModifiers
    }
}
