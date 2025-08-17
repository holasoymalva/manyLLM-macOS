import Foundation
import CoreData
import OSLog

/// Handles Core Data migrations and version management
class CoreDataMigration {
    private let logger = Logger(subsystem: "com.manyllm.desktop", category: "CoreDataMigration")
    
    /// Checks if the store needs migration
    static func requiresMigration(at storeURL: URL, toVersion version: String) -> Bool {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            return !NSManagedObjectModel.mergedModel(from: [Bundle.main])!
                .isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            return false
        }
    }
    
    /// Performs progressive migration if needed
    static func migrateStore(at storeURL: URL) throws {
        let logger = Logger(subsystem: "com.manyllm.desktop", category: "CoreDataMigration")
        
        guard requiresMigration(at: storeURL, toVersion: "1.0") else {
            logger.info("No migration required")
            return
        }
        
        logger.info("Starting Core Data migration")
        
        // Create backup before migration
        let backupURL = storeURL.appendingPathExtension("backup")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.copyItem(at: storeURL, to: backupURL)
        
        logger.info("Created backup at \(backupURL.path)")
        
        // Perform migration
        let migrationManager = NSMigrationManager(sourceModel: getSourceModel(for: storeURL),
                                                destinationModel: getCurrentModel())
        
        let mappingModel = try getMappingModel(from: getSourceModel(for: storeURL),
                                             to: getCurrentModel())
        
        let destinationURL = storeURL.appendingPathExtension("migrated")
        
        try migrationManager.migrateStore(from: storeURL,
                                        sourceType: NSSQLiteStoreType,
                                        options: nil,
                                        with: mappingModel,
                                        toDestinationURL: destinationURL,
                                        destinationType: NSSQLiteStoreType,
                                        destinationOptions: nil)
        
        // Replace original store with migrated store
        try FileManager.default.removeItem(at: storeURL)
        try FileManager.default.moveItem(at: destinationURL, to: storeURL)
        
        logger.info("Migration completed successfully")
    }
    
    /// Gets the source model for the existing store
    private static func getSourceModel(for storeURL: URL) -> NSManagedObjectModel {
        let metadata = try! NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
        
        return NSManagedObjectModel.mergedModel(from: [Bundle.main], forStoreMetadata: metadata)!
    }
    
    /// Gets the current model
    private static func getCurrentModel() -> NSManagedObjectModel {
        return NSManagedObjectModel.mergedModel(from: [Bundle.main])!
    }
    
    /// Gets the mapping model for migration
    private static func getMappingModel(from sourceModel: NSManagedObjectModel,
                                      to destinationModel: NSManagedObjectModel) throws -> NSMappingModel {
        // Try to find a custom mapping model first
        if let mappingModel = NSMappingModel(from: [Bundle.main],
                                           forSourceModel: sourceModel,
                                           destinationModel: destinationModel) {
            return mappingModel
        }
        
        // Fall back to inferred mapping
        return try NSMappingModel.inferredMappingModel(forSourceModel: sourceModel,
                                                     destinationModel: destinationModel)
    }
    
    /// Validates the store after migration
    static func validateStore(at storeURL: URL) -> Bool {
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: getCurrentModel())
            let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType,
                                                         configurationName: nil,
                                                         at: storeURL,
                                                         options: nil)
            coordinator.remove(store)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - Migration Error Types

enum MigrationError: LocalizedError {
    case sourceModelNotFound
    case destinationModelNotFound
    case mappingModelNotFound
    case migrationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .sourceModelNotFound:
            return "Source data model not found"
        case .destinationModelNotFound:
            return "Destination data model not found"
        case .mappingModelNotFound:
            return "Mapping model not found"
        case .migrationFailed(let reason):
            return "Migration failed: \(reason)"
        }
    }
}