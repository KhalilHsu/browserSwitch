import Foundation
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

    func testHostContainsIsCaseInsensitiveAndPathPrefixPreservesCase() throws {
        let rule = makeRule(hostContains: "GitHub", pathPrefix: "/OpenAI")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://github.com/OpenAI/codex")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://github.com/openai/codex")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://github.com/Other/codex")))
    }

    func testURLContainsMatchesAgainstFullURL() throws {
        let rule = makeRule(urlContains: "utm_source=work")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=work")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=personal")))
    }

    func testURLContainsMatchesAfterPercentDecoding() throws {
        let rule = makeRule(urlContains: "login?ref=1")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://example.com/login%3Fref%3D1")))
    }

    func testMultipleRuleConditionsMustAllMatch() throws {
        let rule = makeRule(hostSuffix: "example.com", pathPrefix: "/docs")

        XCTAssertTrue(RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/docs/start")))
        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/blog/start")))
    }

    func testEmptyRuleDoesNotMatch() throws {
        XCTAssertFalse(RuleMatcher.matches(makeRule(), url: try makeURL("https://example.com")))
    }

    func testDisabledRuleDoesNotMatch() throws {
        let rule = makeRule(isEnabled: false, hostSuffix: "example.com")

        XCTAssertFalse(RuleMatcher.matches(rule, url: try makeURL("https://example.com")))
    }

    private func makeRule(
        isEnabled: Bool = true,
        hostContains: String? = nil,
        hostSuffix: String? = nil,
        pathPrefix: String? = nil,
        urlContains: String? = nil
    ) -> RoutingRule {
        RoutingRule(
            id: "test",
            name: "Test",
            isEnabled: isEnabled,
            browserOptionID: "browser",
            hostContains: hostContains,
            hostSuffix: hostSuffix,
            pathPrefix: pathPrefix,
            urlContains: urlContains
        )
    }

    private func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw URLError(.badURL)
        }

        return url
    }
}
