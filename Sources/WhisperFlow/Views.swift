import SwiftUI
import Speech
import FlowCore

private let ink = Color(red: 0.17, green: 0.16, blue: 0.20)
private let accent = Color(red: 0.40, green: 0.32, blue: 0.66)
private let canvas = Color(red: 0.985, green: 0.980, blue: 0.970)

private struct FlowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundColor(ink.opacity(isEnabled ? 0.9 : 0.35))
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(ink.opacity(configuration.isPressed ? 0.10 : 0.035))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ink.opacity(0.10), lineWidth: 1))
            .cornerRadius(6)
    }
}

struct MainView: View {
    @ObservedObject var controller: DictationController
    @ObservedObject var store: Store
    @State private var selection = "Home"
    @State private var heard = ""
    @State private var replacement = ""
    @State private var query = ""
    @State private var confirmClear = false
    @State private var copiedID: UUID?
    private let pages = [("Home", "house"), ("History", "clock.arrow.circlepath"), ("Vocabulary", "text.book.closed"), ("Settings", "slider.horizontal.3")]

    init(controller: DictationController, store: Store, initialPage: String = "Home") {
        self.controller = controller; self.store = store
        _selection = State(initialValue: initialPage)
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) { Image(systemName: "waveform").font(.title2).foregroundColor(accent); Text(AppIdentity.name).font(.system(size: 17, weight: .semibold)) }
                    .padding(.bottom, 32).padding(.top, 20)
                ForEach(pages, id: \.0) { page in
                    Button { selection = page.0; controller.refreshPermissions() } label: {
                        Label(page.0, systemImage: page.1).font(.system(size: 14, weight: selection == page.0 ? .semibold : .regular))
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 11)
                            .background(selection == page.0 ? accent.opacity(0.10) : Color.clear).cornerRadius(8)
                    }.buttonStyle(.plain).foregroundColor(selection == page.0 ? accent : ink.opacity(0.75))
                }
                Spacer()
                Divider().padding(.bottom, 12)
                Label("Your Mac. Your words.", systemImage: "laptopcomputer").font(.system(size: 11)).foregroundColor(.secondary)
                Text("Personal desktop edition").font(.system(size: 10)).foregroundColor(.secondary).padding(.leading, 20)
            }.padding(20).frame(width: 208).background(Color(red: 0.95, green: 0.94, blue: 0.93))
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack { Text(selection).font(.system(size: 28, weight: .semibold)); Spacer(); Label("No subscription", systemImage: "checkmark.circle").font(.system(size: 11)).foregroundColor(.secondary) }
                    switch selection {
                    case "History": history
                    case "Vocabulary": vocabulary
                    case "Settings": settings
                    default: home
                    }
                    if !store.storageError.isEmpty { Text(store.storageError).font(.callout).foregroundColor(.red) }
                }.padding(36).frame(maxWidth: 840, alignment: .leading).frame(maxWidth: .infinity)
            }.background(canvas)
        }.foregroundColor(ink).tint(accent).buttonStyle(FlowButtonStyle()).frame(minWidth: 860, minHeight: 610)
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in controller.refreshPermissions() }
            .confirmationDialog("Delete all saved transcripts? This cannot be undone.", isPresented: $confirmClear) { Button("Delete all history", role: .destructive) { store.clear() } }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your words, where you need them.").font(.system(size: 29, weight: .medium))
                Text("Hold your shortcut, speak, and release to write.").font(.system(size: 15)).foregroundColor(.secondary)
            }.padding(.top, 12)
            VStack(spacing: 20) {
                Image(systemName: controller.phase == .listening ? "waveform" : "mic.fill")
                    .font(.system(size: 32)).foregroundColor(accent).frame(width: 76, height: 76)
                    .background(accent.opacity(0.08)).clipShape(Circle())
                Text(controller.busy ? (controller.phase == .finishing ? "Finishing up…" : "Listening to you…") : (controller.accessibilityAllowed ? "Your voice, ready to go" : "Enable cross-app dictation")).font(.system(size: 20, weight: .medium))
                HStack(spacing: 6) { Text("Hold").foregroundColor(.secondary); Text(store.shortcut.label).font(.system(size: 13, weight: .semibold, design: .monospaced)).padding(.horizontal, 10).padding(.vertical, 6).background(ink.opacity(0.05)).cornerRadius(5); Text("to speak. Release to insert.").foregroundColor(.secondary) }.font(.system(size: 13))
                Button(action: controller.toggle) { Label(controller.busy ? "Finish dictation" : "Try dictation", systemImage: controller.busy ? "stop.fill" : "mic.fill").padding(.horizontal, 16).padding(.vertical, 8) }.buttonStyle(.borderedProminent).disabled(controller.phase == .finishing)
                if controller.busy { Button("Cancel dictation", role: .cancel, action: controller.cancel).buttonStyle(.plain).font(.caption) }
                if !controller.hotkeyAvailable { Text(controller.accessibilityAllowed ? "Shortcut unavailable. Choose another in Settings." : "Allow Accessibility below to enable the hold shortcut.").font(.callout).foregroundColor(.red) }
                Text(controller.message).font(.system(size: 12)).foregroundColor(.secondary).multilineTextAlignment(.center).textSelection(.enabled)
            }.padding(30).frame(maxWidth: .infinity).background(Color(red: 0.96, green: 0.95, blue: 0.98)).cornerRadius(14)

            if !controller.micAllowed || !controller.speechAllowed || !controller.accessibilityAllowed {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Set up cross-app dictation").font(.system(size: 16, weight: .semibold))
                    permissionRow("Microphone & speech", detail: "Needed to hear and transcribe you", ready: controller.micAllowed && controller.speechAllowed) { selection = "Settings"; controller.requestPermissions() }
                    permissionRow("Shortcut & text insertion", detail: "Allow Accessibility to hold the shortcut and write into other apps", ready: controller.accessibilityAllowed) { controller.requestAccessibility() }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Use it anywhere you write").font(.system(size: 16, weight: .semibold))
                    Text("Click a text field in Codex, Mail, Notes, Chrome, or another app. Hold \(store.shortcut.label) together while you speak, then release all the keys. Keep the field selected while your words are inserted. For hands-free recording, use Try dictation and the floating panel’s Finish button.").font(.system(size: 13)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !controller.lastText.isEmpty || !controller.liveText.isEmpty {
                Divider()
                HStack { Text(controller.busy ? "LIVE TRANSCRIPT" : "LATEST WORDS").font(.system(size: 10, weight: .semibold)).foregroundColor(.secondary); Spacer(); if !controller.lastText.isEmpty && !controller.busy { Button("Copy") { controller.copy(controller.lastText); controller.message = "Copied to clipboard" } } }
                Text(controller.busy ? controller.liveText : controller.lastText).font(.system(size: 15)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    private func permissionRow(_ title: String, detail: String, ready: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: ready ? "checkmark.circle.fill" : "circle").foregroundColor(ready ? accent : .secondary)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.system(size: 13, weight: .medium)); Text(detail).font(.system(size: 11)).foregroundColor(.secondary) }
            Spacer(); if !ready { Button("Enable", action: action) }
        }
    }
    private var history: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("Save transcripts on this Mac", isOn: $store.saveHistory).toggleStyle(.switch)
            Text("History is optional and keeps up to 200 dictations. Audio is never saved by this app. Turning history off stops new saves; existing entries remain until you delete them.").font(.callout).foregroundColor(.secondary)
            HStack { TextField("Search your words", text: $query).textFieldStyle(.roundedBorder); Button("Delete all…", role: .destructive) { confirmClear = true }.disabled(store.history.isEmpty) }
            if store.history.isEmpty {
                empty("Your words will live here", symbol: "text.alignleft", detail: "Turn on history, then finish a dictation to keep a copy here.")
            } else {
                let filtered = store.history.filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
                if filtered.isEmpty { Text("No transcripts match your search.").foregroundColor(.secondary) }
                ForEach(filtered) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(item.date, style: .date); Text(item.date, style: .time); Spacer(); Text(item.app) }.font(.system(size: 11)).foregroundColor(.secondary)
                        Text(item.text).font(.system(size: 14)).textSelection(.enabled)
                        HStack { Text("\(item.words) words · \(Int(item.seconds)) sec").font(.caption).foregroundColor(.secondary); Spacer(); Button(copiedID == item.id ? "Copied" : "Copy") { controller.copy(item.text); copiedID = item.id }; Button("Delete", role: .destructive) { store.delete(item.id) } }
                        Divider().padding(.top, 8)
                    }
                }
            }
        }
    }
    private var vocabulary: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Names, places, and words you use.").font(.system(size: 20, weight: .medium))
            Text("Teach the app how to write a name or phrase. For example, replace “realty os” with “RealtyOS”. Added terms also help guide speech recognition.").font(.callout).foregroundColor(.secondary)
            HStack { TextField("When it hears…", text: $heard); Image(systemName: "arrow.right").foregroundColor(.secondary); TextField("Write this…", text: $replacement); Button("Add") { store.addWord(heard, replacement); heard = ""; replacement = "" }.disabled(heard.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || replacement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.textFieldStyle(.roundedBorder)
            Divider()
            if store.vocabulary.isEmpty { empty("A little more like you", symbol: "text.book.closed", detail: "Add a name, a business, or a phrase that dictation often misses.") }
            ForEach(store.vocabulary) { entry in
                HStack { Text(entry.heard).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading); Image(systemName: "arrow.right").foregroundColor(.secondary); Text(entry.replacement).frame(maxWidth: .infinity, alignment: .leading); Button { store.deleteWord(entry.id) } label: { Image(systemName: "trash") }.help("Delete \(entry.heard)") }; Divider()
            }
        }
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 20) {
            Group {
            ShortcutSettingsView(store: store, busy: controller.busy)
            if !controller.hotkeyAvailable { Text(controller.accessibilityAllowed ? "This shortcut is unavailable. Choose another combination above. You can still record from the menu bar." : "Allow Accessibility below to enable the modifier-key shortcut.").font(.callout).foregroundColor(.red) }
            Text("Hold \(store.shortcut.displayName) briefly until Listening appears, then speak and release to insert. Recording stops after 55 seconds. Use the menu bar to cancel. Closing the window keeps the app running.").font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Group {
            Text("Dictation").font(.system(size: 18, weight: .semibold))
            HStack { Text("Language"); Spacer(); Picker("Language", selection: $store.locale) { ForEach(SFSpeechRecognizer.supportedLocales().map(\.identifier).sorted(), id: \.self) { id in Text(Locale.current.localizedString(forIdentifier: id) ?? id).tag(id) } }.labelsHidden().frame(width: 250) }.disabled(controller.busy)
            Toggle("Insert into the active text field", isOn: $store.autoInsert)
            Toggle("Remove fillers: um, uh, erm", isOn: $store.removeFillers)
            Toggle("Require on-device recognition", isOn: $store.localOnly).disabled(controller.busy)
            Text("With on-device only off, Apple may process audio on its servers. On-device availability depends on your Mac, language, and installed speech resources. This app does not send audio to its own server or save recordings.").font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Group {
            Text("Permissions").font(.system(size: 18, weight: .semibold))
            permissionRow("Microphone", detail: "Capture your voice", ready: controller.micAllowed) { if AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined { controller.requestPermissions() } else { controller.openPrivacy("Microphone") } }
            permissionRow("Speech recognition", detail: "Turn speech into words", ready: controller.speechAllowed) { if SFSpeechRecognizer.authorizationStatus() == .notDetermined { controller.requestPermissions() } else { controller.openPrivacy("SpeechRecognition") } }
            permissionRow("Accessibility", detail: "Enable the hold shortcut and insert words into another app", ready: controller.accessibilityAllowed, action: controller.requestAccessibility)
            Button("Refresh permission status", action: controller.refreshPermissions)
            }
            Divider()
            Text("\(AppIdentity.name) \(AppIdentity.version) · Personal dictation for Mac\nUses Apple Speech. Chrome extension and mobile app are future work.").font(.system(size: 11)).foregroundColor(.secondary)
        }.toggleStyle(.switch)
    }
    private func empty(_ title: String, symbol: String, detail: String) -> some View {
        VStack(spacing: 14) { Image(systemName: symbol).font(.system(size: 28)).foregroundColor(accent); Text(title).font(.system(size: 18, weight: .medium)); Text(detail).font(.callout).foregroundColor(.secondary).multilineTextAlignment(.center) }.frame(maxWidth: .infinity).padding(.vertical, 55)
    }
}

import AVFoundation

struct RecordingView: View {
    @ObservedObject var controller: DictationController
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: controller.busy ? "waveform" : "text.bubble").foregroundColor(.purple)
            if controller.busy {
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.phase == .finishing ? "Finishing…" : "Listening · \(controller.elapsed)s").font(.system(size: 13, weight: .semibold))
                    Text(controller.destinationLabel).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                    ProgressView(value: Double(controller.level)).progressViewStyle(.linear).frame(width: 170).accessibilityLabel("Microphone level")
                }
                Spacer()
                Button(action: controller.stop) { Image(systemName: "stop.fill") }.help("Finish dictation").disabled(controller.phase != .listening)
                Button(action: controller.cancel) { Image(systemName: "xmark") }.help("Cancel dictation")
            } else {
                Text(controller.message).font(.system(size: 12)).lineLimit(4).frame(maxWidth: .infinity, alignment: .leading)
                if !controller.lastText.isEmpty { Button("Copy") { controller.copy(controller.lastText) } }
            }
        }.padding(16).frame(width: 388, height: 68).background(Color(red: 0.97, green: 0.96, blue: 0.98)).cornerRadius(16)
    }
}
