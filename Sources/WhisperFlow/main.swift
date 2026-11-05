import AppKit
import SwiftUI
import Combine

final class RecordingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = Store()
    lazy var controller = DictationController(store: store)
    let hotkey = Hotkey()
    private var window: NSWindow!
    private var panel: NSPanel!
    private var status: NSStatusItem!
    private var statusObserver: AnyCancellable?
    private var permissionObserver: AnyCancellable?
    private var permissionTimer: Timer?
    private var resultDismissal: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)
        installMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = AppIdentity.name; window.titlebarAppearsTransparent = true
        window.minSize = NSSize(width: 860, height: 650); window.center(); window.delegate = self
        window.isReleasedWhenClosed = false
        var initialPage = "Home"
        if let index = CommandLine.arguments.firstIndex(of: "--page"), CommandLine.arguments.count > index + 1 {
            let page = CommandLine.arguments[index + 1]
            if ["Home", "History", "Vocabulary", "Settings"].contains(page) { initialPage = page }
        }
        window.contentView = NSHostingView(rootView: MainView(controller: controller, store: store, initialPage: initialPage).environment(\.colorScheme, .light))
        panel = RecordingPanel(contentRect: NSRect(x: 0, y: 0, width: 420, height: 100), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.becomesKeyOnlyIfNeeded = true
        panel.level = .floating; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: RecordingView(controller: controller).environment(\.colorScheme, .light))
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: AppIdentity.name)
        let menu = NSMenu()
        menu.addItem(withTitle: "Start / finish hands-free dictation", action: #selector(toggle), keyEquivalent: "")
        menu.addItem(withTitle: "Cancel dictation", action: #selector(cancel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Open \(AppIdentity.name)", action: #selector(show), keyEquivalent: "")
        menu.addItem(withTitle: "Copy latest transcript", action: #selector(copyLatest), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        status.menu = menu
        hotkey.onPress = { [weak self] in self?.controller.shortcutPressed() }
        hotkey.onRelease = { [weak self] in self?.controller.shortcutReleased() }
        hotkey.onCancel = { [weak self] in self?.controller.shortcutCancelled() }
        controller.hotkeyAvailable = hotkey.register(store.shortcut)
        statusObserver = store.$shortcut.dropFirst().sink { [weak self] shortcut in
            guard let self = self else { return }
            self.controller.hotkeyAvailable = self.hotkey.register(shortcut)
            DispatchQueue.main.async { self.writeRuntimeStatus() }
        }
        permissionObserver = controller.$accessibilityAllowed.removeDuplicates().dropFirst().sink { [weak self] _ in
            guard let self = self else { return }
            if self.store.shortcut.isModifierOnly {
                self.controller.hotkeyAvailable = self.hotkey.register(self.store.shortcut)
            }
            DispatchQueue.main.async { self.writeRuntimeStatus() }
        }
        // Re-arm modifier monitoring after the user grants Accessibility in Settings.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.controller.refreshPermissions() }
        controller.onActivity = { [weak self] in self?.updateActivity() }
        writeRuntimeStatus()
        show()
        // Smoke verification renders the real home view without requesting microphone access.
        if let index = CommandLine.arguments.firstIndex(of: "--screenshot"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let view = self?.window.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { NSApp.terminate(nil); return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                NSApp.terminate(nil)
            }
        }
    }
    private func installMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(AppIdentity.name)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(AppIdentity.name)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu; main.addItem(appItem)
        let editItem = NSMenuItem(); let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    private func updateActivity() {
        resultDismissal?.cancel()
        writeRuntimeStatus()
        status.button?.toolTip = controller.message
        status.button?.image = NSImage(systemSymbolName: controller.busy ? "mic.fill" : "waveform", accessibilityDescription: controller.busy ? "Recording" : AppIdentity.name)
        let frame = NSScreen.main?.visibleFrame ?? .zero
        panel.setFrameOrigin(NSPoint(x: frame.midX - 210, y: frame.minY + 35)); panel.orderFrontRegardless()
        if !controller.busy {
            let work = DispatchWorkItem { [weak self] in self?.panel.orderOut(nil) }
            resultDismissal = work; DispatchQueue.main.asyncAfter(deadline: .now() + 7, execute: work)
        }
    }
    private func writeRuntimeStatus() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("WhisperFlow")
        let url = directory.appendingPathComponent("runtime-status.json")
        if let data = try? JSONSerialization.data(withJSONObject: controller.runtimeStatus, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        }
    }
    @objc func show() { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); controller.refreshPermissions() }
    @objc func toggle() { controller.toggle() }
    @objc func cancel() { controller.cancel() }
    @objc func copyLatest() { if !controller.lastText.isEmpty { controller.copy(controller.lastText) } }
    @objc func quit() { controller.cancel(); NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { show(); return true }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
