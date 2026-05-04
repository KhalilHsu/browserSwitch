import Foundation
import XCTest
@testable import BrowserRouterCore

final class URLTextExtractorTests: XCTestCase {
    func testExtractsPlainWebURL() {
        let url = URLTextExtractor.firstWebURL(in: "https://example.com/path?x=1")

        XCTAssertEqual(url?.absoluteString, "https://example.com/path?x=1")
    }

    func testExtractsFirstWebURLFromText() {
        let url = URLTextExtractor.firstWebURL(in: "Open this one: https://example.com/docs, thanks")

        XCTAssertEqual(url?.host, "example.com")
        XCTAssertEqual(url?.path, "/docs")
    }

    func testRejectsNonWebURL() {
        XCTAssertNil(URLTextExtractor.firstWebURL(in: "file:///Users/khalil/Desktop/test.html"))
    }

    func testReturnsNilWhenTextHasNoURL() {
        XCTAssertNil(URLTextExtractor.firstWebURL(in: "just some selected text"))
    }
}
