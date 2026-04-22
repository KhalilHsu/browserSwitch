import Foundation
import Testing
@testable import BrowserRouterCore

@Test func urlLogSummaryDoesNotExposePathQueryValuesOrFragment() throws {
    let url = try #require(URL(string: "https://example.com/private/token?utm_source=newsletter&secret=abc#access_token=value"))

    let summary = URLLogSummary(url: url).description

    #expect(summary.contains("scheme=https"))
    #expect(summary.contains("host=example.com"))
    #expect(summary.contains("path=present"))
    #expect(summary.contains("queryItems=2"))
    #expect(!summary.contains("private"))
    #expect(!summary.contains("token"))
    #expect(!summary.contains("secret"))
    #expect(!summary.contains("abc"))
    #expect(!summary.contains("access_token"))
}

@Test func urlLogSummaryHandlesRootPathAndMissingQuery() throws {
    let url = try #require(URL(string: "https://example.com/"))

    let summary = URLLogSummary(url: url).description

    #expect(summary == "scheme=https host=example.com path=none queryItems=0")
}
