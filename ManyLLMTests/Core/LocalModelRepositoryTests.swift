import XCTest
import Foundation
@testable import ManyLLM

final class LocalModelRepositoryTests: XCTestCase {
    
    var repository: LocalModelRepository!
    var tempDirectory: URL!
    var testModelFile: URL!
    
    override func setUp() {
        super.setUp()
        
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMTests")
            .appendingPathComponent(UUID().uuidString)
        
        try! FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create a test model file
        testModelFile = tempDirectory.appendingPathComponent("test_model.bin")
        let testData = "This is a test model file".data(using: .utf8)!
        try! testData.write(to: testModelFile)
        
        // Initialize repository with custom directory
        repository = try! TestableLocalModelRepository(modelsDirectory: tempDirectory.appendingPathComponent("Models"))
    }
    
    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        repository = nil
        tempDirectory = nil
        testModelFile = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testRepositoryInitialization() {
        XCTAssertNotNil(repository)
        
        // Verify models directory was created
        let modelsDir = tempDirectory.appendingPathComponent("Models")
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelsDir.path))
    }
    
    // MARK: - Model Addition Tests
    
    func testAddModel() throws {
        let model = createTestModel()
        
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        XCTAssertTrue(addedModel.isLocal)
        XCTAssertNotNil(addedModel.localPath)
        XCTAssertNotNil(addedModel.updatedAt)
        
        // Verify model file was copied
        if let localPath = addedModel.localPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: localPath.path))
        }
        
        // Verify model is in cache
        let retrievedModel = repository.getLocalModel(id: model.id)
        XCTAssertNotNil(retrievedModel)
        XCTAssertEqual(retrievedModel?.id, model.id)
    }
    
    func testAddModelWithNonexistentFile() {
        let model = createTestModel()
        let nonexistentFile = tempDirectory.appendingPathComponent("nonexistent.bin")
        
        XCTAssertThrowsError(try repository.addModel(model, at: nonexistentFile)) { error in
            if case ManyLLMError.modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            } else {
                XCTFail("Expected modelNotFound error, got \(error)")
            }
        }
    }
    
    // MARK: - Model Retrieval Tests
    
    func testGetLocalModels() throws {
        let model1 = createTestModel(id: "model1", name: "Model 1")
        let model2 = createTestModel(id: "model2", name: "Model 2")
        
        _ = try repository.addModel(model1, at: testModelFile)
        _ = try repository.addModel(model2, at: testModelFile)
        
        let localModels = repository.getLocalModels()
        
        XCTAssertEqual(localModels.count, 2)
        XCTAssertTrue(localModels.contains { $0.id == "model1" })
        XCTAssertTrue(localModels.contains { $0.id == "model2" })
        
        // Verify models are sorted by name
        XCTAssertEqual(localModels[0].name, "Model 1")
        XCTAssertEqual(localModels[1].name, "Model 2")
    }
    
    func testGetLocalModelById() throws {
        let model = createTestModel()
        _ = try repository.addModel(model, at: testModelFile)
        
        let retrievedModel = repository.getLocalModel(id: model.id)
        XCTAssertNotNil(retrievedModel)
        XCTAssertEqual(retrievedModel?.id, model.id)
        XCTAssertEqual(retrievedModel?.name, model.name)
        
        let nonexistentModel = repository.getLocalModel(id: "nonexistent")
        XCTAssertNil(nonexistentModel)
    }
    
    // MARK: - Model Search Tests
    
    func testSearchModels() async throws {
        let model1 = createTestModel(id: "model1", name: "Llama 3", author: "Meta")
        let model2 = createTestModel(id: "model2", name: "GPT-4", author: "OpenAI")
        let model3 = createTestModel(id: "model3", name: "Claude", author: "Anthropic", tags: ["assistant", "helpful"])
        
        _ = try repository.addModel(model1, at: testModelFile)
        _ = try repository.addModel(model2, at: testModelFile)
        _ = try repository.addModel(model3, at: testModelFile)
        
        // Search by name
        let llamaResults = try await repository.searchModels(query: "llama")
        XCTAssertEqual(llamaResults.count, 1)
        XCTAssertEqual(llamaResults[0].id, "model1")
        
        // Search by author
        let metaResults = try await repository.searchModels(query: "meta")
        XCTAssertEqual(metaResults.count, 1)
        XCTAssertEqual(metaResults[0].id, "model1")
        
        // Search by tag
        let assistantResults = try await repository.searchModels(query: "assistant")
        XCTAssertEqual(assistantResults.count, 1)
        XCTAssertEqual(assistantResults[0].id, "model3")
        
        // Search with no results
        let noResults = try await repository.searchModels(query: "nonexistent")
        XCTAssertEqual(noResults.count, 0)
    }
    
    // MARK: - Model Deletion Tests
    
    func testDeleteModel() throws {
        let model = createTestModel()
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        // Verify model exists
        XCTAssertNotNil(repository.getLocalModel(id: model.id))
        if let localPath = addedModel.localPath {
            XCTAssertTrue(FileManager.default.fileExists(atPath: localPath.path))
        }
        
        // Delete model
        try repository.deleteModel(addedModel)
        
        // Verify model is removed
        XCTAssertNil(repository.getLocalModel(id: model.id))
        if let localPath = addedModel.localPath {
            XCTAssertFalse(FileManager.default.fileExists(atPath: localPath.path))
        }
    }
    
    func testDeleteNonLocalModel() {
        let model = createTestModel(isLocal: false)
        
        XCTAssertThrowsError(try repository.deleteModel(model)) { error in
            if case ManyLLMError.modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("not stored locally"))
            } else {
                XCTFail("Expected modelNotFound error, got \(error)")
            }
        }
    }
    
    // MARK: - Model Verification Tests
    
    func testVerifyModelIntegrity() async throws {
        let model = createTestModel()
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        let isValid = try await repository.verifyModelIntegrity(addedModel)
        XCTAssertTrue(isValid)
    }
    
    func testVerifyModelIntegrityWithMissingFile() async throws {
        var model = createTestModel(isLocal: true)
        model.localPath = tempDirectory.appendingPathComponent("missing.bin")
        
        do {
            _ = try await repository.verifyModelIntegrity(model)
            XCTFail("Expected error for missing file")
        } catch ManyLLMError.modelNotFound(let message) {
            XCTAssertTrue(message.contains("does not exist"))
        }
    }
    
    func testVerifyModelIntegrityWithSizeMismatch() async throws {
        let model = createTestModel(size: 999999) // Different from actual file size
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        let isValid = try await repository.verifyModelIntegrity(addedModel)
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Model Discovery Tests
    
    func testDiscoverLocalModels() throws {
        // Add a model first
        let model = createTestModel()
        _ = try repository.addModel(model, at: testModelFile)
        
        // Clear cache to simulate fresh discovery
        let testableRepo = repository as! TestableLocalModelRepository
        testableRepo.clearCache()
        
        // Discover models
        try repository.discoverLocalModels()
        
        // Verify model was discovered
        let discoveredModels = repository.getLocalModels()
        XCTAssertEqual(discoveredModels.count, 1)
        XCTAssertEqual(discoveredModels[0].id, model.id)
    }
    
    // MARK: - Storage Statistics Tests
    
    func testGetStorageStatistics() throws {
        let model1 = createTestModel(id: "model1", size: 1000)
        let model2 = createTestModel(id: "model2", size: 2000)
        
        _ = try repository.addModel(model1, at: testModelFile)
        _ = try repository.addModel(model2, at: testModelFile)
        
        let stats = repository.getStorageStatistics()
        XCTAssertEqual(stats.modelCount, 2)
        XCTAssertEqual(stats.totalSize, 3000)
    }
    
    // MARK: - Cleanup Tests
    
    func testCleanupOrphanedFiles() throws {
        // Create an orphaned directory (without metadata)
        let orphanedDir = tempDirectory.appendingPathComponent("Models").appendingPathComponent("orphaned")
        try FileManager.default.createDirectory(at: orphanedDir, withIntermediateDirectories: true)
        
        // Create a file in the orphaned directory
        let orphanedFile = orphanedDir.appendingPathComponent("orphaned.bin")
        try "orphaned data".write(to: orphanedFile, atomically: true, encoding: .utf8)
        
        // Verify orphaned directory exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: orphanedDir.path))
        
        // Clean up orphaned files
        try repository.cleanupOrphanedFiles()
        
        // Verify orphaned directory was removed
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanedDir.path))
    }
    
    // MARK: - Model Path Tests
    
    func testIsModelLocal() throws {
        let model = createTestModel()
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        XCTAssertTrue(repository.isModelLocal(addedModel))
        
        let nonLocalModel = createTestModel(id: "nonlocal", isLocal: false)
        XCTAssertFalse(repository.isModelLocal(nonLocalModel))
    }
    
    func testGetModelPath() throws {
        let model = createTestModel()
        let addedModel = try repository.addModel(model, at: testModelFile)
        
        let path = repository.getModelPath(addedModel)
        XCTAssertNotNil(path)
        XCTAssertEqual(path, addedModel.localPath)
        
        let nonLocalModel = createTestModel(id: "nonlocal", isLocal: false)
        let nonLocalPath = repository.getModelPath(nonLocalModel)
        XCTAssertNil(nonLocalPath)
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchAvailableModelsReturnsLocalModels() async throws {
        let model = createTestModel()
        _ = try repository.addModel(model, at: testModelFile)
        
        let availableModels = try await repository.fetchAvailableModels()
        XCTAssertEqual(availableModels.count, 1)
        XCTAssertEqual(availableModels[0].id, model.id)
    }
    
    func testDownloadModelThrowsError() async {
        let model = createTestModel()
        
        do {
            _ = try await repository.downloadModel(model) { _ in }
            XCTFail("Expected error for download operation")
        } catch ManyLLMError.networkError(let message) {
            XCTAssertTrue(message.contains("not implemented"))
        }
    }
    
    func testGetDownloadProgressReturnsNil() {
        let progress = repository.getDownloadProgress(for: "any-model")
        XCTAssertNil(progress)
    }
    
    func testCancelDownloadThrowsError() {
        XCTAssertThrowsError(try repository.cancelDownload(for: "any-model")) { error in
            if case ManyLLMError.networkError(let message) = error {
                XCTAssertTrue(message.contains("not supported"))
            } else {
                XCTFail("Expected networkError, got \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestModel(
        id: String = "test-model",
        name: String = "Test Model",
        author: String = "Test Author",
        description: String = "A test model",
        size: Int64 = 25, // Size of test data
        parameters: String = "7B",
        isLocal: Bool = false,
        tags: [String] = []
    ) -> ModelInfo {
        return ModelInfo(
            id: id,
            name: name,
            author: author,
            description: description,
            size: size,
            parameters: parameters,
            isLocal: isLocal,
            compatibility: .fullyCompatible,
            tags: tags
        )
    }
}

// MARK: - Testable LocalModelRepository

/// Testable version of LocalModelRepository that allows custom directory and cache manipulation
class TestableLocalModelRepository: LocalModelRepository {
    private let customModelsDirectory: URL
    
    init(modelsDirectory: URL) throws {
        self.customModelsDirectory = modelsDirectory
        
        // Create the directory structure
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        
        // Initialize with custom directory by overriding the parent's modelsDirectory
        try super.init()
        
        // Replace the modelsDirectory with our custom one
        setValue(customModelsDirectory, forKey: "modelsDirectory")
        
        // Initialize cache for the custom directory
        try loadModelCache()
    }
    
    func clearCache() {
        setValue([:], forKey: "modelCache")
        setValue(Date.distantPast, forKey: "lastCacheUpdate")
    }
    
    override init() throws {
        // This should not be called in tests
        fatalError("Use init(modelsDirectory:) for testing")
    }
}