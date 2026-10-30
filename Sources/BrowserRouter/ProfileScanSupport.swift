import Foundation
import BrowserRouterCore

/// Result of a browser profile scan.
struct ProfileScanResult {
    var options: [BrowserOption] = []
    /// Apps whose profile names macOS would not let us read, so some profiles show their folder name instead.
    var appsMissingProfileNames: [String] = []

    static func + (lhs: ProfileScanResult, rhs: ProfileScanResult) -> ProfileScanResult {
        ProfileScanResult(
            options: lhs.options + rhs.options,
            appsMissingProfileNames: lhs.appsMissingProfileNames + rhs.appsMissingProfileNames
        )
    }
}

enum ProfileFileRead<Value> {
    case value(Value)
    case missing
    /// macOS refused access. Since macOS 27, browser data folders such as
    /// ~/Library/Application Support/Google/Chrome are protected and need Full Disk Access.
    case permissionDenied
}

enum ProfileScanSupport {
    static func read<Value>(_ url: URL, parse: (Data) -> Value?) -> ProfileFileRead<Value> {
        do {
            let data = try Data(contentsOf: url)
            return parse(data).map(ProfileFileRead.value) ?? .missing
        } catch {
            return isPermissionError(error) ? .permissionDenied : .missing
        }
    }

    static func subdirectoryNames(of url: URL) -> ProfileFileRead<[String]> {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            let names = urls.compactMap { url -> String? in
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
                    return nil
                }
                return url.lastPathComponent
            }
            return .value(names)
        } catch {
            return isPermissionError(error) ? .permissionDenied : .missing
        }
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileReadNoPermissionError || nsError.code == NSFileWriteNoPermissionError {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain {
            return nsError.code == Int(EPERM) || nsError.code == Int(EACCES)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPermissionError(underlying)
        }
        return false
    }

    /// Merges detected profile options into a configuration, keeping the user's order and hidden state.
    static func merge(_ detected: [BrowserOption], into configuration: RouterConfiguration) -> RouterConfiguration {
        guard !detected.isEmpty else {
            return configuration
        }

        var byID = Dictionary(uniqueKeysWithValues: configuration.browserOptions.map { ($0.id, $0) })
        for var option in detected {
            option.isHidden = byID[option.id]?.isHidden ?? option.isHidden
            byID[option.id] = option
        }

        let originalIDs = configuration.browserOptions.map(\.id)
        let newIDs = detected.map(\.id).filter { !originalIDs.contains($0) }

        var merged = configuration
        merged.browserOptions = (originalIDs + newIDs).compactMap { byID[$0] }
        return merged
    }
}
