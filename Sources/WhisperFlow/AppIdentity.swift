import Foundation

enum AppIdentity {
    static var name: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Dictation" }
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development" }
}
