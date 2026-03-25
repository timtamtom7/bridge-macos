import Foundation

// MARK: - Sync History Entry

struct SyncHistoryEntry: Identifiable, Codable {
    let id: UUID
    let deviceID: UUID
    let syncType: String
    let startedAt: Date
    let completedAt: Date?
    let itemsSynced: Int
    let status: String

    init(from log: SyncLog) {
        self.id = UUID()
        self.deviceID = log.deviceID
        self.syncType = log.syncType.rawValue
        self.startedAt = log.startedAt
        self.completedAt = log.completedAt
        self.itemsSynced = log.itemsSynced
        self.status = log.status.rawValue
    }
}

// MARK: - Photo Filter

struct PhotoFilter {
    enum DateRange {
        case today, thisWeek, thisMonth, thisYear
    }

    var showDuplicates: Bool = false
    var searchText: String = ""

    var applied: Bool {
        showDuplicates || !searchText.isEmpty
    }
}

// MARK: - Export Format

enum ExportFormat: String, CaseIterable {
    case original = "Original"
    case jpeg = "JPEG"
    case png = "PNG"
}

// MARK: - Sync Service Extensions

@MainActor
final class BridgeSyncHistoryService: ObservableObject {
    @Published var entries: [SyncHistoryEntry] = []

    func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: "bridge_sync_history"),
           let decoded = try? JSONDecoder().decode([SyncHistoryEntry].self, from: data) {
            entries = decoded
        }
    }

    func addEntry(_ entry: SyncHistoryEntry) {
        entries.insert(entry, at: 0)
        if entries.count > 50 { entries = Array(entries.prefix(50)) }
        save()
    }

    private func save() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "bridge_sync_history")
        }
    }
}
