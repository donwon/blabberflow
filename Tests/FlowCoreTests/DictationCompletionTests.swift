import XCTest
@testable import FlowCore

final class DictationCompletionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000)

    func testEarlyRecognitionFinalWaitsForUserRelease() {
        var session = DictationCompletion(holdToTalk: true)
        session.markTranscriptReady()
        XCTAssertEqual(session.action(modifiersDown: false, now: now), .waitForRelease)
        session.release()
        XCTAssertEqual(session.action(modifiersDown: false, now: now), .deliver)
    }

    func testQuickReleaseStillWaitsForRecognition() {
        var session = DictationCompletion(holdToTalk: true)
        session.release()
        XCTAssertEqual(session.action(modifiersDown: false, now: now), .waitForRecognition)
        session.markTranscriptReady()
        XCTAssertEqual(session.action(modifiersDown: false, now: now), .deliver)
    }

    func testPartialReleaseDoesNotSendModifiedPaste() {
        var session = DictationCompletion(holdToTalk: true)
        session.release(); session.markTranscriptReady()
        XCTAssertEqual(session.action(modifiersDown: true, now: now), .waitForModifiers)
        XCTAssertEqual(session.action(modifiersDown: true, now: now.addingTimeInterval(1)), .waitForModifiers)
        XCTAssertEqual(session.action(modifiersDown: false, now: now.addingTimeInterval(2)), .deliver)
    }

    func testStuckModifierFallsBackToCopyInsteadOfDelayedInsertion() {
        var session = DictationCompletion(holdToTalk: true)
        session.release(); session.markTranscriptReady()
        XCTAssertEqual(session.action(modifiersDown: true, now: now), .waitForModifiers)
        XCTAssertEqual(session.action(modifiersDown: true, now: now.addingTimeInterval(5)), .copyOnly)
    }

    func testButtonRecordingDoesNotNeedShortcutRelease() {
        var session = DictationCompletion(holdToTalk: false)
        session.markTranscriptReady()
        XCTAssertEqual(session.action(modifiersDown: false, now: now), .deliver)
    }
}
