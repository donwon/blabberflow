import SwiftUI
import FlowCore

final class Store: ObservableObject {
    @Published var history: [Transcript] = []
    @Published var vocabulary: [VocabularyEntry] = []
    @Published var saveHistory = false { didSet { UserDefaults.standard.set(saveHistory, forKey: "saveHistory") } }
    @Published var removeFillers = false { didSet { UserDefaults.standard.set(removeFillers, forKey: "removeFillers") } }
    @Published var localOnly = false { didSet { UserDefaults.standard.set(localOnly, forKey: "localOnly") } }
    @Published var autoInsert = true { didSet { UserDefaults.standard.set(autoInsert, forKey: "autoInsert") } }
    @Published var locale = "en-CA" { didSet { UserDefaults.standard.set(locale, forKey: "locale") } }
    @Published var shortcut: DictationShortcut = .recommended { didSet { UserDefaults.standard.set(shortcut.rawValue, forKey: "holdDictationShortcut") } }
    @Published var storageError = ""
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WhisperFlow", isDirectory: true)
        let d = UserDefaults.standard
        saveHistory = d.bool(forKey: "saveHistory"); removeFillers = d.bool(forKey: "removeFillers"); localOnly = d.bool(forKey: "localOnly")
        autoInsert = d.object(forKey: "autoInsert") == nil ? true : d.bool(forKey: "autoInsert")
        locale = d.string(forKey: "locale") ?? "en-CA"
        if d.integer(forKey: "modifierShortcutPickerVersion") < 1 {
            // Requested migration from the previous three-key default. Future
            // launches preserve the combination chosen in the new settings UI.
            shortcut = .recommended
            d.set(shortcut.rawValue, forKey: "holdDictationShortcut")
            d.set(1, forKey: "modifierShortcutPickerVersion")
        } else {
            let saved = DictationShortcut(rawValue: d.string(forKey: "holdDictationShortcut") ?? "")
            shortcut = saved?.isModifierOnly == true ? saved! : .recommended
        }
        do {
            try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            history = try read([Transcript].self, "history.json") ?? []
            vocabulary = try read([VocabularyEntry].self, "vocabulary.json") ?? []
        } catch { storageError = "Could not read local data: \(error.localizedDescription)" }
    }
    private func read<T: Decodable>(_ type: T.Type, _ name: String) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }
    private func write<T: Encodable>(_ value: T, _ name: String) {
        do {
            let url = directory.appendingPathComponent(name)
            try JSONEncoder().encode(value).write(to: url, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            storageError = ""
        } catch { storageError = "Could not save local data: \(error.localizedDescription)" }
    }
    func add(_ item: Transcript) {
        guard saveHistory else { return }
        history.insert(item, at: 0); history = Array(history.prefix(200)); write(history, "history.json")
    }
    func delete(_ id: UUID) { history.removeAll { $0.id == id }; write(history, "history.json") }
    func clear() { history = []; write(history, "history.json") }
    func addWord(_ heard: String, _ replacement: String) {
        let heard = heard.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !heard.isEmpty, !replacement.isEmpty else { return }
        vocabulary.removeAll { $0.heard.caseInsensitiveCompare(heard) == .orderedSame }
        vocabulary.append(VocabularyEntry(heard: heard, replacement: replacement)); write(vocabulary, "vocabulary.json")
    }
    func deleteWord(_ id: UUID) { vocabulary.removeAll { $0.id == id }; write(vocabulary, "vocabulary.json") }
}
