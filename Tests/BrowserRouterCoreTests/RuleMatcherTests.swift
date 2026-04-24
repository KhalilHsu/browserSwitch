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

    // MARK: - Source App

    func testSourceAppRuleMatchesWhenAppMatches() throws {
        let rule = makeRule(hostSuffix: "example.com", sourceAppBundleID: "com.tinyspeck.slackmacgap")
        let url = try makeURL("https://example.com")

        XCTAssertTrue(RuleMatcher.matches(rule, url: url, sourceApp: "com.tinyspeck.slackmacgap"))
    }

    func testSourceAppRuleMatchesIsCaseInsensitive() throws {
        let rule = makeRule(hostSuffix: "example.com", sourceAppBundleID: "com.tinyspeck.slackmacgap")
        let url = try makeURL("https://example.com")

        XCTAssertTrue(RuleMatcher.matches(rule, url: url, sourceApp: "COM.TINYSPECK.SLACKMACGAP"))
    }

    func testSourceAppRuleMismatchWhenWrongApp() throws {
        let rule = makeRule(hostSuffix: "example.com", sourceAppBundleID: "com.tinyspeck.slackmacgap")
        let url = try makeURL("https://example.com")

        XCTAssertFalse(RuleMatcher.matches(rule, url: url, sourceApp: "ru.keepcoder.Telegram"))
    }

    func testSourceAppRuleDoesNotMatchWhenSourceAppIsNil() throws {
        // If a rule requires a specific source app but the source is unknown, it must NOT match.
        // This prevents misattribution when source-app detection fails.
        let rule = makeRule(hostSuffix: "example.com", sourceAppBundleID: "com.tinyspeck.slackmacgap")
        let url = try makeURL("https://example.com")

        XCTAssertFalse(RuleMatcher.matches(rule, url: url, sourceApp: nil))
    }

    func testSourceAppOnlyRuleMatchesAnyURLFromThatApp() throws {
        // A rule with only sourceAppBundleID set should match any URL from that app.
        let rule = makeRule(sourceAppBundleID: "com.apple.Notes")
        let url = try makeURL("https://anything.com/path?query=1")

        XCTAssertTrue(RuleMatcher.matches(rule, url: url, sourceApp: "com.apple.Notes"))
        XCTAssertFalse(RuleMatcher.matches(rule, url: url, sourceApp: "ru.keepcoder.Telegram"))
        XCTAssertFalse(RuleMatcher.matches(rule, url: url, sourceApp: nil))
    }

    func testRuleWithoutSourceAppMatchesRegardlessOfSourceApp() throws {
        // Rules with no sourceAppBundleID are not affected by the source app — backward compat.
        let rule = makeRule(hostSuffix: "example.com")
        let url = try makeURL("https://example.com")

        XCTAssertTrue(RuleMatcher.matches(rule, url: url, sourceApp: "com.tinyspeck.slackmacgap"))
        XCTAssertTrue(RuleMatcher.matches(rule, url: url, sourceApp: nil))
    }

    private func makeRule(
        isEnabled: Bool = true,
        hostContains: String? = nil,
        hostSuffix: String? = nil,
        pathPrefix: String? = nil,
        urlContains: String? = nil,
        sourceAppBundleID: String? = nil
    ) -> RoutingRule {
        RoutingRule(
            id: "test",
            name: "Test",
            isEnabled: isEnabled,
            browserOptionID: "browser",
            hostContains: hostContains,
            hostSuffix: hostSuffix,
            pathPrefix: pathPrefix,
            urlContains: urlContains,
            sourceAppBundleID: sourceAppBundleID
        )
    }

    private func makeURL(_ value: String) throws -> URL {
        guard let url = URL(string: value) else {
            throw URLError(.badURL)
        }

        return url
    }
}
