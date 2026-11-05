import XCTest
import FlowCore

final class ShortcutHoldStateTests: XCTestCase {
    private let chord = ModifierShortcutHoldState.required

    func testEachPresetRequiresDeliberateHoldAndEachReleaseOrderEndsOnce() {
        let presets = DictationShortcut.allCases.filter(\.isModifierOnly).map(\.modifiers)
        for preset in presets {
            for released in [ShortcutModifiers.control, .command, .shift, .option, .function] where preset.contains(released) {
                var state = ModifierShortcutHoldState(required: preset)
                XCTAssertNil(state.update(preset, now: 10))
                XCTAssertNil(state.update(preset, now: 10.29))
                XCTAssertEqual(state.update(preset, now: 10.3), .pressed)
                XCTAssertNil(state.update(preset, now: 10.5))
                XCTAssertEqual(state.update(preset.subtracting(released), now: 11), .released)
                XCTAssertNil(state.update([], now: 11.1))
            }
        }
    }

    func testFunctionHoldDoesNotHijackFunctionKeyCombinations() {
        var state = ModifierShortcutHoldState(required: [.function])
        XCTAssertNil(state.update([.function], now: 0))
        XCTAssertNil(state.update([.function], mayStart: false, nonModifierDown: true, now: 0.1))
        XCTAssertNil(state.update([.function], now: 1), "Fn plus an arrow/media key must stay suppressed after that key is up")
        XCTAssertNil(state.update([], now: 2))
        XCTAssertNil(state.update([.function], now: 3))
        XCTAssertEqual(state.update([.function], now: 3.3), .pressed)
        XCTAssertEqual(state.update([.function], mayStart: false, nonModifierDown: true, now: 4), .cancelled)
        XCTAssertNil(state.update([.function], now: 5))
        XCTAssertNil(state.update([], now: 6))
        XCTAssertNil(state.update([.function], now: 7))
        XCTAssertEqual(state.update([.function], now: 7.3), .pressed)
        XCTAssertEqual(state.update([], now: 8), .released)
    }

    func testIncompleteReleaseCannotStartAnotherRecording() {
        var state = ModifierShortcutHoldState()
        XCTAssertNil(state.update(chord, now: 0))
        XCTAssertEqual(state.update(chord, now: 0.3), .pressed)
        XCTAssertEqual(state.update([.control, .command], now: 1), .released)
        XCTAssertNil(state.update(chord, now: 2), "Repressing Shift while the other keys remain down must not restart")
        XCTAssertNil(state.update([.shift], now: 3))
        XCTAssertNil(state.update(chord, now: 4))
        XCTAssertNil(state.update([], now: 5))
        XCTAssertNil(state.update(chord, now: 6))
        XCTAssertEqual(state.update(chord, now: 6.3), .pressed)
    }

    func testShortTapNeverStartsAndRequiresReleaseBeforeAnotherAttempt() {
        var state = ModifierShortcutHoldState(required: [.control, .shift])
        XCTAssertNil(state.update([.control, .shift], now: 0))
        XCTAssertNil(state.update([.control], now: 0.1))
        XCTAssertNil(state.update([.control, .shift], now: 1))
        XCTAssertNil(state.update([.control, .shift], now: 2))
        XCTAssertNil(state.armingDeadline)
        XCTAssertNil(state.update([], now: 3))
        XCTAssertNil(state.update([.control, .shift], now: 4))
        XCTAssertEqual(state.update([.control, .shift], now: 4.3), .pressed)
    }

    func testShortcutLetterDuringDelaySuppressesUntilFullRelease() {
        let preset: ShortcutModifiers = [.control, .shift]
        var state = ModifierShortcutHoldState(required: preset)
        XCTAssertNil(state.update(preset, now: 0))
        XCTAssertNil(state.update(preset, mayStart: false, nonModifierDown: true, now: 0.1))
        XCTAssertNil(state.update(preset, now: 1), "Releasing a shortcut letter must not begin dictation")
        XCTAssertNil(state.armingDeadline)
        XCTAssertNil(state.update([], now: 2))
        XCTAssertNil(state.update(preset, now: 3))
        XCTAssertEqual(state.update(preset, now: 3.3), .pressed)
    }

    func testShortcutLetterBeforeChordIsCompleteSuppressesUntilFullRelease() {
        var state = ModifierShortcutHoldState(required: [.control, .shift])
        XCTAssertNil(state.update([.control], mayStart: false, nonModifierDown: true, now: 0))
        XCTAssertNil(state.update([.control, .shift], now: 1))
        XCTAssertNil(state.update([.control, .shift], now: 2))
        XCTAssertFalse(state.isHeld)
        XCTAssertNil(state.armingDeadline)
    }

