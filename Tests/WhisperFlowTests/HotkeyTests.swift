import XCTest
import AppKit
import Carbon
import FlowCore
@testable import WhisperFlow

final class HotkeyTests: XCTestCase {
    func testExclusiveRegistrationReportsConflictAndReleasesPreviousShortcut() throws {
        var first: Hotkey? = Hotkey()
        let second = Hotkey()
        // The installed app can already own the default while development tests run.
        guard let shortcut = DictationShortcut.allCases.filter({ !$0.isModifierOnly }).first(where: { first!.register($0) }) else {
            throw XCTSkip("All dictation presets are in use by running apps")
        }
        XCTAssertFalse(second.register(shortcut), "A conflicting owner must not silently share the shortcut")
        first = nil
        XCTAssertTrue(second.register(shortcut), "Removing the owner must release its registration")
    }

    func testModifierMappingIgnoresCapsLockAndRetainsDisallowedModifiers() {
        XCTAssertEqual(Hotkey.modifiers(from: [.control, .command, .shift, .capsLock]), ModifierShortcutHoldState.required)
        XCTAssertNotEqual(Hotkey.modifiers(from: [.control, .command, .shift, .option]), ModifierShortcutHoldState.required)
        XCTAssertNotEqual(Hotkey.modifiers(from: [.control, .command, .shift, .function]), ModifierShortcutHoldState.required)
    }

    func testPreheldKeyDetectionIgnoresPhysicalModifiersButIncludesLettersArrowsAndKeypad() {
        let modifierKeys = Set([kVK_Command, kVK_RightCommand, kVK_Shift, kVK_RightShift,
                                kVK_Option, kVK_RightOption, kVK_Control, kVK_RightControl,
                                kVK_CapsLock, kVK_Function].map(CGKeyCode.init))
        XCTAssertFalse(Hotkey.hasNonModifierKeyDown { modifierKeys.contains($0) })
        for key in [kVK_ANSI_A, kVK_LeftArrow, kVK_ANSI_Keypad0] {
            XCTAssertTrue(Hotkey.hasNonModifierKeyDown { $0 == CGKeyCode(key) })
        }
        XCTAssertFalse(Hotkey.hasNonModifierKeyDown { _ in false })
    }

    func testCancellingAnActiveModifierHoldDoesNotDeliverItsTranscript() {
        let hotkey = Hotkey()
        let cancelled = expectation(description: "Cancellation reaches controller")
        var releases = 0
        hotkey.onRelease = { releases += 1 }
        hotkey.onCancel = { cancelled.fulfill() }
        hotkey.dispatchTransition(.pressed)
        hotkey.dispatchTransition(.cancelled)
        wait(for: [cancelled], timeout: 1)
        XCTAssertEqual(releases, 0)
    }

    func testReregisterPreservesCancellationWhenCallbackIsStillQueued() {
        let hotkey = Hotkey()
        let pressed = expectation(description: "Press callback reached controller")
        var releases = 0
        var cancellations = 0
        hotkey.onPress = { pressed.fulfill() }
        hotkey.onRelease = { releases += 1 }
        hotkey.onCancel = { cancellations += 1 }
        hotkey.dispatchTransition(.pressed)
        wait(for: [pressed], timeout: 1)
        hotkey.dispatchTransition(.cancelled)
        _ = hotkey.register(.controlShiftD)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(releases, 0, "A pending cancellation must not become a delivery when settings change")
        let drained = expectation(description: "Queued stale cancellation drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
        XCTAssertEqual(cancellations, 1)
        XCTAssertEqual(releases, 0)
    }

    func testReregisterDeliversReleaseWhenAnEarlierReleaseIsStillQueued() {
        let hotkey = Hotkey()
        let pressed = expectation(description: "Press callback reached controller")
        var releases = 0
        hotkey.onPress = { pressed.fulfill() }
        hotkey.onRelease = { releases += 1 }
        hotkey.dispatchTransition(.pressed)
        wait(for: [pressed], timeout: 1)
        hotkey.dispatchTransition(.released)
        _ = hotkey.register(.controlShiftD)
        XCTAssertEqual(releases, 1, "Changing registration must match the press already delivered")
        let drained = expectation(description: "Queued stale callback drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 1)
        XCTAssertEqual(releases, 1, "The invalidated release callback must not fire twice")
    }
}
