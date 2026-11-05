import Foundation

public struct VocabularyEntry: Codable, Identifiable, Equatable {
    public var id: UUID
    public var heard: String
    public var replacement: String
    public init(id: UUID = UUID(), heard: String, replacement: String) {
        self.id = id; self.heard = heard; self.replacement = replacement
    }
}

public enum TextProcessor {
    public static func process(_ input: String, vocabulary: [VocabularyEntry], removeFillers: Bool) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Replace longest phrases first, once per original span. Replacements never cascade.
        let entries = vocabulary.filter { !$0.heard.trimmingCharacters(in: .whitespaces).isEmpty && !$0.replacement.isEmpty }
            .sorted { $0.heard.count > $1.heard.count }
        if !entries.isEmpty {
            let pattern = "(?<![\\p{L}\\p{N}_])(?:" + entries.map { NSRegularExpression.escapedPattern(for: $0.heard) }.joined(separator: "|") + ")(?![\\p{L}\\p{N}_])"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
                    guard let range = Range(match.range, in: text), let entry = entries.first(where: { $0.heard.caseInsensitiveCompare(String(text[range])) == .orderedSame }) else { continue }
                    text.replaceSubrange(range, with: entry.replacement)
                }
            }
        }
        if removeFillers {
            text = text.replacingOccurrences(of: "(?i)(?<![\\p{L}\\p{N}_])(?:um|uh|erm)(?![\\p{L}\\p{N}_])[, ]*", with: "", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: " +([,.!?;:])", with: "$1", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public struct Transcript: Codable, Identifiable {
    public var id: UUID
    public var date: Date
    public var text: String
    public var seconds: Double
    public var app: String
    public var words: Int { text.split(whereSeparator: { $0.isWhitespace }).count }
    public init(text: String, seconds: Double, app: String) {
        self.id = UUID(); self.date = Date(); self.text = text; self.seconds = seconds; self.app = app
    }
}
