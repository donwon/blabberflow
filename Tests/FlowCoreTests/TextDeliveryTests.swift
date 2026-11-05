import XCTest
@testable import FlowCore

final class TextDeliveryTests: XCTestCase {
    final class Destination: TextDestination {
        var isCurrent = true
        var isSecure = false
        var acceptsPaste = true
        var prefersPaste = false
        var directSuccess = false
        var pasteSuccess = true
        var replacement: String?
        var pastes = 0
        func replaceSelection(with text: String) -> Bool { replacement = text; return directSuccess }
        func requestPaste() -> Bool { pastes += 1; return pasteSuccess }
    }
    func testReadOnlySelectedTextAutomaticallyPastesAfterCopy() {
        let destination = Destination()
        let result = TextDelivery.deliver("Hello from dictation", to: destination) { text in
            XCTAssertEqual(text, "Hello from dictation")
            XCTAssertEqual(destination.pastes, 0, "Clipboard must be ready before the paste is sent")
        }
        XCTAssertEqual(result, .pasteRequested)
        XCTAssertEqual(destination.pastes, 1)
    }
    func testSuccessfulDirectInsertionDoesNotPasteTwiceOrChangeClipboard() {
        let destination = Destination(); destination.directSuccess = true
        XCTAssertEqual(TextDelivery.deliver("Hello", to: destination) { _ in XCTFail("Preserve clipboard after direct insertion") }, .inserted)
        XCTAssertEqual(destination.replacement, "Hello"); XCTAssertEqual(destination.pastes, 0)
    }
    func testChromiumRouteSkipsSetterThatCanFalselyReportSuccess() {
        let destination = Destination()
        destination.prefersPaste = true
        destination.directSuccess = true // Chromium can acknowledge without changing text.
        var copies: [String] = []
        let result = TextDelivery.deliver("Hello from dictation", to: destination) { text in
            copies.append(text)
            XCTAssertEqual(destination.pastes, 0)
        }
        XCTAssertNil(destination.replacement, "Do not invoke the unreliable selected-text setter")
        XCTAssertEqual(copies, ["Hello from dictation"])
        XCTAssertEqual(destination.pastes, 1)
        XCTAssertEqual(result, .pasteRequested)
    }
    func testPreferredPasteStillRejectsSecureNonTextAndChangedFields() {
        for condition in 0..<3 {
            let destination = Destination(); destination.prefersPaste = true; destination.directSuccess = true
            if condition == 0 { destination.isSecure = true }
            if condition == 1 { destination.acceptsPaste = false }
            if condition == 2 { destination.isCurrent = false }
            XCTAssertEqual(TextDelivery.deliver("Hello", to: destination) { _ in }, .copied)
            XCTAssertNil(destination.replacement)
            XCTAssertEqual(destination.pastes, 0)
        }
    }
    func testFocusChangeDuringFallbackPreventsPaste() {
        let destination = Destination()
        XCTAssertEqual(TextDelivery.deliver("Hello", to: destination) { _ in destination.isCurrent = false }, .copied)
        XCTAssertEqual(destination.pastes, 0)
    }
    func testSecureAndNonTextTargetsDoNotReceivePaste() {
        for secure in [true, false] {
            let destination = Destination(); destination.isSecure = secure; destination.acceptsPaste = false
            XCTAssertEqual(TextDelivery.deliver("Hello", to: destination) { _ in }, .copied)
            XCTAssertEqual(destination.pastes, 0)
            if secure { XCTAssertNil(destination.replacement) }
        }
    }
    func testMissingOrChangedDestinationKeepsRecoverableCopy() {
        var copies: [String] = []
        XCTAssertEqual(TextDelivery.deliver("One", to: nil) { copies.append($0) }, .copied)
        let destination = Destination(); destination.isCurrent = false
        XCTAssertEqual(TextDelivery.deliver("Two", to: destination) { copies.append($0) }, .copied)
        XCTAssertEqual(copies, ["One", "Two"]); XCTAssertNil(destination.replacement)
    }
    func testEventFailureDoesNotClaimInsertion() {
        let destination = Destination(); destination.pasteSuccess = false
        XCTAssertEqual(TextDelivery.deliver("Hello", to: destination) { _ in }, .copied)
    }
}
