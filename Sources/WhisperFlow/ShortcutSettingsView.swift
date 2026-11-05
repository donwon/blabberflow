import SwiftUI
import FlowCore

struct ShortcutSettingsView: View {
    @ObservedObject var store: Store
    let busy: Bool
    @State private var selected: ShortcutModifiers = []
    private let keys: [(ShortcutModifiers, String)] = [(.control, "Control ⌃"), (.option, "Option ⌥"), (.shift, "Shift ⇧"), (.command, "Command ⌘")]

    private var proposed: DictationShortcut? { DictationShortcut.modifierShortcut(for: selected) }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Hold-to-talk shortcut").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text(store.shortcut.label).font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 10).padding(.vertical, 6).background(Color.primary.opacity(0.05)).cornerRadius(5)
                    .accessibilityLabel("Current shortcut: \(store.shortcut.displayName)")
            }
            Text("Choose Fn / Globe alone, or two or three modifier keys. Control + Shift is recommended.")
                .font(.system(size: 12)).foregroundColor(.secondary)
            HStack(spacing: 20) {
                ForEach(keys.indices, id: \.self) { index in
                    Toggle(keys[index].1, isOn: Binding(get: { selected.contains(keys[index].0) }, set: { enabled in
                        if enabled { selected.remove(.function); selected.insert(keys[index].0) } else { selected.remove(keys[index].0) }
                    })).toggleStyle(.checkbox)
                }
            }.disabled(busy)
            Toggle("Use Fn / Globe by itself", isOn: Binding(get: { selected == [.function] }, set: { enabled in
                selected = enabled ? [.function] : DictationShortcut.recommended.modifiers
            })).toggleStyle(.checkbox).disabled(busy)
            if selected == [.function] {
                Text("If Fn also opens emoji or Apple Dictation, go to System Settings → Keyboard and set ‘Press Fn / Globe key to’ to ‘Do Nothing’. Check the Dictation shortcut there too. Blabberflow leaves your Mac settings unchanged.")
                    .font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Open Keyboard Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") { NSWorkspace.shared.open(url) }
                }
            }
            if let reason = DictationShortcut.validationMessage(for: selected) {
                Text(reason).font(.system(size: 12)).foregroundColor(.secondary)
            } else if let proposed = proposed {
                Text("Hold \(proposed.displayName) until Listening appears. Speak, then release to insert.").font(.system(size: 12)).foregroundColor(.secondary)
            }
            HStack {
                Button("Apply shortcut") { if let proposed = proposed { store.shortcut = proposed } }
                    .disabled(busy || proposed == nil || proposed == store.shortcut)
                Button("Use Control + Shift") { selected = DictationShortcut.recommended.modifiers; store.shortcut = .recommended }
                    .disabled(busy || store.shortcut == .recommended && selected == DictationShortcut.recommended.modifiers)
            }
            Text("Mac shortcuts keep working. Adding a letter, arrow, or other key cancels dictation without inserting. Other apps may use the same modifier keys; choose a different combination if needed.")
                .font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
        }.onAppear { selected = store.shortcut.modifiers }
    }
}
