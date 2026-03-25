import Foundation
import SQLite

final class SettingsStore {
    private let db: Connection
    private let appSupportPath: String

    private let devices = Table("devices")
    private let syncLog = Table("sync_log")
    private let importedPhotos = Table("imported_photos")

    private let id = Expression<Int64>("id")
    private let udid = Expression<String>("udid")
    private let name = Expression<String>("name")
    private let model = Expression<String>("model")
    private let iosVersion = Expression<String>("ios_version")
    private let lastSeen = Expression<Date>("last_seen")
    private let isPrimary = Expression<Bool>("is_primary")
    private let deviceId = Expression<String>("device_id")
    private let syncType = Expression<String>("sync_type")
    private let startedAt = Expression<Date>("started_at")
    private let completedAt = Expression<Date?>("completed_at")
    private let itemsSynced = Expression<Int>("items_synced")
    private let status = Expression<String>("status")
    private let filename = Expression<String>("filename")
    private let importDate = Expression<Date>("import_date")
    private let macUrl = Expression<String>("mac_url")

    private var kvStore: [String: Any] = [:]

    init() {
        let fm = FileManager.default
        let homeDir = fm.homeDirectoryForCurrentUser
        appSupportPath = homeDir.appendingPathComponent("Library/Application Support/Bridge").path
        try? fm.createDirectory(atPath: appSupportPath, withIntermediateDirectories: true)
        let dbPath = (appSupportPath as NSString).appendingPathComponent("bridge.db")
        db = try! Connection(dbPath)
        createTables()
        loadKVStore()
    }

    private func createTables() {
        do {
            try db.run(devices.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(udid, unique: true)
                t.column(name)
                t.column(model)
                t.column(iosVersion)
                t.column(lastSeen)
                t.column(isPrimary, defaultValue: false)
            })
            try db.run(syncLog.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(deviceId)
                t.column(syncType)
                t.column(startedAt)
                t.column(completedAt)
                t.column(itemsSynced)
                t.column(status)
            })
            try db.run(importedPhotos.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(deviceId)
                t.column(filename)
                t.column(importDate)
                t.column(macUrl)
            })
        } catch {
            print("Failed to create tables: \(error)")
        }
    }

    private func loadKVStore() {
        let kvPath = (appSupportPath as NSString).appendingPathComponent("settings.json")
        if let data = FileManager.default.contents(atPath: kvPath),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            kvStore = dict
        }
    }

    private func saveKVStore() {
        let kvPath = (appSupportPath as NSString).appendingPathComponent("settings.json")
        if let data = try? JSONSerialization.data(withJSONObject: kvStore) {
            try? data.write(to: URL(fileURLWithPath: kvPath))
        }
    }

    func set(_ value: Any?, forKey key: String) {
        if let value = value {
            kvStore[key] = value
        } else {
            kvStore.removeValue(forKey: key)
        }
        saveKVStore()
    }

    func string(forKey key: String) -> String? {
        kvStore[key] as? String
    }

    func bool(forKey key: String) -> Bool? {
        kvStore[key] as? Bool
    }

    func date(forKey key: String) -> Date? {
        kvStore[key] as? Date
    }

    func saveDevice(_ device: DeviceInfo) {
        do {
            let existingCount = try db.scalar(devices.filter(udid == device.udid).count)
            if existingCount > 0 {
                try db.run(devices.filter(udid == device.udid).update(
                    name <- device.name,
                    model <- device.model,
                    iosVersion <- device.iosVersion,
                    lastSeen <- device.lastSeen
                ))
            } else {
                try db.run(devices.insert(
                    udid <- device.udid,
                    name <- device.name,
                    model <- device.model,
                    iosVersion <- device.iosVersion,
                    lastSeen <- device.lastSeen,
                    isPrimary <- false
                ))
            }
        } catch {
            print("Failed to save device: \(error)")
        }
    }

    func logSync(deviceId: String, syncType: String, itemsSynced count: Int, status: String = "completed") {
        do {
            try db.run(syncLog.insert(
                self.deviceId <- deviceId,
                self.syncType <- syncType,
                startedAt <- Date(),
                completedAt <- Date(),
                itemsSynced <- count,
                self.status <- status
            ))
        } catch {
            print("Failed to log sync: \(error)")
        }
    }

    func importedPhotoFilenames(for deviceId: String) -> [String] {
        do {
            return try db.prepare(importedPhotos.filter(self.deviceId == deviceId)).map { $0[filename] }
        } catch {
            print("Failed: \(error)")
            return []
        }
    }
}
