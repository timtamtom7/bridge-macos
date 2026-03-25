import Foundation
import os.log

final class ErrorRecoveryService {
    static let shared = ErrorRecoveryService()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "ErrorRecoveryService")
    
    private let maxRetries = 3
    private let baseDelay: TimeInterval = 1.0
    
    private init() {}
    
    // MARK: - AFC Error Recovery
    
    func withAFCRetry<T>(_ operation: @escaping () throws -> T) throws -> T {
        var lastError: Error?
        var delay = baseDelay
        
        for attempt in 1...maxRetries {
            do {
                return try operation()
            } catch {
                lastError = error
                logger.warning("AFC operation failed (attempt \(attempt)/\(self.maxRetries)): \(error.localizedDescription)")
                
                if attempt < maxRetries {
                    Thread.sleep(forTimeInterval: delay)
                    delay *= 2 // Exponential backoff
                }
            }
        }
        
        logger.error("AFC operation failed after \(maxRetries) attempts")
        throw lastError ?? ErrorRecoveryError.maxRetriesExceeded
    }
    
    // MARK: - Sync Recovery
    
    func handleDeviceDisconnect(syncState: SyncState, completion: @escaping (SyncRecoveryAction) -> Void) {
        logger.warning("Device disconnected during sync")
        
        syncState.pause()
        
        NotificationCenter.default.post(
            name: .deviceDisconnectedDuringSync,
            object: nil,
            userInfo: ["syncState": syncState]
        )
        
        completion(.pauseAndWait)
    }
    
    func resumeSync(from syncState: SyncState) {
        logger.info("Resuming sync from previous state")
        syncState.resume()
        NotificationCenter.default.post(name: .syncResumed, object: nil)
    }
    
    func abortSync(from syncState: SyncState) {
        logger.info("Aborting sync")
        syncState.abort()
        NotificationCenter.default.post(name: .syncAborted, object: nil)
    }
    
    // MARK: - Crash Recovery
    
    func checkForIncompleteSync() -> IncompleteSyncInfo? {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "incompleteSyncInProgress") {
            return IncompleteSyncInfo(
                deviceID: defaults.string(forKey: "incompleteSyncDeviceID"),
                lastProgress: defaults.integer(forKey: "incompleteSyncProgress"),
                timestamp: defaults.object(forKey: "incompleteSyncTimestamp") as? Date
            )
        }
        return nil
    }
    
    func markSyncInProgress(deviceID: String, progress: Int) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "incompleteSyncInProgress")
        defaults.set(deviceID, forKey: "incompleteSyncDeviceID")
        defaults.set(progress, forKey: "incompleteSyncProgress")
        defaults.set(Date(), forKey: "incompleteSyncTimestamp")
    }
    
    func clearSyncInProgress() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: "incompleteSyncInProgress")
        defaults.removeObject(forKey: "incompleteSyncDeviceID")
        defaults.removeObject(forKey: "incompleteSyncProgress")
        defaults.removeObject(forKey: "incompleteSyncTimestamp")
    }
    
    // MARK: - Archive Verification
    
    func verifyArchive(at url: URL, expectedHash: String) throws -> Bool {
        guard let data = try? Data(contentsOf: url) else {
            throw ErrorRecoveryError.archiveReadError
        }
        
        let computedHash = data.sha256Hash()
        
        if computedHash != expectedHash {
            logger.error("Archive hash mismatch: expected \(expectedHash), got \(computedHash)")
            throw ErrorRecoveryError.archiveCorrupted
        }
        
        return true
    }
    
    func sha256Hash(for data: Data) -> String {
        return data.sha256Hash()
    }
}

// MARK: - Supporting Types

enum SyncRecoveryAction {
    case pauseAndWait
    case resumeWhenReconnected
    case abort
}

enum ErrorRecoveryError: LocalizedError {
    case maxRetriesExceeded
    case archiveReadError
    case archiveCorrupted
    case deviceDisconnected
    
    var errorDescription: String? {
        switch self {
        case .maxRetriesExceeded:
            return "Operation failed after multiple attempts"
        case .archiveReadError:
            return "Failed to read archive"
        case .archiveCorrupted:
            return "Archive is corrupted (hash mismatch)"
        case .deviceDisconnected:
            return "Device was disconnected"
        }
    }
}

struct SyncState {
    var isPaused: Bool = false
    var isAborted: Bool = false
    var progress: Int = 0
    var deviceID: String?
    
    mutating func pause() { isPaused = true }
    mutating func resume() { isPaused = false }
    mutating func abort() { isAborted = true }
}

struct IncompleteSyncInfo {
    let deviceID: String?
    let lastProgress: Int
    let timestamp: Date?
}

// MARK: - Notifications

extension Notification.Name {
    static let deviceDisconnectedDuringSync = Notification.Name("deviceDisconnectedDuringSync")
    static let syncResumed = Notification.Name("syncResumed")
    static let syncAborted = Notification.Name("syncAborted")
}

// MARK: - Data Extension

extension Data {
    func sha256Hash() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

import CommonCrypto
