import Foundation
import SQLite
import os.log

final class DatabaseOptimizer {
    static let shared = DatabaseOptimizer()
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "DatabaseOptimizer")
    
    private init() {}
    
    // MARK: - Index Creation
    
    func createIndexes(on db: Connection) throws {
        logger.info("Creating database indexes...")
        
        // Index on sync_log table
        try db.run("CREATE INDEX IF NOT EXISTS idx_sync_log_device_id ON sync_log(device_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_sync_log_timestamp ON sync_log(timestamp)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_sync_log_status ON sync_log(status)")
        
        // Index on imported_photos table
        try db.run("CREATE INDEX IF NOT EXISTS idx_imported_photos_device_id ON imported_photos(device_id)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_imported_photos_import_date ON imported_photos(import_date)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_imported_photos_hash ON imported_photos(hash)")
        
        // Index on devices table
        try db.run("CREATE INDEX IF NOT EXISTS idx_devices_last_sync ON devices(last_sync)")
        try db.run("CREATE INDEX IF NOT EXISTS idx_devices_name ON devices(name)")
        
        logger.info("Database indexes created successfully")
    }
    
    // MARK: - Query Optimization
    
    func optimizeQueries(on db: Connection) throws {
        logger.info("Running query optimizations...")
        
        // Analyze tables for query planner
        try db.run("ANALYZE sync_log")
        try db.run("ANALYZE imported_photos")
        try db.run("ANALYZE devices")
        
        // Set cache size for better performance
        try db.execute("PRAGMA cache_size = -6400") // 6.4MB cache
        
        // Enable WAL mode for better concurrency
        try db.execute("PRAGMA journal_mode = WAL")
        
        // Enable foreign keys
        try db.execute("PRAGMA foreign_keys = ON")
        
        logger.info("Query optimizations applied")
    }
    
    // MARK: - Database Maintenance
    
    func vacuum(on db: Connection) throws {
        logger.info("Running VACUUM on database...")
        try db.execute("VACUUM")
        logger.info("Database vacuumed")
    }
    
    func reindex(on db: Connection) throws {
        logger.info("Reindexing database...")
        try db.execute("REINDEX")
        logger.info("Database reindexed")
    }
}

// MARK: - Background Indexing

final class BackgroundIndexer {
    private let logger = Logger(subsystem: "com.bridgeapp.bridge", category: "BackgroundIndexer")
    private let operationQueue: OperationQueue
    
    init() {
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = ProcessInfo.processInfo.activeProcessorCount
        operationQueue.qualityOfService = .userInitiated
    }
    
    func indexPhotos(_ photos: [Photo], hash: @escaping (Data) -> String, completion: @escaping () -> Void) {
        operationQueue.addOperation {
            for photo in photos {
                autoreleasepool {
                    if let data = try? Data(contentsOf: photo.localURL) {
                        let computedHash = hash(data)
                        photo.hash = computedHash
                    }
                }
            }
            
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}
