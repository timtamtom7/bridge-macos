import Foundation

final class DeviceService {
    var onDeviceConnected: ((DeviceInfo) -> Void)?
    var onDeviceDisconnected: ((String) -> Void)?
    private var isMonitoring = false

    init() {}
    deinit { stopMonitoring() }

    func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
    }

    func backupDevice(_ udid: String, to path: String, progress: @escaping (Double) -> Void) async throws {
        for i in 1...10 {
            try await Task.sleep(nanoseconds: 100_000_000)
            progress(Double(i) / 10.0)
        }
    }

    func iCloudBackupEnabled(for udid: String) async -> Bool {
        false
    }

    func mountDevice(_ udid: String) -> String? {
        nil
    }

    func unmountDevice(_ udid: String) {
    }
}
