import Foundation
import Combine
import AppKit

class PatternLibrary: ObservableObject {
    @Published var entries: [PatternEntry] = []
    @Published var activeEntryID: UUID? = nil

    private let storageURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("CrochetApp", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("patterns.json")
    }()

    // MARK: - Computed

    var pinned: [PatternEntry] {
        entries.filter(\.isPinned).sorted { $0.lastOpened > $1.lastOpened }
    }

    var recent: [PatternEntry] {
        entries.filter { !$0.isPinned }
            .sorted { $0.lastOpened > $1.lastOpened }
    }

    var activeEntry: PatternEntry? {
        entries.first { $0.id == activeEntryID }
    }

    // MARK: - Init

    init() {
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    // MARK: - Public API

    @discardableResult
    func add(url: URL) -> UUID? {
        if let existing = entries.first(where: { $0.resolveURL() == url }) {
            return existing.id
        }
        guard var entry = try? PatternEntry(url: url) else { return nil }
        let s = AppSettings.shared
        if s.defaultRowGoal > 0 { entry.rowGoal = s.defaultRowGoal }
        if s.defaultStitchGoal > 0 { entry.stitchGoal = s.defaultStitchGoal }
        entries.append(entry)
        save()
        return entry.id
    }

    func select(entryID: UUID) {
        activeEntryID = entryID
    }

    func updateActiveCounters(row: Int, stitch: Int, repeat repeatCount: Int, autoReset: Bool) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let changed = entries[i].rowCount != row || entries[i].stitchCount != stitch || entries[i].repeatCount != repeatCount
        entries[i].rowCount = row
        entries[i].stitchCount = stitch
        entries[i].repeatCount = repeatCount
        entries[i].autoResetStitch = autoReset
        if changed { entries[i].lastOpened = Date() }
        save()
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        if activeEntryID == entryID { activeEntryID = nil }
        save()
    }

    func togglePin(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].isPinned.toggle()
        save()
    }

    func toggleRepeatCounter(entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].showRepeatCounter.toggle()
        if !entries[i].showRepeatCounter { entries[i].repeatCount = 0 }
        save()
    }

    /// Called from AnnotationBridge when JS saves or deletes a note.
    /// Key is a text fingerprint (first 64 chars of block text).
    func updateNote(key: String, text: String?) {
        guard let id = activeEntryID,
              let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let text = text, !text.isEmpty {
            entries[i].annotations[key] = text
        } else {
            entries[i].annotations.removeValue(forKey: key)
        }
        save()
    }

    /// Persist AI analysis results for a pattern so they don't need to be re-run on next launch.
    func updateAICache(
        for entryID: UUID,
        summary: PatternSummary? = nil,
        abbreviations: AbbreviationList? = nil,
        materials: MaterialsBreakdown? = nil,
        difficulty: String? = nil,
        timeEstimate: String? = nil
    ) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        if let v = summary { entries[i].aiSummary = v }
        if let v = abbreviations { entries[i].aiAbbreviations = v }
        if let v = materials { entries[i].aiMaterials = v }
        if let v = difficulty { entries[i].aiDifficulty = v }
        if let v = timeEstimate { entries[i].aiTimeEstimate = v }
        save()
    }

    func clearAICache(for entryID: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == entryID }) else { return }
        entries[i].aiSummary = nil
        entries[i].aiAbbreviations = nil
        entries[i].aiMaterials = nil
        entries[i].aiDifficulty = nil
        entries[i].aiTimeEstimate = nil
        save()
    }

    // MARK: - Persistence

    func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([PatternEntry].self, from: data) else { return }
        entries = decoded
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func appWillTerminate() {
        save()
    }
}
