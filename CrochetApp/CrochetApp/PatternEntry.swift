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
    }

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
