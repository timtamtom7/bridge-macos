import Foundation

struct Device: Identifiable, Equatable {
    let id: UUID
    let udid: String
    var name: String
    var model: String
    var iosVersion: String
    var batteryLevel: Double
    var isCharging: Bool
    var storageUsed: Int64
    var storageTotal: Int64
    var lastBackupDate: Date?
    var isUsingiCloudBackup: Bool
    var lastSeen: Date
    var isPrimary: Bool
    var photoCount: Int { 0 }
    var contactCount: Int { 0 }
    var messageCount: Int { 0 }
    var displayName: String { name }
    mutating func setDisplayName(_ newName: String) { name = newName }

    init(id: UUID = UUID(), udid: String, name: String = "Unknown Device",
         model: String = "Unknown", iosVersion: String = "Unknown",
         batteryLevel: Double = 0, isCharging: Bool = false,
         storageUsed: Int64 = 0, storageTotal: Int64 = 0,
         lastBackupDate: Date? = nil, isUsingiCloudBackup: Bool = false,
         lastSeen: Date = Date(), isPrimary: Bool = false) {
        self.id = id; self.udid = udid; self.name = name; self.model = model
        self.iosVersion = iosVersion; self.batteryLevel = batteryLevel
        self.isCharging = isCharging; self.storageUsed = storageUsed
        self.storageTotal = storageTotal; self.lastBackupDate = lastBackupDate
        self.isUsingiCloudBackup = isUsingiCloudBackup; self.lastSeen = lastSeen
        self.isPrimary = isPrimary
    }

    var storageProgress: Double { guard storageTotal > 0 else { return 0 }; return Double(storageUsed) / Double(storageTotal) }
    var formattedStorageUsed: String { ByteCountFormatter.string(fromByteCount: storageUsed, countStyle: .file) }
    var formattedStorageTotal: String { ByteCountFormatter.string(fromByteCount: storageTotal, countStyle: .file) }
    var formattedBattery: String { "\(Int(batteryLevel * 100))%" }
}

struct Photo: Identifiable, Equatable {
    let id: UUID
    let filename: String
    let path: String
    let creationDate: Date?
    let fileSize: Int64
    var thumbnailData: Data?
    var isSelected: Bool
    var isDuplicate: Bool
    var localURL: URL { URL(fileURLWithPath: path) }
    var hash: String?

    init(id: UUID = UUID(), filename: String, path: String, creationDate: Date? = nil,
         fileSize: Int64 = 0, thumbnailData: Data? = nil, isSelected: Bool = false, isDuplicate: Bool = false) {
        self.id = id; self.filename = filename; self.path = path; self.creationDate = creationDate
        self.fileSize = fileSize; self.thumbnailData = thumbnailData; self.isSelected = isSelected
        self.isDuplicate = isDuplicate
    }

    var formattedSize: String { ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file) }
}

struct Contact: Identifiable, Equatable {
    let id: UUID
    var givenName: String
    var familyName: String
    var phoneNumbers: [String]
    var emails: [String]
    var addresses: [String]
    var notes: String
    var lastModified: Date
    var deviceUDID: String

    init(id: UUID = UUID(), givenName: String = "", familyName: String = "",
         phoneNumbers: [String] = [], emails: [String] = [], addresses: [String] = [],
         notes: String = "", lastModified: Date = Date(), deviceUDID: String = "") {
        self.id = id; self.givenName = givenName; self.familyName = familyName
        self.phoneNumbers = phoneNumbers; self.emails = emails; self.addresses = addresses
        self.notes = notes; self.lastModified = lastModified; self.deviceUDID = deviceUDID
    }

    var fullName: String { [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ") }
}

struct SyncLog: Identifiable {
    let id: UUID
    let deviceID: UUID
    let syncType: SyncType
    let startedAt: Date
    var completedAt: Date?
    var itemsSynced: Int
    var status: SyncStatus

    enum SyncType: String { case photos, contacts, backup }
    enum SyncStatus: String { case inProgress = "in_progress", completed, failed }
}

enum ImportProgress: Equatable {
    case idle
    case scanning(total: Int)
    case importing(current: Int, total: Int)
    case completed(imported: Int, skipped: Int)
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .scanning(let total): return "Scanning... \(total) photos found"
        case .importing(let current, let total): return "Importing \(current)/\(total)"
        case .completed(let imported, let skipped): return "Done! \(imported) imported, \(skipped) skipped"
        case .failed(let msg): return "Failed: \(msg)"
        }
    }
}

enum BackupProgress: Equatable {
    case idle
    case inProgress(bytesCopied: Int64, totalBytes: Int64, estimatedTime: TimeInterval?)
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .inProgress(let copied, let total, _):
            let pct = total > 0 ? Int(Double(copied) / Double(total) * 100) : 0
            return "Backing up \(pct)% (\(ByteCountFormatter.string(fromByteCount: copied, countStyle: .file))/\(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)))"
        case .completed: return "Backup complete"
        case .failed(let msg): return "Backup failed: \(msg)"
        }
    }
}
