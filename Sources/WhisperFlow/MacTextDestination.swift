import AppKit
import Carbon.HIToolbox
import FlowCore

struct MacTextDestination: TextDestination {
    let app: NSRunningApplication
    let element: AXUIElement
    private static var preparedProcesses = Set<pid_t>()

    static func capture() -> MacTextDestination? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        prepareAccessibility(in: app)
        guard let element = focusedElement(in: app) else { return nil }
        return MacTextDestination(app: app, element: element)
    }
    private static func prepareAccessibility(in app: NSRunningApplication) {
        guard !preparedProcesses.contains(app.processIdentifier) else { return }
        guard let attribute = accessibilityActivationAttribute(in: app) else { return }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(application, 0.4)
        if AXUIElementSetAttributeValue(application, attribute as CFString, kCFBooleanTrue) == .success {
            // A busy renderer can reject activation temporarily. Cache successes only,
            // so capture can retry while recording in the original destination app.
            preparedProcesses.insert(app.processIdentifier)
        }
    }
    private static func accessibilityActivationAttribute(in app: NSRunningApplication) -> String? {
        let info = app.bundleURL.flatMap { Bundle(url: $0)?.infoDictionary } ?? [:]
        let electron = app.bundleURL.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("Contents/Frameworks/Electron Framework.framework").path) } ?? false
        return accessibilityActivationAttribute(bundleIdentifier: app.bundleIdentifier, info: info, hasElectronFramework: electron)
    }
    static func accessibilityActivationAttribute(bundleIdentifier: String?, info: [String: Any], hasElectronFramework: Bool) -> String? {
        if hasElectronFramework { return "AXManualAccessibility" }
        // Chromium-derived apps can rename their framework. Codex ships "Codex
        // Framework.framework" and identifies its engine with ChromiumBaseVersion.
        if let version = info["ChromiumBaseVersion"] as? String, !version.isEmpty {
            return "AXEnhancedUserInterface"
        }
        if ["com.google.Chrome", "com.google.Chrome.canary", "com.microsoft.edgemac", "com.brave.Browser"].contains(bundleIdentifier ?? "") {
            return "AXEnhancedUserInterface"
        }
        return nil
    }
    private static func focusedElement(in app: NSRunningApplication) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedUIElementAttribute as CFString, &value) == .success,
              let value = value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        var element = value as! AXUIElement
        for _ in 0..<4 {
            var nested: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, kAXFocusedUIElementAttribute as CFString, &nested) == .success,
                  let nested = nested, CFGetTypeID(nested) == AXUIElementGetTypeID(), !CFEqual(element, nested) else { break }
            element = nested as! AXUIElement
        }
        return element
    }
    private func stringAttribute(_ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }
    var isCurrent: Bool {
        guard AXIsProcessTrusted(), !app.isTerminated,
              NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              let current = Self.focusedElement(in: app) else { return false }
        return CFEqual(element, current)
    }
    var isSecure: Bool { stringAttribute(kAXSubroleAttribute) == kAXSecureTextFieldSubrole }
    var role: String { stringAttribute(kAXRoleAttribute) ?? "unknown" }
    var prefersPaste: Bool { Self.accessibilityActivationAttribute(in: app) != nil }
    var acceptsPaste: Bool {
        guard !isSecure else { return false }
        // Never send Command-V to arbitrary buttons, windows, or web page containers.
        return [kAXTextFieldRole, kAXTextAreaRole, kAXComboBoxRole, "AXSearchField"].contains(role)
    }
    func replaceSelection(with text: String) -> Bool {
        guard !prefersPaste, isCurrent, !isSecure else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFString) == .success
    }
    func requestPaste() -> Bool {
        guard isCurrent, acceptsPaste,
              let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else { return false }
        down.flags = .maskCommand; up.flags = .maskCommand
        // Address the captured process rather than broadcasting to whichever app gains focus next.
        down.postToPid(app.processIdentifier); up.postToPid(app.processIdentifier)
        return true
    }
}
