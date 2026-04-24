import Foundation
import XCTest
@testable import BrowserRouterCore

final class URLLogSummaryTests: XCTestCase {
    func testURLLogSummaryDoesNotExposePathQueryValuesOrFragment() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/private/token?utm_source=newsletter&secret=abc#access_token=value"))

        let summary = URLLogSummary(url: url).description

        XCTAssertTrue(summary.contains("scheme=https"))
        XCTAssertTrue(summary.contains("host=example.com"))
        XCTAssertTrue(summary.contains("path=present"))
        XCTAssertTrue(summary.contains("queryItems=2"))
        XCTAssertFalse(summary.contains("private"))
        XCTAssertFalse(summary.contains("token"))
        XCTAssertFalse(summary.contains("secret"))
        XCTAssertFalse(summary.contains("abc"))
        XCTAssertFalse(summary.contains("access_token"))
    }

    func testURLLogSummaryHandlesRootPathAndMissingQuery() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/"))

        let summary = URLLogSummary(url: url).description

        XCTAssertEqual(summary, "scheme=https host=example.com path=none queryItems=0")
    }
}
