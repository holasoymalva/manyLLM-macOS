import Foundation
import CoreData
import OSLog

/// Core Data stack manager for ManyLLM application
class CoreDataStack: ObservableObject {
    static let shared = CoreDataStack()
    
    private let logger = Logger(subsystem: "com.manyllm.desktop", category: "CoreData")
    
    /// The persistent container for the application
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ManyLLM")
        
        // Configure store description for better performance and security
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Enable file protection for privacy
        storeDescription?.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        container.loadPersistentStores { [weak self] _, error in
            if let error = error as NSError? {
                self?.logger.error("Core Data failed to load store: \(error.localizedDescription)")
                // In production, you might want to handle this more gracefully
                fatalError("Core Data failed to load store: \(error)")
            } else {
                self?.logger.info("Core Data store loaded successfully")
            }
        }
        
        // Configure automatic merging of changes
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        return container
    }()
    
    /// The main managed object context for UI operations
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    /// Creates a new background context for data operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Saves the view context if it has changes
    func save() throws {
        let context = viewContext
        
        guard context.hasChanges else {
            logger.debug("No changes to save in view context")
            return
        }
        
        do {
            try context.save()
            logger.debug("View context saved successfully")
        } catch {
            logger.error("Failed to save view context: \(error.localizedDescription)")
            throw ManyLLMError.storageError("Failed to save data: \(error.localizedDescription)")
        }
    }
    
    /// Saves a background context
    func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else {
            logger.debug("No changes to save in background context")
            return
        }
        
        do {
            try context.save()
            logger.debug("Background context saved successfully")
        } catch {
            logger.error("Failed to save background context: \(error.localizedDescription)")
            throw ManyLLMError.storageError("Failed to save data: \(error.localizedDescription)")
        }
    }
    
    /// Performs a background task with automatic saving
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            let context = newBackgroundContext()
            
            context.perform {
                do {
                    let result = try block(context)
                    
                    if context.hasChanges {
                        try context.save()
                    }
                    
                    continuation.resume(returning: result)
                } catch {
                    self.logger.error("Background task failed: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Deletes all data from the persistent store (for testing or reset)
    func deleteAllData() throws {
        let context = viewContext
        
        // Delete all entities
        let entityNames = ["WorkspaceEntity", "ChatSessionEntity", "MessageEntity", "DocumentEntity", "DocumentChunkEntity"]
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try context.execute(deleteRequest)
                logger.info("Deleted all \(entityName) records")
            } catch {
                logger.error("Failed to delete \(entityName): \(error.localizedDescription)")
                throw ManyLLMError.storageError("Failed to delete \(entityName): \(error.localizedDescription)")
            }
        }
        
        try save()
        logger.info("All data deleted successfully")
    }
    
    /// Checks if the persistent store is accessible
    func isStoreAccessible() -> Bool {
        do {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "WorkspaceEntity")
            fetchRequest.fetchLimit = 1
            _ = try viewContext.fetch(fetchRequest)
            return true
        } catch {
            logger.error("Store accessibility check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private init() {
        logger.info("CoreDataStack initialized")
    }
}

// MARK: - Migration Support

extension CoreDataStack {
    /// Checks if migration is needed
    func migrationNeeded() -> Bool {
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            
            let model = persistentContainer.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            logger.error("Migration check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Performs lightweight migration if needed
    func performMigrationIfNeeded() throws {
        if migrationNeeded() {
            logger.info("Core Data migration needed, performing automatic migration")
            
            let storeDescription = persistentContainer.persistentStoreDescriptions.first
            storeDescription?.shouldMigrateStoreAutomatically = true
            storeDescription?.shouldInferMappingModelAutomatically = true
            
            // The migration will happen automatically when the store loads
            logger.info("Migration configuration completed")
        }
    }
}