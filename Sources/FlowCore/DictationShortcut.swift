public enum DictationShortcut: String, CaseIterable, Identifiable {
    case function
    case controlShift, optionShift, controlCommand, optionCommand
    case controlOptionShift, optionCommandShift, controlOptionCommand
    case controlCommandShift, controlShiftSpace, commandOptionShiftSpace, controlShiftD
    public var id: String { rawValue }
    public static let recommended: Self = .controlShift
    public var isModifierOnly: Bool {
        ![Self.controlShiftSpace, .commandOptionShiftSpace, .controlShiftD].contains(self)
    }
    public var modifiers: ShortcutModifiers {
        switch self {
        case .function: return [.function]
        case .controlShift, .controlShiftSpace, .controlShiftD: return [.control, .shift]
        case .optionShift: return [.option, .shift]
        case .controlCommand: return [.control, .command]
        case .optionCommand: return [.option, .command]
        case .controlOptionShift: return [.control, .option, .shift]
        case .optionCommandShift, .commandOptionShiftSpace: return [.option, .command, .shift]
        case .controlOptionCommand: return [.control, .option, .command]
        case .controlCommandShift: return [.control, .shift, .command]
        }
    }
    public static func modifierShortcut(for modifiers: ShortcutModifiers) -> Self? {
        allCases.first { $0.isModifierOnly && $0.modifiers == modifiers }
    }
    public static func validationMessage(for modifiers: ShortcutModifiers) -> String? {
        if modifiers == [.control, .option] { return "Control + Option is used by VoiceOver. Choose another combination." }
        if modifiers == [.command, .shift] { return "Command + Shift is common in Mac shortcuts. Include Control or Option instead." }
        if modifierShortcut(for: modifiers) == nil { return "Choose Fn / Globe alone, or two or three of the other modifier keys." }
        return nil
    }
    public var displayName: String {
        if self == .function { return "Fn / Globe" }
        let names: [(ShortcutModifiers, String)] = [(.control, "Control"), (.option, "Option"), (.shift, "Shift"), (.command, "Command")]
        let suffix = isModifierOnly ? [] : [self == .controlShiftD ? "D" : "Space"]
        return (names.filter { modifiers.contains($0.0) }.map { $0.1 } + suffix).joined(separator: " + ")
    }
    public var label: String {
        if self == .function { return "fn" }
        if isModifierOnly {
            let symbols: [(ShortcutModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
            return symbols.filter { modifiers.contains($0.0) }.map { $0.1 }.joined()
        }
        switch self {
        case .controlShiftSpace: return "⌃⇧Space"
        case .commandOptionShiftSpace: return "⌘⌥⇧Space"
        case .controlShiftD: return "⌃⇧D"
        default: return ""
        }
    }
}
