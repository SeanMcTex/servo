import Foundation

struct ObservationEntry: Codable {
    let timestamp: Date
    let appName: String
    let windowTitle: String?
}

actor ObservationLog {

    static let shared = ObservationLog()
    private init() {}

    private var entries: [ObservationEntry] = []
    private var loaded = false

    // MARK: - Public API

    func append(appName: String, windowTitle: String?) {
        ensureLoaded()
        let entry = ObservationEntry(timestamp: Date(), appName: appName, windowTitle: windowTitle)
        entries.append(entry)
        prune()
        save(entries)
    }

    func contextSummary() -> String {
        ensureLoaded()
        guard !entries.isEmpty else { return "" }

        let now = Date()
        let calendar = Calendar.current
        let oneHourAgo = now.addingTimeInterval(-3600)
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday)!

        let recent = entries.filter { $0.timestamp >= oneHourAgo }
        let earlierToday = entries.filter { $0.timestamp >= startOfToday && $0.timestamp < oneHourAgo }
        let yesterday = entries.filter { $0.timestamp >= startOfYesterday && $0.timestamp < startOfToday }

        var parts: [String] = []

        if let recentSummary = summarize(recent, label: nil) {
            parts.append("Recent: \(recentSummary)")
        }
        if let todaySummary = summarize(earlierToday, label: nil) {
            parts.append("Earlier today: \(todaySummary)")
        }
        if let yesterdaySummary = summarize(yesterday, label: nil) {
            parts.append("Yesterday: \(yesterdaySummary)")
        }

        let result = parts.joined(separator: ". ")
        // Cap at ~150 chars to stay within token budget
        return result.count > 150 ? String(result.prefix(147)) + "…" : result
    }

    // MARK: - Private

    private func ensureLoaded() {
        guard !loaded else { return }
        entries = load()
        loaded = true
    }

    private func prune() {
        let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
        entries = entries.filter { $0.timestamp > cutoff }
    }

    /// Summarizes a list of entries as "AppName (Xm), AppName2 (Ym)" grouped by app, sorted by most time.
    private func summarize(_ entries: [ObservationEntry], label: String?) -> String? {
        guard !entries.isEmpty else { return nil }

        // Compute approximate time per app by counting entries (each ≈ captureInterval seconds)
        var counts: [String: Int] = [:]
        for entry in entries {
            counts[entry.appName, default: 0] += 1
        }

        // Sort by count descending, take top 3
        let sorted = counts.sorted { $0.value > $1.value }.prefix(3)
        let total = entries.count

        let parts = sorted.map { (app, count) -> String in
            let pct = Int((Double(count) / Double(total)) * 100)
            if pct >= 80 { return "\(app) (most of the time)" }
            if sorted.count == 1 { return app }
            return app
        }

        return parts.joined(separator: ", ")
    }

    // MARK: - Persistence

    private var fileURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Servo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("observations.json")
    }()

    private func load() -> [ObservationEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([ObservationEntry].self, from: data)) ?? []
    }

    private func save(_ entries: [ObservationEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