    func testOrdinaryKeyAlreadyDownBlocksChordAndDelayedActivation() {
        let preset: ShortcutModifiers = [.option, .shift]
        var preheld = ModifierShortcutHoldState(required: preset)
        XCTAssertNil(preheld.update(preset, nonModifierDown: true, now: 0))
        XCTAssertNil(preheld.update(preset, now: 1))
        XCTAssertNil(preheld.armingDeadline)

        var keyArrivedDuringDelay = ModifierShortcutHoldState(required: preset)
        XCTAssertNil(keyArrivedDuringDelay.update(preset, now: 0))
        XCTAssertNil(keyArrivedDuringDelay.update(preset, nonModifierDown: true, now: 0.3))
        XCTAssertNil(keyArrivedDuringDelay.update(preset, now: 1))
        XCTAssertFalse(keyArrivedDuringDelay.isHeld)
    }

    func testOrdinaryKeyDuringRecordingCancelsWithoutDelivering() {
        let preset: ShortcutModifiers = [.option, .shift]
        var state = ModifierShortcutHoldState(required: preset)
        XCTAssertNil(state.update(preset, now: 0))
        XCTAssertEqual(state.update(preset, now: 0.3), .pressed)
        XCTAssertEqual(state.update(preset, mayStart: false, nonModifierDown: true, now: 1), .cancelled)
        XCTAssertNil(state.update(preset, mayStart: false, nonModifierDown: true, now: 1.1))
        XCTAssertNil(state.update(preset, now: 2))
        XCTAssertNil(state.update([], now: 3), "Cancellation must not also deliver a release")
    }

    func testExtraModifiersBeforeOrDuringDelaySuppressUntilFullRelease() {
        for extra in [ShortcutModifiers.option, .function] {
            var state = ModifierShortcutHoldState()
            XCTAssertNil(state.update(chord.union(extra), now: 0))
            XCTAssertNil(state.update(chord, now: 1), "Removing the extra modifier must not start dictation")
            XCTAssertNil(state.update([], now: 2))
            XCTAssertNil(state.update(chord, now: 3))
            XCTAssertNil(state.update(chord.union(extra), now: 3.1))
            XCTAssertNil(state.update(chord, now: 4))
            XCTAssertNil(state.armingDeadline)
        }
    }

    func testExtraModifierWhileRecordingCancelsInsteadOfFinishing() {
        var state = ModifierShortcutHoldState(required: [.control, .shift])
        XCTAssertNil(state.update([.control, .shift], now: 0))
        XCTAssertEqual(state.update([.control, .shift], now: 0.3), .pressed)
        XCTAssertEqual(state.update([.control, .shift, .command], now: 1), .cancelled)
        XCTAssertNil(state.update([.control, .shift], now: 2))
        XCTAssertNil(state.update([], now: 3))
    }

    func testRegistrationWithAnySelectedModifierHeldRequiresFullRelease() {
        var state = ModifierShortcutHoldState(required: [.option, .shift], initialModifiers: [.shift])
        XCTAssertNil(state.update([.option, .shift], now: 0))
        XCTAssertNil(state.update([.option], now: 1))
        XCTAssertNil(state.update([.option, .shift], now: 2))
        XCTAssertNil(state.update([], now: 3))
        XCTAssertNil(state.update([.option, .shift], now: 4))
        XCTAssertEqual(state.update([.option, .shift], now: 4.3), .pressed)
    }

    func testSafetyPollingCanStopAndRearmButNeverBeginOrCompleteArming() {
        var state = ModifierShortcutHoldState()
        XCTAssertNil(state.update(chord, mayStart: false, now: 0))
        XCTAssertNil(state.armingDeadline)
        XCTAssertNil(state.update(chord, now: 1))
        XCTAssertNil(state.update(chord, mayStart: false, now: 2))
        XCTAssertFalse(state.isHeld)
        XCTAssertEqual(state.update(chord, now: 2.1), .pressed)
        XCTAssertEqual(state.update([.control], mayStart: false, now: 3), .released)
        XCTAssertNil(state.update([], mayStart: false, now: 4))
        XCTAssertNil(state.update(chord, mayStart: false, now: 5))
        XCTAssertNil(state.armingDeadline)
    }

    func testEmptyModifierChoiceCanNeverRecord() {
        var state = ModifierShortcutHoldState(required: [])
        XCTAssertNil(state.update([], now: 0))
        XCTAssertNil(state.update([], now: 1))
        XCTAssertFalse(state.isHeld)
    }

    func testKeyDownAndUpProduceOnePairDespiteRepeats() {
        var state = KeyShortcutHoldState()
        XCTAssertNil(state.update(isDown: false))
        XCTAssertEqual(state.update(isDown: true), .pressed)
        XCTAssertNil(state.update(isDown: true))
        XCTAssertNil(state.update(isDown: true))
        XCTAssertEqual(state.update(isDown: false), .released)
        XCTAssertNil(state.update(isDown: false))
        XCTAssertEqual(state.update(isDown: true), .pressed)
    }

    func testKeyAlreadyHeldAtRegistrationAndSafetyPollingCannotStart() {
        var state = KeyShortcutHoldState(initiallyDown: true)
        XCTAssertNil(state.update(isDown: true))
        XCTAssertNil(state.update(isDown: false, mayStart: false))
        XCTAssertNil(state.update(isDown: true, mayStart: false))
        XCTAssertEqual(state.update(isDown: true), .pressed)
        XCTAssertEqual(state.update(isDown: false, mayStart: false), .released)
    }
}
