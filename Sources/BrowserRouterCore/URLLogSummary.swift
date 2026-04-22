import Foundation

public struct URLLogSummary: Hashable, CustomStringConvertible {
    public var scheme: String
    public var host: String
    public var hasPath: Bool
    public var queryItemCount: Int

    public init(url: URL) {
        scheme = url.scheme?.lowercased() ?? "unknown"
        host = url.host?.lowercased() ?? "unknown"
        hasPath = !url.path.isEmpty && url.path != "/"

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            queryItemCount = components.queryItems?.count ?? 0
        } else {
            queryItemCount = url.query == nil ? 0 : 1
        }
    }

    public var description: String {
        "scheme=\(scheme) host=\(host) path=\(hasPath ? "present" : "none") queryItems=\(queryItemCount)"
    }
}
