import Foundation
import os.log

final class EdgeCaseHandler {
    static let shared = EdgeCaseHandler()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "EdgeCaseHandler")
    
    private init() {}
    
    // MARK: - Empty State Handling
    
    func handleEmptyDevice(device: Device) -> Bool {
        let hasNoPhotos = device.photoCount == 0
        let hasNoContacts = device.contactCount == 0
        let hasNoMessages = device.messageCount == 0
        
        if hasNoPhotos && hasNoContacts && hasNoMessages {
            logger.info("Device \(device.name) is empty")
            return true
        }
        return false
    }
    
    func handleLargePhotoLibrary(photoCount: Int, progressHandler: @escaping (Double) -> Void, completion: @escaping (Result<Void, Error>) -> Void) {
        guard photoCount > 50000 else {
            completion(.success(()))
            return
        }
        
        logger.info("Large photo library detected: \(photoCount) photos")
        
        // Pagination for large libraries
        let pageSize = 1000
        let totalPages = (photoCount + pageSize - 1) / pageSize
        
        for page in 0..<totalPages {
            autoreleasepool {
                let progress = Double(page) / Double(totalPages)
                progressHandler(progress)
                
                // Process page...
            }
        }
        
        progressHandler(1.0)
        completion(.success(()))
    }
    
    // MARK: - Device Disambiguation
    
    func disambiguateDevices(_ devices: [Device]) -> [Device] {
        var seenNames: [String: Int] = [:]
        
        return devices.map { device in
            var updatedDevice = device
            
            if let count = seenNames[device.name] {
                seenNames[device.name] = count + 1
                updatedDevice.displayName = "\(device.name) (\(device.udid.suffix(4)))"
            } else {
                seenNames[device.name] = 1
            }
            
            return updatedDevice
        }
    }
    
    // MARK: - Passcode Lock Handling
    
    func handlePasscodeLockedDevice() -> PasscodeLockAction {
        logger.warning("Device is locked with passcode")
        NotificationCenter.default.post(name: .devicePasscodeLocked, object: nil)
        return .showUnlockPrompt
    }
    
    // MARK: - Import Cancellation
    
    func cancelImport() {
        logger.info("Import cancelled by user")
        NotificationCenter.default.post(name: .importCancelled, object: nil)
    }
}

enum PasscodeLockAction {
    case showUnlockPrompt
    case skipDevice
    case retryLater
}

extension Notification.Name {
    static let devicePasscodeLocked = Notification.Name("devicePasscodeLocked")
    static let importCancelled = Notification.Name("importCancelled")
}
