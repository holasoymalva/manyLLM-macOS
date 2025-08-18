import XCTest
import Foundation
@testable import ManyLLM

/// Integration tests for LocalModelRepository with real file system operations
final class LocalModelRepositoryIntegrationTests: XCTestCase {
    
    var repository: LocalModelRepository!
    var tempDirectory: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for integration testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Initialize repository
        do {
            repository = try LocalModelRepository()
        } catch {
            XCTFail("Failed to initialize LocalModelRepository: \(error)")
        }
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        repository = nil
        tempDirectory = nil
        super.tearDown()
    }
    
    // MARK: - Integration Tests
    
    func testRepositoryInitializationCreatesDirectories() {
        // The repository should create necessary directories during initialization
        XCTAssertNotNil(repository)
        
        // Test that we can get local models without errors
        let models = repository.getLocalModels()
        XCTAssertNotNil(models)
    }
    
    func testFullModelLifecycle() throws {
        // Create a test model file
        let testModelFile = tempDirectory.appendingPathComponent("test_model.bin")
        let testData = "This is a test model file for integration testing".data(using: .utf8)!
        try testData.write(to: testModelFile)
        
        // Create model info
        let modelInfo = ModelInfo(
            id: "integration-test-model",
            name: "Integration Test Model",
            author: "Test Suite",
            description: "A model for integration testing",
            size: Int64(testData.count),
            parameters: "Test",
            compatibility: .fullyCompatible,
            tags: ["integration", "test"]
        )
        
        // Test adding the model
        let addedModel = try repository.addModel(modelInfo, at: testModelFile)
        XCTAssertTrue(addedModel.isLocal)
        XCTAssertNotNil(addedModel.localPath)
        
        // Test retrieving the model
        let retrievedModel = repository.getLocalModel(id: modelInfo.id)
        XCTAssertNotNil(retrievedModel)
        XCTAssertEqual(retrievedModel?.id, modelInfo.id)
        
        // Test model verification
        let isValid = try await repository.verifyModelIntegrity(addedModel)
        XCTAssertTrue(isValid)
        
        // Test model search
        let searchResults = try await repository.searchModels(query: "integration")
        XCTAssertTrue(searchResults.contains { $0.id == modelInfo.id })
        
        // Test storage statistics
        let stats = repository.getStorageStatistics()
        XCTAssertGreaterThan(stats.modelCount, 0)
        XCTAssertGreaterThan(stats.totalSize, 0)
        
        // Test model deletion
        try repository.deleteModel(addedModel)
        let deletedModel = repository.getLocalModel(id: modelInfo.id)
        XCTAssertNil(deletedModel)
    }
    
    func testModelDiscovery() throws {
        // This test verifies that the repository can discover models
        // even after reinitialization (simulating app restart)
        
        // Create a test model file
        let testModelFile = tempDirectory.appendingPathComponent("discovery_test.bin")
        let testData = "Discovery test model".data(using: .utf8)!
        try testData.write(to: testModelFile)
        
        // Create and add model
        let modelInfo = ModelInfo(
            id: "discovery-test-model",
            name: "Discovery Test Model",
            author: "Test Suite",
            description: "A model for testing discovery",
            size: Int64(testData.count),
            parameters: "Test"
        )
        
        _ = try repository.addModel(modelInfo, at: testModelFile)
        
        // Verify model exists
        XCTAssertNotNil(repository.getLocalModel(id: modelInfo.id))
        
        // Create a new repository instance (simulating app restart)
        let newRepository = try LocalModelRepository()
        
        // The new repository should discover the existing model
        let discoveredModel = newRepository.getLocalModel(id: modelInfo.id)
        XCTAssertNotNil(discoveredModel)
        XCTAssertEqual(discoveredModel?.name, modelInfo.name)
        
        // Clean up
        if let model = discoveredModel {
            try newRepository.deleteModel(model)
        }
    }
    
    func testErrorHandling() {
        // Test adding model with non-existent file
        let nonExistentFile = tempDirectory.appendingPathComponent("nonexistent.bin")
        let modelInfo = ModelInfo(
            id: "error-test-model",
            name: "Error Test Model",
            author: "Test Suite",
            description: "A model for error testing",
            size: 1000,
            parameters: "Test"
        )
        
        XCTAssertThrowsError(try repository.addModel(modelInfo, at: nonExistentFile))
        
        // Test deleting non-local model
        let nonLocalModel = ModelInfo(
            id: "non-local-model",
            name: "Non-Local Model",
            author: "Test Suite",
            description: "A non-local model",
            size: 1000,
            parameters: "Test",
            isLocal: false
        )
        
        XCTAssertThrowsError(try repository.deleteModel(nonLocalModel))
    }
    
    func testCleanupOperations() throws {
        // Test cleanup of orphaned files
        // This is a basic test since creating truly orphaned files
        // requires more complex setup
        
        XCTAssertNoThrow(try repository.cleanupOrphanedFiles())
        
        // Verify repository still works after cleanup
        let models = repository.getLocalModels()
        XCTAssertNotNil(models)
    }
    
    func testConcurrentOperations() async throws {
        // Test that repository handles concurrent operations safely
        let testModelFile = tempDirectory.appendingPathComponent("concurrent_test.bin")
        let testData = "Concurrent test model".data(using: .utf8)!
        try testData.write(to: testModelFile)
        
        // Create multiple model infos
        let modelInfos = (0..<5).map { index in
            ModelInfo(
                id: "concurrent-test-model-\(index)",
                name: "Concurrent Test Model \(index)",
                author: "Test Suite",
                description: "A model for concurrent testing",
                size: Int64(testData.count),
                parameters: "Test"
            )
        }
        
        // Add models concurrently
        await withTaskGroup(of: Void.self) { group in
            for modelInfo in modelInfos {
                group.addTask {
                    do {
                        _ = try self.repository.addModel(modelInfo, at: testModelFile)
                    } catch {
                        XCTFail("Concurrent model addition failed: \(error)")
                    }
                }
            }
        }
        
        // Verify all models were added
        let localModels = repository.getLocalModels()
        let addedModels = localModels.filter { $0.id.hasPrefix("concurrent-test-model") }
        XCTAssertEqual(addedModels.count, modelInfos.count)
        
        // Clean up
        for model in addedModels {
            try repository.deleteModel(model)
        }
    }
    
    func testRepositoryPerformance() throws {
        // Performance test for repository operations
        let testModelFile = tempDirectory.appendingPathComponent("performance_test.bin")
        let testData = "Performance test model".data(using: .utf8)!
        try testData.write(to: testModelFile)
        
        // Measure time to add multiple models
        let startTime = Date()
        
        for i in 0..<10 {
            let modelInfo = ModelInfo(
                id: "performance-test-model-\(i)",
                name: "Performance Test Model \(i)",
                author: "Test Suite",
                description: "A model for performance testing",
                size: Int64(testData.count),
                parameters: "Test"
            )
            
            _ = try repository.addModel(modelInfo, at: testModelFile)
        }
        
        let addTime = Date().timeIntervalSince(startTime)
        
        // Measure time to retrieve all models
        let retrieveStartTime = Date()
        let models = repository.getLocalModels()
        let retrieveTime = Date().timeIntervalSince(retrieveStartTime)
        
        // Basic performance assertions (adjust thresholds as needed)
        XCTAssertLessThan(addTime, 5.0, "Adding 10 models should take less than 5 seconds")
        XCTAssertLessThan(retrieveTime, 1.0, "Retrieving models should take less than 1 second")
        XCTAssertGreaterThanOrEqual(models.count, 10)
        
        // Clean up
        let performanceModels = models.filter { $0.id.hasPrefix("performance-test-model") }
        for model in performanceModels {
            try repository.deleteModel(model)
        }
    }
}