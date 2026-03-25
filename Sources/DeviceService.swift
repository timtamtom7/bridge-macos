import Foundation
import SQLite

@_silgen_name("AMDeviceCopyDeviceList")
func AMDeviceCopyDeviceList() -> CFArray?
@_silgen_name("AMDeviceConnect")
func AMDeviceConnect(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceIsPaired")
func AMDeviceIsPaired(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDevicePairingPair")
func AMDevicePairingPair(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceStartSession")
func AMDeviceStartSession(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceStopSession")
func AMDeviceStopSession(_ device: UnsafeMutableRawPointer?) -> Int32
@_silgen_name("AMDeviceCopyValue")
func AMDeviceCopyValue(_ device: UnsafeMutableRawPointer?, _ domain: CFString?, _ key: CFString?) -> CFTypeRef?
@_silgen_name("AMDeviceCopyDeviceIdentifier")
func AMDeviceCopyDeviceIdentifier(_ device: UnsafeMutableRawPointer?) -> CFString?

actor DeviceService {
    func discoverDevices() -> [Device] {
        var devices: [Device] = []
        guard let deviceList = AMDeviceCopyDeviceList() as? [UnsafeMutableRawPointer?] else { return devices }
        for rawDevice in deviceList {
            guard let device = rawDevice else { continue }
            guard AMDeviceConnect(device) == 0 else { continue }
            guard AMDeviceIsPaired(device) == 1 else { _ = AMDeviceStopSession(device); continue }
            _ = AMDevicePairingPair(device)
            guard AMDeviceStartSession(device) == 0 else { continue }
            let udid = (AMDeviceCopyDeviceIdentifier(device) as String?) ?? UUID().uuidString
            let deviceName = getDeviceValue(device, key: "DeviceName") as? String ?? "iPhone"
            let modelStr = getDeviceValue(device, key: "ModelNumber") as? String ?? "Unknown"
            let iosVer = getDeviceValue(device, key: "ProductVersion") as? String ?? "Unknown"
            let batteryLevel = getBatteryLevel(device)
            let isCharging = getChargingState(device)
            let (storageUsed, storageTotal) = getStorageInfo(device)
            let lastBackup = getLastBackupDate()
            let deviceObj = Device(udid: udid, name: deviceName, model: modelStr, iosVersion: iosVer, batteryLevel: batteryLevel, isCharging: isCharging, storageUsed: storageUsed, storageTotal: storageTotal, lastBackupDate: lastBackup, isUsingiCloudBackup: false, lastSeen: Date(), isPrimary: devices.isEmpty)
            devices.append(deviceObj)
            _ = AMDeviceStopSession(device)
        }
        return devices
    }

    private func getDeviceValue(_ device: UnsafeMutableRawPointer?, key: String) -> CFTypeRef? {
        return AMDeviceCopyValue(device, nil, key as CFString)
    }

    private func getBatteryLevel(_ device: UnsafeMutableRawPointer?) -> Double {
        let batteryDomain = "com.apple.mobile.battery" as CFString
        let batteryKey = "BatteryCurrentCapacity" as CFString
        if let battery = AMDeviceCopyValue(device, batteryDomain, batteryKey), let level = battery as? Int { return Double(level) / 100.0 }
        return 0.0
    }

    private func getChargingState(_ device: UnsafeMutableRawPointer?) -> Bool {
        let batteryDomain = "com.apple.mobile.battery" as CFString
        let chargingKey = "IsCharging" as CFString
        if let charging = AMDeviceCopyValue(device, batteryDomain, chargingKey), let state = charging as? Bool { return state }
        return false
    }

    private func getStorageInfo(_ device: UnsafeMutableRawPointer?) -> (Int64, Int64) {
        if let totalRef = AMDeviceCopyValue(device, nil, "TotalDataCapacity" as CFString),
           let total = totalRef as? Int64,
           let availRef = AMDeviceCopyValue(device, nil, "TotalDataAvailable" as CFString),
           let available = availRef as? Int64 {
            return (total - available, total)
        }
        return (0, 0)
    }

    private func getLastBackupDate() -> Date? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let backupDir = appSupport.appendingPathComponent("Bridge/Backups")
        guard let contents = try? FileManager.default.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey]) else { return nil }
        let sorted = contents.sorted { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            return dateA > dateB
        }
        if let first = sorted.first {
            return try? first.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        }
        return nil
    }

    func backupDevice(_ device: Device, progressHandler: @escaping (Int64, Int64, TimeInterval?) -> Void) async -> Swift.Result<Void, Error> {
        return await withCheckedContinuation { continuation in
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let backupDir = appSupport.appendingPathComponent("Bridge/Backups")
            try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                continuation.resume(returning: .success(()))
            }
        }
    }
}

@MainActor
final class DeviceMonitorService {
    private let store: BridgeStore
    private var timer: Timer?
    init(store: BridgeStore) { self.store = store }
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.store.refreshDevices() }
        }
        timer?.fire()
        Task { await store.refreshDevices() }
    }
    func stopMonitoring() { timer?.invalidate(); timer = nil }
    deinit { timer?.invalidate() }
}
