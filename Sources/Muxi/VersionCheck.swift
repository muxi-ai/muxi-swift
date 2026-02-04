import Foundation

public enum VersionCheck {
    private static let sdkName = "swift"
    private static let twelveHours: TimeInterval = 12 * 60 * 60
    private static var checked = false
    private static let lock = NSLock()
    
    public static func checkForUpdates(_ headers: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        
        if checked { return }
        checked = true
        
        guard !notificationsDisabled() else { return }
        
        guard let latest = headers["X-Muxi-SDK-Latest"] ?? headers["x-muxi-sdk-latest"] else { return }
        guard isNewerVersion(latest: latest, current: MuxiVersion.version) else { return }
        
        updateLatestVersion(latest)
        
        if !notifiedRecently() {
            fputs("[muxi] SDK update available: \(latest) (current: \(MuxiVersion.version))\n", stderr)
            fputs("[muxi] Update via Swift Package Manager\n", stderr)
            markNotified()
        }
    }
    
    private static func notificationsDisabled() -> Bool {
        ProcessInfo.processInfo.environment["MUXI_SDK_VERSION_NOTIFICATION"] == "0"
    }
    
    private static func getCachePath() -> URL? {
        guard let home = FileManager.default.homeDirectoryForCurrentUser.path as String? else { return nil }
        return URL(fileURLWithPath: home).appendingPathComponent(".muxi/sdk-versions.json")
    }
    
    private static func loadCache() -> [String: [String: Any]] {
        guard let path = getCachePath(),
              FileManager.default.fileExists(atPath: path.path),
              let data = try? Data(contentsOf: path),
              let cache = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return [:]
        }
        return cache
    }
    
    private static func saveCache(_ cache: [String: [String: Any]]) {
        guard let path = getCachePath(),
              let data = try? JSONSerialization.data(withJSONObject: cache, options: .prettyPrinted) else { return }
        
        let dir = path.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: path)
    }
    
    private static func isNewerVersion(latest: String, current: String) -> Bool {
        latest.compare(current, options: .numeric) == .orderedDescending
    }
    
    private static func notifiedRecently() -> Bool {
        let cache = loadCache()
        guard let entry = cache[sdkName],
              let lastNotifiedStr = entry["last_notified"] as? String,
              let lastNotified = ISO8601DateFormatter().date(from: lastNotifiedStr) else { return false }
        return Date().timeIntervalSince(lastNotified) < twelveHours
    }
    
    private static func updateLatestVersion(_ latest: String) {
        var cache = loadCache()
        var entry = cache[sdkName] ?? [:]
        entry["current"] = MuxiVersion.version
        entry["latest"] = latest
        cache[sdkName] = entry
        saveCache(cache)
    }
    
    private static func markNotified() {
        var cache = loadCache()
        if var entry = cache[sdkName] {
            entry["last_notified"] = ISO8601DateFormatter().string(from: Date())
            cache[sdkName] = entry
            saveCache(cache)
        }
    }
}
