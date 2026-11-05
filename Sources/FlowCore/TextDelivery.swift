import Foundation

public protocol TextDestination {
    var isCurrent: Bool { get }
    var isSecure: Bool { get }
    var acceptsPaste: Bool { get }
    var prefersPaste: Bool { get }
    func replaceSelection(with text: String) -> Bool
    func requestPaste() -> Bool
}

public extension TextDestination {
    var prefersPaste: Bool { false }
}

public enum DeliveryOutcome: Equatable {
    case inserted, pasteRequested, copied
}

public enum TextDelivery {
    public static func deliver(_ text: String, to destination: TextDestination?, copy: (String) -> Void) -> DeliveryOutcome {
        guard let destination = destination, destination.isCurrent, !destination.isSecure else {
            copy(text); return .copied
        }
        // Chromium can acknowledge AXSelectedText without applying it. Pick the
        // paste route before attempting that setter, so there is no false success
        // or duplicate insertion from retrying after an ambiguous acknowledgement.
        if !destination.prefersPaste && destination.replaceSelection(with: text) { return .inserted }
        // Many browser editors expose selected text as read-only. Use their normal Paste action.
        copy(text)
        guard destination.isCurrent, !destination.isSecure, destination.acceptsPaste,
              destination.requestPaste() else { return .copied }
        return .pasteRequested
    }
}
