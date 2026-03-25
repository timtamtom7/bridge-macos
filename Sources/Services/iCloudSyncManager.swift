import Foundation

@MainActor
final class BridgeSyncManager: ObservableObject {
    static let shared = BridgeSyncManager()

    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSynced: Date?

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced
        case offline
        case error(String)
    }

    private let store = NSUbiquitousKeyValueStore.default
    private var observers: [NSObjectProtocol] = []

    private init() {
        setupObservers()
    }

    private func setupObservers() {
        let notification = NSUbiquitousKeyValueStore.didChangeExternallyNotification
        let observer = NotificationCenter.default.addObserver(
            forName: notification,
            object: store,
            queue: .main
        ) { [weak self] _ in
            self?.handleExternalChange()
        }
        observers.append(observer)
    }

    // MARK: - Sync Data

    struct SyncPayload: Codable {
        var deviceHistory: [DeviceSnapshot]
        var settings: BridgeSettings

        struct BridgeSettings: Codable {
            var autoBackup: Bool
            var syncPhotos: Bool
        }
    }

    struct DeviceSnapshot: Codable {
        let deviceId: String
        let timestamp: Date
        let batteryLevel: Double
        let storageUsed: Int64
        let storageTotal: Int64
    }

    func sync() {
        guard isICloudAvailable else {
            syncStatus = .offline
            return
        }

        syncStatus = .syncing

        do {
            let payload = buildPayload()
            let data = try JSONEncoder().encode(payload)
            store.set(data, forKey: "bridge.sync.data")
            store.synchronize()

            syncStatus = .synced
            lastSynced = Date()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    func pullFromCloud() {
        guard isICloudAvailable else { return }

        guard let data = store.data(forKey: "bridge.sync.data"),
              let payload = try? JSONDecoder().decode(SyncPayload.self, from: data) else {
            return
        }

        applyPayload(payload)
    }

    private func buildPayload() -> SyncPayload {
        let settings = SyncPayload.BridgeSettings(
            autoBackup: UserDefaults.standard.bool(forKey: "bridge_autoBackup"),
            syncPhotos: UserDefaults.standard.bool(forKey: "bridge_syncPhotos")
        )

        let devices = BridgeState.shared.devices
        let snapshots = devices.map { device in
            DeviceSnapshot(
                deviceId: device.udid,
                timestamp: Date(),
                batteryLevel: device.batteryLevel,
                storageUsed: device.storageUsed,
                storageTotal: device.storageTotal
            )
        }

        return SyncPayload(deviceHistory: snapshots, settings: settings)
    }

    private func applyPayload(_ payload: SyncPayload) {
        UserDefaults.standard.set(payload.settings.autoBackup, forKey: "bridge_autoBackup")
        UserDefaults.standard.set(payload.settings.syncPhotos, forKey: "bridge_syncPhotos")
    }

    private func handleExternalChange() {
        pullFromCloud()
        syncStatus = .synced
        lastSynced = Date()
    }

    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    func syncNow() {
        sync()
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
