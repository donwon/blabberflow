import XCTest
@testable import WhisperFlow

final class AccessibilityActivationTests: XCTestCase {
    func testCodexWithRenamedChromiumFrameworkGetsActivated() {
        // Relevant metadata from the installed Codex bundle; no Electron framework.
        XCTAssertEqual(MacTextDestination.accessibilityActivationAttribute(
            bundleIdentifier: "com.openai.codex",
            info: ["ChromiumBaseVersion": "155.0.8059.80"],
            hasElectronFramework: false), "AXEnhancedUserInterface")
    }

    func testStandardElectronAndChromeKeepTheirActivationMethods() {
        XCTAssertEqual(MacTextDestination.accessibilityActivationAttribute(
            bundleIdentifier: "test.electron", info: [:], hasElectronFramework: true), "AXManualAccessibility")
        XCTAssertEqual(MacTextDestination.accessibilityActivationAttribute(
            bundleIdentifier: "com.google.Chrome", info: [:], hasElectronFramework: false), "AXEnhancedUserInterface")
    }

    func testNativeAppsDoNotReceiveChromiumAttributes() {
        XCTAssertNil(MacTextDestination.accessibilityActivationAttribute(
            bundleIdentifier: "com.apple.TextEdit", info: [:], hasElectronFramework: false))
    }
}
