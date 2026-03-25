import Foundation
import os.log

final class CacheManager {
    static let shared = CacheManager()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "CacheManager")
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 500 * 1024 * 1024 // 500MB
    private var inMemoryCache: [String: Data] = [:]
    private let memoryCacheLimit = 100 * 1024 * 1024 // 100MB
    private var currentMemoryUsage: Int64 = 0
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        cacheDirectory = appSupport.appendingPathComponent("Bridge/Cache", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Disk Cache
    
    func cacheToDisk(_ data: Data, forKey key: String, size: CGSize) {
        let fileURL = diskCacheURL(forKey: key, size: size)
        do {
            try data.write(to: fileURL)
            logger.debug("Cached \(data.count) bytes to disk for key \(key)")
        } catch {
            logger.error("Failed to cache to disk: \(error.localizedDescription)")
        }
    }
    
    func retrieveFromDisk(forKey key: String, size: CGSize) -> Data? {
        let fileURL = diskCacheURL(forKey: key, size: size)
        return try? Data(contentsOf: fileURL)
    }
    
    private func diskCacheURL(forKey key: String, size: CGSize) -> URL {
        let scaledKey = "\(key)_\(Int(size.width))x\(Int(size.height))"
        let hashedKey = scaledKey.data(using: .utf8)!.base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .prefix(50)
        return cacheDirectory.appendingPathComponent(String(hashedKey))
    }
    
    // MARK: - Memory Cache
    
    func cacheToMemory(_ data: Data, forKey key: String) {
        if currentMemoryUsage + Int64(data.count) > memoryCacheLimit {
            trimMemoryCache()
        }
        
        inMemoryCache[key] = data
        currentMemoryUsage += Int64(data.count)
    }
    
    func retrieveFromMemory(forKey key: String) -> Data? {
        return inMemoryCache[key]
    }
    
    private func trimMemoryCache() {
        logger.debug("Trimming memory cache")
        inMemoryCache.removeAll()
        currentMemoryUsage = 0
    }
    
    // MARK: - Cleanup
    
    func clearDiskCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        logger.info("Disk cache cleared")
    }
    
    func clearAllCaches() {
        clearDiskCache()
        inMemoryCache.removeAll()
        currentMemoryUsage = 0
        logger.info("All caches cleared")
    }
    
    func diskCacheSize() -> Int64 {
        guard let contents = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
}
