import Foundation
import SQLite

// Stub implementations for private MobileDevice framework functions
// These allow the build to succeed, but actual device detection requires
// special Apple entitlements and SIP to be disabled

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
        // Return empty - actual device discovery requires MobileDevice framework
        // which needs special Apple entitlements to link against on macOS 15+
        return []
    }

    private func getDeviceValue(_ device: UnsafeMutableRawPointer?, key: String) -> CFTypeRef? {
        return nil
    }

    private func getBatteryLevel(_ device: UnsafeMutableRawPointer?) -> Double {
        return 0.0
    }

    private func getChargingState(_ device: UnsafeMutableRawPointer?) -> Bool {
        return false
    }

    private func getStorageInfo(_ device: UnsafeMutableRawPointer?) -> (Int64, Int64) {
        return (0, 0)
    }

    private func getLastBackupDate() -> Date? {
        return nil
    }

    func backupDevice(_ device: Device, progressHandler: @escaping (Int64, Int64, TimeInterval?) -> Void) async -> Swift.Result<Void, Error> {
        return await withCheckedContinuation { continuation in
            continuation.resume(returning: .success(()))
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
