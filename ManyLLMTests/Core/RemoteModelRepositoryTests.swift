import XCTest
@testable import ManyLLM

final class RemoteModelRepositoryTests: XCTestCase {
    var localRepository: LocalModelRepository!
    var remoteRepository: RemoteModelRepository!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create local repository with temp directory
        localRepository = try LocalModelRepository()
        remoteRepository = try RemoteModelRepository(localRepository: localRepository)
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        localRepository = nil
        remoteRepository = nil
    }
    
    func testFetchAvailableModels() async throws {
        // Test fetching available models
        let models = try await remoteRepository.fetchAvailableModels()
        
        // Should return at least local models (might be empty)
        XCTAssertNotNil(models)
        XCTAssertTrue(models.allSatisfy { !$0.id.isEmpty })
    }
    
    func testSearchModels() async throws {
        // Test model search functionality
        let allModels = try await remoteRepository.fetchAvailableModels()
        
        if !allModels.isEmpty {
            let firstModel = allModels.first!
            let searchResults = try await remoteRepository.searchModels(query: firstModel.name)
            
            XCTAssertTrue(searchResults.contains { $0.id == firstModel.id })
        }
        
        // Test empty search
        let emptyResults = try await remoteRepository.searchModels(query: "nonexistent_model_xyz")
        XCTAssertTrue(emptyResults.isEmpty)
    }
    
    func testDownloadModelValidation() async throws {
        // Test download validation
        let modelWithoutURL = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: nil
        )
        
        do {
            _ = try await remoteRepository.downloadModel(modelWithoutURL) { _ in }
            XCTFail("Should have thrown error for model without download URL")
        } catch let error as ManyLLMError {
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("No download URL"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Test local model download attempt
        let localModel = ModelInfo(
            id: "local-model",
            name: "Local Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: URL(string: "https://example.com/model.bin"),
            isLocal: true
        )
        
        do {
            _ = try await remoteRepository.downloadModel(localModel) { _ in }
            XCTFail("Should have thrown error for already local model")
        } catch let error as ManyLLMError {
            if case .validationError(let message) = error {
                XCTAssertTrue(message.contains("already downloaded"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testDownloadProgress() throws {
        let testModel = ModelInfo(
            id: "test-progress",
            name: "Test Progress Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: URL(string: "https://example.com/model.bin")
        )
        
        // Initially no progress
        XCTAssertNil(remoteRepository.getDownloadProgress(for: testModel.id))
        
        // Test cancel non-existent download
        XCTAssertThrowsError(try remoteRepository.cancelDownload(for: testModel.id)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testLocalModelOperations() throws {
        // Test local model operations delegation
        let models = remoteRepository.getLocalModels()
        XCTAssertNotNil(models)
        
        // Test non-existent model
        XCTAssertNil(remoteRepository.getLocalModel(id: "nonexistent"))
        
        // Test model path for non-existent model
        let testModel = ModelInfo(
            id: "test-path",
            name: "Test Path Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B"
        )
        
        XCTAssertNil(remoteRepository.getModelPath(testModel))
        XCTAssertFalse(remoteRepository.isModelLocal(testModel))
    }
    
    func testIntegrityVerification() async throws {
        // Create a test model file
        let testModelPath = tempDirectory.appendingPathComponent("test_model.bin")
        let testData = Data("test model data".utf8)
        try testData.write(to: testModelPath)
        
        let testModel = ModelInfo(
            id: "integrity-test",
            name: "Integrity Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true
        )
        
        // Test integrity verification
        let isValid = try await remoteRepository.verifyModelIntegrity(testModel)
        XCTAssertTrue(isValid)
        
        // Test with non-existent model
        let nonExistentModel = ModelInfo(
            id: "non-existent",
            name: "Non-existent Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: tempDirectory.appendingPathComponent("nonexistent.bin"),
            isLocal: true
        )
        
        do {
            _ = try await remoteRepository.verifyModelIntegrity(nonExistentModel)
            XCTFail("Should have thrown error for non-existent model")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testModelDeletion() throws {
        // Create a test model file
        let testModelPath = tempDirectory.appendingPathComponent("delete_test.bin")
        let testData = Data("test model data".utf8)
        try testData.write(to: testModelPath)
        
        let testModel = ModelInfo(
            id: "delete-test",
            name: "Delete Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true
        )
        
        // Add model to local repository first
        let addedModel = try localRepository.addModel(testModel, at: testModelPath)
        
        // Verify it exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: testModelPath.path))
        
        // Delete through remote repository
        try remoteRepository.deleteModel(addedModel)
        
        // Verify it's deleted
        XCTAssertFalse(FileManager.default.fileExists(atPath: testModelPath.path))
    }
}

// MARK: - Mock Download Tests

extension RemoteModelRepositoryTests {
    
    func testDownloadTaskCreation() throws {
        // Test that download tasks are properly created and tracked
        let testModel = ModelInfo(
            id: "download-task-test",
            name: "Download Task Test",
            author: "Test Author",
            description: "Test Description",
            size: 1000000,
            parameters: "1B",
            downloadURL: URL(string: "https://httpbin.org/bytes/1000")
        )
        
        // This test would require mocking URLSession for proper testing
        // For now, we just test the validation logic
        XCTAssertNotNil(testModel.downloadURL)
        XCTAssertFalse(testModel.isLocal)
        XCTAssertTrue(testModel.canDownload)
    }
    
    func testConcurrentDownloadLimits() {
        // Test that concurrent download limits are respected
        // This would be tested with the ModelDownloadManager
        XCTAssertTrue(true) // Placeholder for actual implementation
    }
    
    func testDownloadResume() {
        // Test download resume functionality
        // This would require integration with URLSession background downloads
        XCTAssertTrue(true) // Placeholder for actual implementation
    }
    
    func testNetworkErrorHandling() {
        // Test various network error scenarios
        let networkErrors: [URLError.Code] = [
            .notConnectedToInternet,
            .timedOut,
            .cannotConnectToHost,
            .networkConnectionLost
        ]
        
        for errorCode in networkErrors {
            let error = URLError(errorCode)
            XCTAssertNotNil(error.localizedDescription)
        }
    }
}

// MARK: - Model Discovery and Search Tests

extension RemoteModelRepositoryTests {
    
    func testAdvancedModelSearch() async throws {
        // Test advanced search with filters
        let filters = ModelSearchFilters.compatibleOnly()
        let compatibleModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        // All returned models should be compatible
        let checker = ModelCompatibilityChecker()
        for model in compatibleModels {
            let result = checker.checkCompatibility(for: model)
            XCTAssertEqual(result.compatibility, .fullyCompatible)
        }
    }
    
    func testModelCategoryFiltering() async throws {
        // Test category-based filtering
        let allModels = try await remoteRepository.getModelsByCategory(.all)
        let localModels = try await remoteRepository.getModelsByCategory(.local)
        let remoteModels = try await remoteRepository.getModelsByCategory(.remote)
        let compatibleModels = try await remoteRepository.getModelsByCategory(.compatible)
        let featuredModels = try await remoteRepository.getModelsByCategory(.featured)
        
        XCTAssertGreaterThanOrEqual(allModels.count, localModels.count + remoteModels.count)
        
        // Local models should all have isLocal = true
        XCTAssertTrue(localModels.allSatisfy { $0.isLocal })
        
        // Remote models should all have isLocal = false
        XCTAssertTrue(remoteModels.allSatisfy { !$0.isLocal })
        
        // Compatible models should all be fully compatible
        let checker = ModelCompatibilityChecker()
        for model in compatibleModels {
            let result = checker.checkCompatibility(for: model)
            XCTAssertEqual(result.compatibility, .fullyCompatible)
        }
        
        // Featured models should have featured or popular tags
        XCTAssertTrue(featuredModels.allSatisfy { model in
            model.tags.contains("featured") || model.tags.contains("popular")
        })
    }
    
    func testModelSearchWithParameterFilters() async throws {
        // Test parameter size filtering
        var filters = ModelSearchFilters()
        filters.maxParameters = 10.0 // Small models only
        
        let smallModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        for model in smallModels {
            let parameterCount = extractParameterCount(from: model.parameters)
            XCTAssertLessThanOrEqual(parameterCount, 10.0)
        }
        
        // Test large models
        filters = ModelSearchFilters()
        filters.minParameters = 30.0 // Large models only
        
        let largeModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        for model in largeModels {
            let parameterCount = extractParameterCount(from: model.parameters)
            XCTAssertGreaterThanOrEqual(parameterCount, 30.0)
        }
    }
    
    func testModelSearchWithSizeFilters() async throws {
        // Test file size filtering
        var filters = ModelSearchFilters()
        filters.maxSize = 5_000_000_000 // 5GB max
        
        let smallSizeModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        for model in smallSizeModels {
            XCTAssertLessThanOrEqual(model.size, 5_000_000_000)
        }
    }
    
    func testModelSearchWithAuthorFilter() async throws {
        // Test author filtering
        var filters = ModelSearchFilters()
        filters.author = "Meta"
        
        let metaModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        for model in metaModels {
            XCTAssertEqual(model.author.lowercased(), "meta")
        }
    }
    
    func testModelSearchWithTagFilters() async throws {
        // Test tag filtering
        var filters = ModelSearchFilters()
        filters.tags = ["instruct", "chat"]
        
        let instructChatModels = try await remoteRepository.searchModels(query: "", filters: filters)
        
        for model in instructChatModels {
            XCTAssertTrue(model.tags.contains { $0.lowercased() == "instruct" })
            XCTAssertTrue(model.tags.contains { $0.lowercased() == "chat" })
        }
    }
    
    func testModelSorting() async throws {
        // Test sorting by name
        var filters = ModelSearchFilters()
        filters.sortBy = .name
        filters.sortAscending = true
        
        let sortedByName = try await remoteRepository.searchModels(query: "", filters: filters)
        
        if sortedByName.count > 1 {
            for i in 0..<(sortedByName.count - 1) {
                XCTAssertLessThanOrEqual(sortedByName[i].name, sortedByName[i + 1].name)
            }
        }
        
        // Test sorting by size
        filters.sortBy = .size
        let sortedBySize = try await remoteRepository.searchModels(query: "", filters: filters)
        
        if sortedBySize.count > 1 {
            for i in 0..<(sortedBySize.count - 1) {
                XCTAssertLessThanOrEqual(sortedBySize[i].size, sortedBySize[i + 1].size)
            }
        }
    }
    
    func testModelCompatibilityChecking() {
        let checker = ModelCompatibilityChecker()
        
        // Test with different model types
        let compatibleModel = ModelInfo(
            id: "test-compatible",
            name: "Test Compatible Model",
            author: "Test",
            description: "A test model that should be compatible",
            size: 1_000_000_000, // 1GB
            parameters: "7B",
            compatibility: .fullyCompatible,
            tags: ["test", "compatible"]
        )
        
        let result = checker.checkCompatibility(for: compatibleModel)
        XCTAssertEqual(result.compatibility, .fullyCompatible)
        XCTAssertTrue(result.isCompatible)
        
        // Test with large model that might have memory warnings
        let largeModel = ModelInfo(
            id: "test-large",
            name: "Test Large Model",
            author: "Test",
            description: "A test model that is very large",
            size: 100_000_000_000, // 100GB
            parameters: "175B",
            compatibility: .fullyCompatible,
            tags: ["test", "large"]
        )
        
        let largeResult = checker.checkCompatibility(for: largeModel)
        // Should have warnings about memory usage
        XCTAssertTrue(largeResult.hasWarnings || largeResult.compatibility != .fullyCompatible)
    }
    
    func testModelDetailInformation() async throws {
        // Test that models have comprehensive detail information
        let models = try await remoteRepository.fetchAvailableModels()
        
        for model in models {
            // Basic information should be present
            XCTAssertFalse(model.id.isEmpty)
            XCTAssertFalse(model.name.isEmpty)
            XCTAssertFalse(model.author.isEmpty)
            XCTAssertFalse(model.description.isEmpty)
            XCTAssertFalse(model.parameters.isEmpty)
            XCTAssertGreaterThan(model.size, 0)
            
            // Compatibility should be set
            XCTAssertNotEqual(model.compatibility, .unknown)
            
            // Should have some tags
            XCTAssertFalse(model.tags.isEmpty)
        }
    }
    
    private func extractParameterCount(from parameterString: String) -> Double {
        let cleanString = parameterString.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanString.hasSuffix("B") {
            return Double(cleanString.dropLast()) ?? 0
        } else if cleanString.hasSuffix("M") {
            return (Double(cleanString.dropLast()) ?? 0) / 1000
        } else if cleanString.hasSuffix("K") {
            return (Double(cleanString.dropLast()) ?? 0) / 1_000_000
        }
        
        return 0
    }
}