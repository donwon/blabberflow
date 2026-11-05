import AppKit
import AVFoundation
import Speech
import SwiftUI
import FlowCore

final class DictationController: ObservableObject {
    enum Phase: String { case idle, preparing, listening, finishing }
    @Published var phase: Phase = .idle
    @Published var liveText = ""
    @Published var lastText = ""
    @Published var message = "Ready when you are"
    @Published var elapsed = 0
    @Published var level: Float = 0
    @Published var micAllowed = false
    @Published var speechAllowed = false
    @Published var accessibilityAllowed = false
    @Published var hotkeyAvailable = true
    @Published var destinationLabel = "Select a text field"
    let store: Store
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var timer: Timer?
    private var finishTimer: Timer?
    private var deliveryTimer: Timer?
    private var completion = DictationCompletion(holdToTalk: false)
    private var holdToTalk = false
    private var shortcutOwnsSession = false
    private var deliveryMethod = "none"
    private var deliveryOutcome = "none"
    private var session: UUID?
    private var target: NSRunningApplication?
    private var destination: MacTextDestination?
    private var started = Date()
    private var tapInstalled = false
    var onActivity: (() -> Void)?

    init(store: Store) { self.store = store; refreshPermissions() }
    var busy: Bool { phase != .idle }
    func refreshPermissions() {
        let microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        let speech = SFSpeechRecognizer.authorizationStatus() == .authorized
        if micAllowed != microphone { micAllowed = microphone }
        if speechAllowed != speech { speechAllowed = speech }
        let trusted = AXIsProcessTrusted()
        if accessibilityAllowed != trusted { accessibilityAllowed = trusted }
    }
    func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            SFSpeechRecognizer.requestAuthorization { _ in DispatchQueue.main.async { self.refreshPermissions() } }
        }
    }
    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy("Accessibility")
    }
    func openPrivacy(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(pane)") { NSWorkspace.shared.open(url) }
    }
    func toggle() {
        switch phase {
        case .idle: start()
        case .listening: stop()
        case .preparing: cancel()
        case .finishing: break
        }
    }
    func shortcutPressed() {
        guard phase == .idle else { return }
        start(holdToTalk: true)
        shortcutOwnsSession = holdToTalk && busy
    }
    func shortcutReleased() {
        guard shortcutOwnsSession else { return }
        shortcutOwnsSession = false
        guard holdToTalk, busy else { return }
        completion.release()
        switch phase {
        case .listening: stop()
        case .preparing: cancel()
        case .finishing: deliverWhenReleased()
        case .idle: break
        }
    }
    func shortcutCancelled() {
        // Ignored presses cannot cancel a hands-free session or an earlier
        // dictation that is still finishing after its original keys were released.
        guard shortcutOwnsSession else { return }
        shortcutOwnsSession = false
        guard holdToTalk, busy else { return }
        cancel()
    }
    func start(holdToTalk: Bool = false) {
        guard phase == .idle else { return }
        refreshPermissions()
        guard micAllowed && speechAllowed else {
            message = "Enable Microphone and Speech Recognition in Settings, then try again."
            onActivity?(); requestPermissions(); return
        }
        // Report the cross-app blocker before the user spends time dictating.
        if holdToTalk && store.autoInsert && !accessibilityAllowed {
            message = "Enable Accessibility in \(AppIdentity.name) Settings to hold the shortcut and insert into other apps."
            onActivity?(); return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: store.locale)), recognizer.isAvailable else {
            message = "Speech recognition is unavailable. Check your connection or choose another language."; onActivity?(); return
        }
        guard !store.localOnly || recognizer.supportsOnDeviceRecognition else {
            message = "On-device recognition is unavailable for this language. Choose another language or turn off on-device only."; onActivity?(); return
        }
        self.holdToTalk = holdToTalk
        deliveryMethod = "none"; deliveryOutcome = "none"
        completion = DictationCompletion(holdToTalk: holdToTalk)
        captureDestination()
        let token = UUID(); session = token
        phase = .preparing; liveText = ""; elapsed = 0; level = 0; started = Date()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = store.localOnly
        request.addsPunctuation = true
        request.contextualStrings = Array(store.vocabulary.map(\.replacement).prefix(100))
        self.request = request
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0 && format.channelCount > 0 else {
            fail("No microphone input is available. Check Sound settings."); return
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) { sum += data[index] * data[index] }
            let rms = min(1, sqrt(sum / Float(buffer.frameLength)) * 8)
            DispatchQueue.main.async { if self?.session == token { self?.level = rms } }
        }
        tapInstalled = true
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self, self.session == token else { return }
                if let result = result { self.liveText = result.bestTranscription.formattedString }
                if result?.isFinal == true { self.finish(); return }
                if let error = error {
                    if self.phase == .finishing && !self.liveText.isEmpty { self.finish() }
                    else { self.fail("Dictation stopped: \(error.localizedDescription). Try again.") }
                }
            }
        }
        do {
            engine.prepare(); try engine.start()
            phase = .listening
            message = holdToTalk ? "Listening… Release \(store.shortcut.label) to insert." : "Listening… Click Finish dictation when you're done."
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                self.elapsed = Int(Date().timeIntervalSince(self.started))
                self.refreshDestination()
                if self.elapsed >= 55 { self.stop() }
            }
            onActivity?()
        } catch { fail("Could not start the microphone: \(error.localizedDescription)") }
    }
    func stop() {
        guard phase == .listening else { return }
        // A recording started from our window may acquire its destination after starting.
        // Freeze it at Stop, before recognition finishes; never pick an unrelated app later.
        refreshDestination()
        phase = .finishing; message = "Finishing your words…"
        stopAudio(); request?.endAudio()
        finishTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in self?.finish() }
        onActivity?()
    }
    func cancel() {
        guard busy else { return }
        cleanUp(); liveText = ""; message = "Dictation cancelled"; onActivity?()
    }
    private func stopAudio() {
        timer?.invalidate(); timer = nil
        engine.stop()
        if tapInstalled { engine.inputNode.removeTap(onBus: 0); tapInstalled = false }
    }
    private func cleanUp() {
        session = nil; stopAudio(); finishTimer?.invalidate(); finishTimer = nil
        deliveryTimer?.invalidate(); deliveryTimer = nil
        shortcutOwnsSession = false
        holdToTalk = false; completion = DictationCompletion(holdToTalk: false)
        task?.cancel(); task = nil; request = nil; phase = .idle; level = 0
    }
    private func fail(_ error: String) {
        // Keep recoverable partial text, but never insert an incomplete/error result automatically.
        let partial = TextProcessor.process(liveText, vocabulary: store.vocabulary, removeFillers: store.removeFillers)
        cleanUp()
        if !partial.isEmpty { lastText = partial }
        message = error + (partial.isEmpty ? "" : " Partial text is available to copy.")
        onActivity?()
    }
    private func finish() {
        guard busy else { return }
        if phase == .listening { refreshDestination() }
        stopAudio(); finishTimer?.invalidate(); finishTimer = nil
        phase = .finishing; completion.markTranscriptReady()
        deliverWhenReleased()
    }
    private func deliverWhenReleased() {
        guard busy else { return }
        let modifiers = CGEventSource.flagsState(.combinedSessionState)
        let blocking: CGEventFlags = [.maskCommand, .maskControl, .maskShift, .maskAlternate, .maskSecondaryFn]
        let action = completion.action(modifiersDown: !modifiers.intersection(blocking).isEmpty, now: Date())
        switch action {
        case .waitForRecognition: return
        case .waitForRelease:
            message = "Release \(store.shortcut.label) to insert your words."
            onActivity?(); return
        case .waitForModifiers:
            if deliveryTimer == nil {
                message = "Release the remaining shortcut keys to insert."
                let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.deliverWhenReleased() }
                deliveryTimer = timer; RunLoop.main.add(timer, forMode: .common)
                onActivity?()
            }
            return
        case .deliver, .copyOnly: break
        }
        let text = TextProcessor.process(liveText, vocabulary: store.vocabulary, removeFillers: store.removeFillers)
        let duration = Date().timeIntervalSince(started)
        cleanUp()
        guard !text.isEmpty else { message = "No speech detected. Try speaking closer to your microphone."; onActivity?(); return }
        lastText = text
        store.add(Transcript(text: text, seconds: duration, app: target?.localizedName ?? AppIdentity.name))
        let selectedDestination = store.autoInsert && action == .deliver ? destination : nil
        deliveryMethod = selectedDestination.map { $0.prefersPaste ? "clipboardPaste" : "accessibilityThenPaste" } ?? "copyOnly"
        let outcome = TextDelivery.deliver(text, to: selectedDestination, copy: copy)
        switch outcome {
        case .inserted:
            deliveryOutcome = "accessibilityAccepted"
            message = "Text sent to \(target?.localizedName ?? "your app")"
        case .pasteRequested:
            deliveryOutcome = "pasteSent"
            message = "Paste sent to \(target?.localizedName ?? "your app"). Your words are also on the clipboard."
        case .copied:
            deliveryOutcome = "copied"
            if action == .copyOnly { message = "Copied. A modifier key stayed held, so automatic paste was skipped. Release the keys and press ⌘V in your text field." }
            else if !store.autoInsert { message = "Copied. Turn on ‘Insert into the active text field’ in Settings for automatic insertion." }
            else if !AXIsProcessTrusted() { message = "Copied. Enable \(AppIdentity.name) in System Settings → Privacy & Security → Accessibility, then relaunch it. Press ⌘V to paste now." }
            else if let target = target, NSWorkspace.shared.frontmostApplication?.processIdentifier != target.processIdentifier {
                message = "Copied. Focus moved away from \(target.localizedName ?? "your app"). Return to its text field and press ⌘V."
            } else if destination == nil {
                message = "Copied. No text field was available in \(target?.localizedName ?? "another app"). Click the field, hold \(store.shortcut.label), speak, then release."
            } else { message = "Copied. The selected field changed or could not accept paste. Press ⌘V in your text field." }
        }
        onActivity?()
    }
    func copy(_ text: String) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }
    private func captureDestination() {
        target = NSWorkspace.shared.frontmostApplication
        if target?.processIdentifier == ProcessInfo.processInfo.processIdentifier { target = nil }
        destination = MacTextDestination.capture()
        destinationLabel = destination?.app.localizedName ?? (target == nil ? "Select a text field" : "Waiting for a text field in \(target?.localizedName ?? "your app")")
    }

    private func refreshDestination() {
        guard let active = NSWorkspace.shared.frontmostApplication else { return }
        if target == nil {
            // Started from the app: bind the first external text field selected while listening.
            if let candidate = MacTextDestination.capture(), candidate.acceptsPaste {
                target = candidate.app; destination = candidate; destinationLabel = candidate.app.localizedName ?? "Your app"
            }
        } else if destination == nil || destination?.acceptsPaste == false {
            // Chromium may publish its accessibility tree after recording begins.
            // Retry only inside the original process; never follow a shortcut-stealing app.
            if active.processIdentifier == target?.processIdentifier, let candidate = MacTextDestination.capture(), candidate.acceptsPaste {
                destination = candidate; destinationLabel = candidate.app.localizedName ?? "Your app"
            }
        }
    }

    var runtimeStatus: [String: Any] {
        ["version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development",
         "checkedAt": ISO8601DateFormatter().string(from: Date()),
         "microphoneAllowed": micAllowed, "speechAllowed": speechAllowed,
         "shortcutMode": "holdToTalk", "shortcutHeld": completion.shortcutHeld,
         "deliveryMethod": deliveryMethod, "deliveryOutcome": deliveryOutcome,
         "shortcut": store.shortcut.label, "shortcutRegistered": hotkeyAvailable,
         "accessibilityAllowed": AXIsProcessTrusted(), "phase": phase.rawValue,
         "targetApp": target?.bundleIdentifier ?? "none", "targetRole": destination?.role ?? "none",
         "targetIsCurrent": destination?.isCurrent ?? false, "canPaste": destination?.acceptsPaste ?? false,
         "status": message]
    }
}
