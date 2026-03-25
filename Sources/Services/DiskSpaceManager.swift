import Foundation
import os.log

final class DiskSpaceManager {
    static let shared = DiskSpaceManager()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "DiskSpaceManager")
    
    private let warningThreshold: Int64 = 5 * 1024 * 1024 * 1024 // 5GB
    private let criticalThreshold: Int64 = 500 * 1024 * 1024 // 500MB
    
    private init() {}
    
    enum DiskSpaceStatus {
        case ok
        case warning
        case critical
        case insufficient
        
        var message: String {
            switch self {
            case .ok: return "Sufficient disk space"
            case .warning: return "Low disk space (\(freeSpaceDescription) free)"
            case .critical: return "Very low disk space (\(freeSpaceDescription) free)"
            case .insufficient: return "Insufficient disk space"
            }
        }
    }
    
    static var freeSpaceDescription: String {
        let freeSpace = DiskSpaceManager.shared.freeSpace
        return ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file)
    }
    
    var freeSpace: Int64 {
        let homeURL = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return values.volumeAvailableCapacityForImportantUsage ?? 0
        } catch {
            logger.error("Failed to get free space: \(error.localizedDescription)")
            return 0
        }
    }
    
    func checkSpace(forRequiredBytes bytes: Int64) -> DiskSpaceStatus {
        let available = freeSpace
        
        if available < criticalThreshold {
            return .insufficient
        } else if available < warningThreshold {
            return .critical
        } else if available < bytes {
            return .warning
        }
        
        return .ok
    }
    
    func canProceed(withRequiredBytes bytes: Int64) -> Bool {
        return checkSpace(forRequiredBytes: bytes) == .ok
    }
    
    func warnIfNeeded(forRequiredBytes bytes: Int64) {
        let status = checkSpace(forRequiredBytes: bytes)
        
        switch status {
        case .warning:
            logger.warning("Low disk space warning: \(freeSpace) bytes free")
            NotificationCenter.default.post(
                name: .diskSpaceWarning,
                object: nil,
                userInfo: ["status": status]
            )
        case .critical, .insufficient:
            logger.error("Critical disk space: \(freeSpace) bytes free")
            NotificationCenter.default.post(
                name: .diskSpaceCritical,
                object: nil,
                userInfo: ["status": status]
            )
        case .ok:
            break
        }
    }
}

extension Notification.Name {
    static let diskSpaceWarning = Notification.Name("diskSpaceWarning")
    static let diskSpaceCritical = Notification.Name("diskSpaceCritical")
}
