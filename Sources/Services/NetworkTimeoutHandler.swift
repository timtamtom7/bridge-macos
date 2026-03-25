import Foundation
import os.log

final class NetworkTimeoutHandler {
    static let shared = NetworkTimeoutHandler()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "NetworkTimeoutHandler")
    
    private let wifiTimeout: TimeInterval = 30.0
    
    private init() {}
    
    enum SyncMethod {
        case wifi
        case usb
        case automatic
    }
    
    func performWithTimeout<T>(
        method: SyncMethod,
        operation: @escaping () throws -> T,
        completion: @escaping (Result<T, Error>) -> Void
    ) {
        let timeout = wifiTimeout
        
        var didComplete = false
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        queue.async {
            do {
                let result = try operation()
                if !didComplete {
                    didComplete = true
                    DispatchQueue.main.async {
                        completion(.success(result))
                    }
                }
            } catch {
                if !didComplete {
                    didComplete = true
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
            if !didComplete {
                didComplete = true
                self.logger.warning("Operation timed out after \(timeout) seconds")
                DispatchQueue.main.async {
                    completion(.failure(NetworkTimeoutError.timeout))
                }
            }
        }
    }
    
    func fallbackSyncMethod(from wifi: @escaping () throws -> Void, to usb: @escaping () throws -> Void) {
        do {
            try wifi()
        } catch {
            logger.warning("WiFi sync failed, falling back to USB: \(error.localizedDescription)")
            do {
                try usb()
            } catch {
                logger.error("USB sync also failed: \(error.localizedDescription)")
            }
        }
    }
}

enum NetworkTimeoutError: LocalizedError {
    case timeout
    case connectionLost
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Connection timed out"
        case .connectionLost:
            return "Network connection lost"
        }
    }
}
