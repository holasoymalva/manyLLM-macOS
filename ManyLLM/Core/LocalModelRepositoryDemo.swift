import Foundation
import OSLog

/// Demonstration class showing how to use LocalModelRepository
/// This can be used for integration testing and as a usage example
class LocalModelRepositoryDemo {
    private let repository: LocalModelRepository
    private let logger = Logger(subsystem: "com.manyllm.app", category: "LocalModelRepositoryDemo")
    
    init() throws {
        self.repository = try LocalModelRepository()
    }
    
    /// Demonstrate basic repository operations
    func demonstrateBasicOperations() async {
        logger.info("Starting LocalModelRepository demonstration")
        
        // 1. Check initial state
        let initialModels = repository.getLocalModels()
        logger.info("Initial local models count: \(initialModels.count)")
        
        // 2. Create a sample model for demonstration
        let sampleModel = createSampleModel()
        logger.info("Created sample model: \(sampleModel.name)")
        
        // 3. Demonstrate search functionality
        do {
            let searchResults = try await repository.searchModels(query: "sample")
            logger.info("Search results for 'sample': \(searchResults.count) models")
        } catch {
            logger.error("Search failed: \(error.localizedDescription)")
        }
        
        // 4. Get storage statistics
        let stats = repository.getStorageStatistics()
        logger.info("Storage statistics - Models: \(stats.modelCount), Total size: \(stats.totalSize) bytes")
        
        // 5. Demonstrate model verification (if we had a local model)
        if let firstModel = initialModels.first {
            do {
                let isValid = try await repository.verifyModelIntegrity(firstModel)
                logger.info("Model \(firstModel.name) integrity check: \(isValid ? "PASSED" : "FAILED")")
            } catch {
                logger.error("Model verification failed: \(error.localizedDescription)")
            }
        }
        
        logger.info("LocalModelRepository demonstration completed")
    }
    
    /// Demonstrate adding a model from a file (requires actual file)
    func demonstrateModelAddition(from filePath: URL) async {
        logger.info("Demonstrating model addition from: \(filePath.path)")
        
        do {
            let sampleModel = createSampleModel()
            let addedModel = try repository.addModel(sampleModel, at: filePath)
            logger.info("Successfully added model: \(addedModel.name)")
            logger.info("Model stored at: \(addedModel.localPath?.path ?? "unknown")")
            
            // Verify the model was added
            let retrievedModel = repository.getLocalModel(id: sampleModel.id)
            if let retrieved = retrievedModel {
                logger.info("Model retrieval successful: \(retrieved.name)")
            } else {
                logger.error("Failed to retrieve added model")
            }
            
        } catch {
            logger.error("Failed to add model: \(error.localizedDescription)")
        }
    }
    
    /// Demonstrate model cleanup operations
    func demonstrateCleanupOperations() async {
        logger.info("Demonstrating cleanup operations")
        
        do {
            // Clean up orphaned files
            try repository.cleanupOrphanedFiles()
            logger.info("Cleanup completed successfully")
            
            // Get updated statistics
            let stats = repository.getStorageStatistics()
            logger.info("Post-cleanup statistics - Models: \(stats.modelCount), Total size: \(stats.totalSize) bytes")
            
        } catch {
            logger.error("Cleanup failed: \(error.localizedDescription)")
        }
    }
    
    /// Create a sample model for demonstration purposes
    private func createSampleModel() -> ModelInfo {
        return ModelInfo(
            id: "demo-model-\(UUID().uuidString)",
            name: "Demo Model",
            author: "ManyLLM Demo",
            description: "A sample model for demonstration purposes",
            size: 1024 * 1024, // 1MB
            parameters: "Demo",
            compatibility: .fullyCompatible,
            version: "1.0.0",
            license: "MIT",
            tags: ["demo", "sample", "test"],
            createdAt: Date()
        )
    }
    
    /// Get the repository instance for external use
    var modelRepository: ModelRepository {
        return repository
    }
}

// MARK: - Usage Example

extension LocalModelRepositoryDemo {
    
    /// Static method to run a complete demonstration
    static func runDemo() async {
        do {
            let demo = try LocalModelRepositoryDemo()
            await demo.demonstrateBasicOperations()
            await demo.demonstrateCleanupOperations()
        } catch {
            print("Demo failed to initialize: \(error.localizedDescription)")
        }
    }
}