import Foundation
import Combine
import AppKit
import Photos
import SQLite

@MainActor
final class BridgeStore: ObservableObject {
    @Published var connectedDevice: Device?
    @Published var devices: [Device] = []
    @Published var photos: [Photo] = []
    @Published var selectedPhotos: Set<UUID> = []
    @Published var contacts: [Contact] = []
    @Published var isScanning = false
    @Published var isImporting = false
    @Published var isSyncingContacts = false
    @Published var isBackingUp = false
    @Published var importProgress: ImportProgress = .idle
    @Published var backupProgress: BackupProgress = .idle
    @Published var errorMessage: String?
    @Published var isDeviceConnected = false

    let deviceService: DeviceService
    let photoService: PhotoService
    let contactService: ContactService
    let settingsStore: SettingsStore
    private var db: Connection?

    init() {
        self.deviceService = DeviceService()
        self.photoService = PhotoService()
        self.contactService = ContactService()
        self.settingsStore = SettingsStore()
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let bridgeDir = appSupport.appendingPathComponent("Bridge", isDirectory: true)
            try FileManager.default.createDirectory(at: bridgeDir, withIntermediateDirectories: true)
            db = try Connection(bridgeDir.appendingPathComponent("bridge.db").path)

            let devicesTable = Table("devices")
            let syncLogTable = Table("sync_log")
            let importedPhotosTable = Table("imported_photos")

            try db?.run(devicesTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("udid"), unique: true)
                t.column(Expression<String>("name"))
                t.column(Expression<String>("model"))
                t.column(Expression<String>("ios_version"))
                t.column(Expression<Date>("last_seen"))
                t.column(Expression<Bool>("is_primary"))
            })

            try db?.run(syncLogTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("device_id"))
                t.column(Expression<String>("sync_type"))
                t.column(Expression<Date>("started_at"))
                t.column(Expression<Date?>("completed_at"))
                t.column(Expression<Int>("items_synced"))
                t.column(Expression<String>("status"))
            })

            try db?.run(importedPhotosTable.create(ifNotExists: true) { t in
                t.column(Expression<String>("id"), primaryKey: true)
                t.column(Expression<String>("device_id"))
                t.column(Expression<String>("filename"))
                t.column(Expression<Date>("import_date"))
                t.column(Expression<String>("mac_url"))
            })
        } catch {
            errorMessage = "Database setup failed: \(error.localizedDescription)"
        }
    }

    func refreshDevices() async {
        isScanning = true
        defer { isScanning = false }
        let foundDevices = await deviceService.discoverDevices()
        devices = foundDevices
        if let primary = foundDevices.first(where: { $0.isPrimary }) ?? foundDevices.first {
            connectedDevice = primary
            isDeviceConnected = true
        } else {
            connectedDevice = nil
            isDeviceConnected = false
        }
    }

    func scanPhotos() async {
        guard let device = connectedDevice else { return }
        isScanning = true
        importProgress = .scanning(total: 0)
        defer { isScanning = false }
        let discoveredPhotos = await photoService.scanPhotosFromDevice(device)
        var photosWithDuplicates: [Photo] = []
        for var photo in discoveredPhotos {
            photo.isDuplicate = await photoService.isDuplicate(photo)
            photosWithDuplicates.append(photo)
        }
        photos = photosWithDuplicates
        importProgress = .scanning(total: photos.count)
    }

    func togglePhotoSelection(_ photo: Photo) {
        if selectedPhotos.contains(photo.id) {
            selectedPhotos.remove(photo.id)
        } else {
            selectedPhotos.insert(photo.id)
        }
        if let idx = photos.firstIndex(where: { $0.id == photo.id }) {
            photos[idx].isSelected.toggle()
        }
    }

    func selectAllPhotos() {
        selectedPhotos = Set(photos.filter { !$0.isDuplicate }.map { $0.id })
        for i in photos.indices {
            if !photos[i].isDuplicate { photos[i].isSelected = true }
        }
    }

    func deselectAllPhotos() {
        selectedPhotos.removeAll()
        for i in photos.indices { photos[i].isSelected = false }
    }

    func importSelectedPhotos() async {
        guard let device = connectedDevice else { return }
        let toImport = photos.filter { selectedPhotos.contains($0.id) && !$0.isDuplicate }
        guard !toImport.isEmpty else { return }
        isImporting = true
        importProgress = .importing(current: 0, total: toImport.count)
        defer { isImporting = false }
        var imported = 0
        var skipped = 0
        for (index, photo) in toImport.enumerated() {
            importProgress = .importing(current: index + 1, total: toImport.count)
            let success = await photoService.importPhoto(photo, from: device)
            if success {
                imported += 1
                recordImportedPhoto(photo)
            } else {
                skipped += 1
            }
        }
        importProgress = .completed(imported: imported, skipped: skipped)
        selectedPhotos.removeAll()
    }

    private func recordImportedPhoto(_ photo: Photo) {
        guard let device = connectedDevice, let db = db else { return }
        do {
            try db.run(Table("imported_photos").insert(
                Expression<String>("id") <- photo.id.uuidString,
                Expression<String>("device_id") <- device.udid,
                Expression<String>("filename") <- photo.filename,
                Expression<Date>("import_date") <- Date(),
                Expression<String>("mac_url") <- photo.path
            ))
        } catch { }
    }

    func syncContacts() async {
        guard let device = connectedDevice else { return }
        isSyncingContacts = true
        defer { isSyncingContacts = false }
        let deviceContacts = await contactService.fetchContacts(from: device)
        let macContacts = contactService.fetchMacContacts()
        var merged: [Contact] = []
        for dc in deviceContacts {
            if let mc = macContacts.first(where: { $0.fullName == dc.fullName }) {
                merged.append(dc.lastModified > mc.lastModified ? dc : mc)
            } else {
                merged.append(dc)
            }
        }
        contacts = merged
        contactService.saveContactsToMac(merged)
        recordSync(deviceID: device.id, type: .contacts, items: merged.count)
    }

    func backupNow() async {
        guard let device = connectedDevice else { return }
        isBackingUp = true
        backupProgress = .inProgress(bytesCopied: 0, totalBytes: 0, estimatedTime: nil)
        defer { isBackingUp = false }
        let result = await deviceService.backupDevice(device) { [weak self] copied, total, eta in
            Task { @MainActor [weak self] in
                self?.backupProgress = .inProgress(bytesCopied: copied, totalBytes: total, estimatedTime: eta)
            }
        }
        switch result {
        case .success:
            backupProgress = .completed
            recordSync(deviceID: device.id, type: .backup, items: 0)
        case .failure(let error):
            backupProgress = .failed(error.localizedDescription)
        }
    }

    private func recordSync(deviceID: UUID, type: SyncLog.SyncType, items: Int) {
        guard let db = db else { return }
        do {
            try db.run(Table("sync_log").insert(
                Expression<String>("id") <- UUID().uuidString,
                Expression<String>("device_id") <- deviceID.uuidString,
                Expression<String>("sync_type") <- type.rawValue,
                Expression<Date>("started_at") <- Date(),
                Expression<Date?>("completed_at") <- Date(),
                Expression<Int>("items_synced") <- items,
                Expression<String>("status") <- SyncLog.SyncStatus.completed.rawValue
            ))
        } catch { }
    }

    func loadSettings() { settingsStore.load() }
    func saveSettings() { settingsStore.save() }
}
