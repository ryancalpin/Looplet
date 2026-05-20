import Foundation

struct PatternEntry: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var bookmark: Data
    var lastOpened: Date
    var isPinned: Bool
    var rowCount: Int
    var stitchCount: Int
    var autoResetStitch: Bool

    // MARK: - Goals
    var rowGoal: Int?        // nil = no goal, no progress bar
    var stitchGoal: Int?     // nil = no auto-advance

    // MARK: - Annotations
    // Key: paragraph index (0-based order of <p> and <li> in rendered HTML)
    // Value: note text
    var annotations: [Int: String]

    init(url: URL) throws {
        self.id = UUID()
        self.displayName = url.deletingPathExtension().lastPathComponent
        self.bookmark = try url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.lastOpened = Date()
        self.isPinned = false
        self.rowCount = 0
        self.stitchCount = 0
        self.autoResetStitch = true
        self.rowGoal = nil
        self.stitchGoal = nil
        self.annotations = [:]
    }

    /// Returns a security-scoped URL for the bookmarked file.
    /// Caller must call `url.startAccessingSecurityScopedResource()` before any file I/O
    /// and `url.stopAccessingSecurityScopedResource()` when done.
    func resolveURL() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return url
    }
}
