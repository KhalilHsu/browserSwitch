import Foundation
import Testing
@testable import BrowserRouterCore

@Test func hostSuffixMatchesExactHostAndSubdomain() throws {
    let rule = makeRule(hostSuffix: "chatgpt.com")

    #expect(RuleMatcher.matches(rule, url: try makeURL("https://chatgpt.com/c/123")))
    #expect(RuleMatcher.matches(rule, url: try makeURL("https://team.chatgpt.com/c/123")))
    #expect(!RuleMatcher.matches(rule, url: try makeURL("https://notchatgpt.com/c/123")))
}

@Test func leadingDotHostSuffixIsNormalized() throws {
    let rule = makeRule(hostSuffix: ".example.com")

    #expect(RuleMatcher.matches(rule, url: try makeURL("https://example.com")))
    #expect(RuleMatcher.matches(rule, url: try makeURL("https://docs.example.com")))
}

@Test func hostContainsAndPathPrefixAreCaseInsensitive() throws {
    let rule = makeRule(hostContains: "GitHub", pathPrefix: "/OpenAI")

    #expect(RuleMatcher.matches(rule, url: try makeURL("https://github.com/OpenAI/codex")))
    #expect(!RuleMatcher.matches(rule, url: try makeURL("https://github.com/Other/codex")))
}

@Test func urlContainsMatchesAgainstFullURL() throws {
    let rule = makeRule(urlContains: "utm_source=work")

    #expect(RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=work")))
    #expect(!RuleMatcher.matches(rule, url: try makeURL("https://example.com/path?utm_source=personal")))
}

@Test func multipleRuleConditionsMustAllMatch() throws {
    let rule = makeRule(hostSuffix: "example.com", pathPrefix: "/docs")

    #expect(RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/docs/start")))
    #expect(!RuleMatcher.matches(rule, url: try makeURL("https://help.example.com/blog/start")))
}

@Test func emptyRuleDoesNotMatch() throws {
    #expect(!RuleMatcher.matches(makeRule(), url: try makeURL("https://example.com")))
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
    guard let url = URL(string: value) else {
        throw URLError(.badURL)
    }

    return url
}