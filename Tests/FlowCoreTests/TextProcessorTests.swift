import XCTest
@testable import FlowCore

final class TextProcessorTests: XCTestCase {
    func testVocabularyUsesWholePhrasesAndLiteralPunctuation() {
        let entries = [VocabularyEntry(heard: "don wong", replacement: "Don Wong"), VocabularyEntry(heard: "c++", replacement: "C++")]
        XCTAssertEqual(TextProcessor.process("don wong uses c++ and abandon wong", vocabulary: entries, removeFillers: false), "Don Wong uses C++ and abandon wong")
    }
    func testLongestPhraseWinsWithoutCascading() {
        let entries = [VocabularyEntry(heard: "realty", replacement: "wrong"), VocabularyEntry(heard: "realty os", replacement: "RealtyOS"), VocabularyEntry(heard: "RealtyOS", replacement: "cascaded")]
        XCTAssertEqual(TextProcessor.process("realty os", vocabulary: entries, removeFillers: false), "RealtyOS")
    }
    func testCleanupIsConservativeAndOptional() {
        XCTAssertEqual(TextProcessor.process("  Um, I, uh, like this.  ", vocabulary: [], removeFillers: true), "I, like this.")
        XCTAssertEqual(TextProcessor.process("um, human umbrella", vocabulary: [], removeFillers: false), "um, human umbrella")
        XCTAssertEqual(TextProcessor.process("um, human umbrella", vocabulary: [], removeFillers: true), "human umbrella")
    }
    func testWhitespaceAndEmptyValues() {
        XCTAssertEqual(TextProcessor.process(" \n ", vocabulary: [], removeFillers: false), "")
        XCTAssertEqual(TextProcessor.process("Hello  world !\nNext line.", vocabulary: [VocabularyEntry(heard: "", replacement: "oops")], removeFillers: false), "Hello world!\nNext line.")
    }
}
