import Foundation

public enum RuleMatcher {
    public static func matches(_ rule: RoutingRule, url: URL) -> Bool {
        let absolute = url.absoluteString.removingPercentEncoding ?? url.absoluteString
        let lowercasedAbsolute = absolute.lowercased()
        let host = (url.host ?? "").lowercased()
        let path = url.path

        if let urlContains = rule.urlContains?.lowercased(), !lowercasedAbsolute.contains(urlContains) {
            return false
        }

        if let hostContains = rule.hostContains?.lowercased(), !host.contains(hostContains) {
            return false
        }

        if let hostSuffix = rule.hostSuffix?.lowercased() {
            let normalized = hostSuffix.hasPrefix(".") ? String(hostSuffix.dropFirst()) : hostSuffix
            guard host == normalized || host.hasSuffix(".\(normalized)") else {
                return false
            }
        }

        if let pathPrefix = rule.pathPrefix, !path.hasPrefix(pathPrefix) {
            return false
        }

        return rule.urlContains != nil
            || rule.hostContains != nil
            || rule.hostSuffix != nil
            || rule.pathPrefix != nil
    }
}
