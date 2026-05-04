import Foundation

public enum URLTextExtractor {
    public static func firstWebURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directURL = URL(string: trimmed), isWebURL(directURL) {
            return directURL
        }

        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        guard let match = detector.firstMatch(in: trimmed, options: [], range: range),
              let url = match.url,
              isWebURL(url) else {
            return nil
        }

        return url
    }

    private static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        return scheme == "http" || scheme == "https"
    }
}
