import XCTest
@testable import BrowserRouterCore

final class RuleMatcherTests: XCTestCase {
    func testHostSuffixMatchesExactHostAndSubdomain() throws {
        let rule = makeRule(hostSuffix: "chatgpt.com")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://chatgpt.com/c/123")))
        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://team.chatgpt.com/c/123")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://notchatgpt.com/c/123")))
    }

    func testLeadingDotHostSuffixIsNormalized() throws {
        let rule = makeRule(hostSuffix: ".example.com")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://example.com")))
        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://docs.example.com")))
    }

    func testHostContainsAndPathPrefixAreCaseInsensitive() throws {
        let rule = makeRule(hostContains: "GitHub", pathPrefix: "/OpenAI")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://github.com/OpenAI/codex")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://github.com/Other/codex")))
    }

    func testURLContainsMatchesAgainstFullURL() throws {
        let rule = makeRule(urlContains: "utm_source=work")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=work")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=personal")))
    }

    func testMultipleRuleConditionsMustAllMatch() throws {
        let rule = makeRule(hostSuffix: "example.com", pathPrefix: "/docs")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/docs/start")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/blog/start")))
    }

    func testEmptyRuleDoesNotMatch() throws {
        XCTAssertFalse(RuleMatcher.matches(makeRule(), url: try makeURL("https://example.com")))
    }

    private func makeRule(
        hostContains: String? = nil,
        hostSuffix: String? = nil,
        pathPrefix: String? = nil,
        urlContains: String? = nil
    ) -> RoutingRule {
        RoutingRule(
            id: "test",
            name: "Test",
            browserOptionID: "browser",
            hostContains: hostContains,
            hostSuffix: hostSuffix,
            pathPrefix: pathPrefix,
            urlContains: urlContains
        )
    }

    private func makeURL(_ value: String) throws -> URL {
        try XCTUnwrap(URL(string: value))
    }
}
