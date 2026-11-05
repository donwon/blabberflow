import XCTest
import FlowCore

final class DictationShortcutTests: XCTestCase {
    func testFunctionKeyIsAnExplicitSingleKeyChoice() {
        XCTAssertEqual(DictationShortcut.modifierShortcut(for: [.function]), .function)
        XCTAssertEqual(DictationShortcut.function.modifiers, [.function])
        XCTAssertTrue(DictationShortcut.function.isModifierOnly)
        XCTAssertEqual(DictationShortcut.function.label, "fn")
        XCTAssertEqual(DictationShortcut.function.displayName, "Fn / Globe")
        for other in [ShortcutModifiers.control, .option, .shift, .command] {
            XCTAssertNil(DictationShortcut.modifierShortcut(for: [.function, other]))
        }
    }
    func testRequestedTwoKeyChoicesAreValid() {
        XCTAssertEqual(DictationShortcut.modifierShortcut(for: [.control, .shift]), .controlShift)
        XCTAssertEqual(DictationShortcut.modifierShortcut(for: [.option, .shift]), .optionShift)
        XCTAssertEqual(DictationShortcut.recommended, .controlShift)
    }
    func testEveryAllowedSelectionRoundTripsWithoutOrdinaryKeys() {
        for shortcut in DictationShortcut.allCases where shortcut.isModifierOnly {
            XCTAssertNil(DictationShortcut.validationMessage(for: shortcut.modifiers))
            XCTAssertEqual(DictationShortcut.modifierShortcut(for: shortcut.modifiers), shortcut)
            XCTAssertEqual(DictationShortcut(rawValue: shortcut.rawValue), shortcut)
        }
    }
    func testUnsupportedAndReservedChoicesCannotBeApplied() {
        let rejected: [ShortcutModifiers] = [[], [.shift], [.control, .option], [.command, .shift], [.control, .option, .shift, .command], [.control, .function]]
        for modifiers in rejected {
            XCTAssertNil(DictationShortcut.modifierShortcut(for: modifiers))
            XCTAssertNotNil(DictationShortcut.validationMessage(for: modifiers))
        }
    }
}
