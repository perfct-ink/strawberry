import Foundation

/// App Store builds run in the App Sandbox, where a folder outside the container
/// is reachable only after the user picks it in an open panel. This keeps a
/// security-scoped bookmark for every folder picked and re-opens access when a
/// path is needed — lazily, so a drive that mounts later is picked up the next
/// time its rule is checked. Outside the sandbox every call is a no-op.
final class SandboxAccess {
    static let shared = SandboxAccess()

    static let isSandboxed = ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil

    private let defaultsKey = "securityScopedBookmarks"
    private let lock = NSLock()
    /// Standardized path → bookmark data, persisted in user defaults.
    private var bookmarks: [String: Data]
    /// Paths whose security scope is currently open. Held for the app's lifetime.
    private var active: Set<String> = []

    private init() {
        bookmarks = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
    }

    /// Remember a folder the user just picked so it stays reachable after relaunch.
    func remember(_ url: URL) {
        guard Self.isSandboxed else { return }
        guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else {
            log.error("Could not create a bookmark for \(url.path)")
            return
        }
        let path = Self.standardize(url.path)
        lock.lock(); defer { lock.unlock() }
        bookmarks[path] = data
        if url.startAccessingSecurityScopedResource() { active.insert(path) }
        persist()
    }

    /// Can the app read and write `path` right now? Re-opens any saved bookmark
    /// that covers it first. Always true outside the sandbox.
    func ensureAccess(to path: String) -> Bool {
        guard Self.isSandboxed else { return true }
        let std = Self.standardize(path)
        lock.lock(); defer { lock.unlock() }
        if active.contains(where: { VolumeUtil.path(std, isOn: $0) }) { return true }

        for (saved, data) in bookmarks where !active.contains(saved) && VolumeUtil.path(std, isOn: saved) {
            var stale = false
            // `.withoutMounting`: an unplugged drive should just report "not
            // reachable", not trigger a mount attempt every refresh.
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withSecurityScope, .withoutUI, .withoutMounting],
                                     relativeTo: nil, bookmarkDataIsStale: &stale),
                  url.startAccessingSecurityScopedResource() else { continue }
            active.insert(saved)
            if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope,
                                                        includingResourceValuesForKeys: nil,
                                                        relativeTo: nil) {
                bookmarks[saved] = fresh
                persist()
            }
            return true
        }
        return false
    }

    private func persist() {
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }

    private static func standardize(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
}
