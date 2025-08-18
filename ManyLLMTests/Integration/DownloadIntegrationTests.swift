import XCTest
@testable import ManyLLM

/// Integration tests for the complete download infrastructure
final class DownloadIntegrationTests: XCTestCase {
    var localRepository: LocalModelRepository!
    var remoteRepository: RemoteModelRepository!
    var downloadManager: ModelDownloadManager!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create temporary directory for testing
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMIntegrationTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Create the complete download infrastructure
        localRepository = try LocalModelRepository()
        remoteRepository = try RemoteModelRepository(localRepository: localRepository)
        downloadManager = ModelDownloadManager(
            remoteRepository: remoteRepository,
            localRepository: localRepository
        )
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        downloadManager = nil
        remoteRepository = nil
        localRepository = nil
    }
    
    @MainActor
    func testCompleteDownloadInfrastructure() async throws {
        // Test that all components are properly initialized
        XCTAssertNotNil(localRepository)
        XCTAssertNotNil(remoteRepository)
        XCTAssertNotNil(downloadManager)
        
        // Test that repositories can fetch models
        let models = try await remoteRepository.fetchAvailableModels()
        XCTAssertNotNil(models)
        
        // Test download manager state
        XCTAssertTrue(downloadManager.activeDownloads.isEmpty)
        XCTAssertTrue(downloadManager.downloadHistory.isEmpty)
        
        let stats = downloadManager.getDownloadStatistics()
        XCTAssertEqual(stats.totalDownloads, 0)
        XCTAssertEqual(stats.activeDownloads, 0)
    }
    
    @MainActor
    func testDownloadValidationFlow() async throws {
        // Create a test model that would fail validation
        let invalidModel = ModelInfo(
            id: "validation-test",
            name: "Validation Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: nil, // No download URL
            isLocal: false
        )
        
        // Test that download manager properly validates
        do {
            try await downloadManager.downloadModel(invalidModel)
            XCTFail("Should have thrown validation error")
        } catch let error as ManyLLMError {
            if case .networkError(let message) = error {
                XCTAssertTrue(message.contains("No download URL"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // Test local model validation
        let localModel = ModelInfo(
            id: "local-validation-test",
            name: "Local Validation Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            downloadURL: URL(string: "https://example.com/model.bin"),
            isLocal: true
        )
        
        do {
            try await downloadManager.downloadModel(localModel)
            XCTFail("Should have thrown validation error for local model")
        } catch let error as ManyLLMError {
            if case .validationError(let message) = error {
                XCTAssertTrue(message.contains("already downloaded"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testModelIntegrityVerificationFlow() async throws {
        // Create a test model file
        let testData = Data("Test model data for integrity verification".utf8)
        let modelPath = tempDirectory.appendingPathComponent("integrity_test.bin")
        try testData.write(to: modelPath)
        
        let testModel = ModelInfo(
            id: "integrity-flow-test",
            name: "Integrity Flow Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        // Test integrity verification through repository
        let isValid = try await remoteRepository.verifyModelIntegrity(testModel)
        XCTAssertTrue(isValid)
        
        // Test with corrupted model (wrong size)
        let corruptedModel = ModelInfo(
            id: "corrupted-test",
            name: "Corrupted Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 999999, // Wrong size
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        let isCorruptedValid = try await remoteRepository.verifyModelIntegrity(corruptedModel)
        XCTAssertFalse(isCorruptedValid)
    }
    
    @MainActor
    func testDownloadProgressTracking() async throws {
        // Test progress tracking without actual download
        let testModel = ModelInfo(
            id: "progress-tracking-test",
            name: "Progress Tracking Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 5000000,
            parameters: "1B",
            downloadURL: URL(string: "https://httpbin.org/delay/1")
        )
        
        // Initially no progress
        XCTAssertNil(downloadManager.getDownloadProgress(for: testModel.id))
        XCTAssertNil(remoteRepository.getDownloadProgress(for: testModel.id))
        
        // Test cancellation of non-existent download
        XCTAssertThrowsError(try downloadManager.cancelDownload(modelId: testModel.id))
        XCTAssertThrowsError(try remoteRepository.cancelDownload(for: testModel.id))
    }
    
    func testErrorHandlingFlow() async throws {
        // Test various error scenarios
        
        // 1. Model not found error
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
            XCTFail("Should have thrown model not found error")
        } catch let error as ManyLLMError {
            if case .modelNotFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
        
        // 2. Storage error
        let invalidPathModel = ModelInfo(
            id: "invalid-path",
            name: "Invalid Path Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: nil,
            isLocal: true
        )
        
        do {
            _ = try await remoteRepository.verifyModelIntegrity(invalidPathModel)
            XCTFail("Should have thrown model not found error")
        } catch let error as ManyLLMError {
            if case .modelNotFound = error {
                // Expected error
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testRepositoryIntegration() async throws {
        // Test that remote repository properly delegates to local repository
        let localModels = remoteRepository.getLocalModels()
        let directLocalModels = localRepository.getLocalModels()
        
        XCTAssertEqual(localModels.count, directLocalModels.count)
        
        // Test model search
        let searchResults = try await remoteRepository.searchModels(query: "test")
        XCTAssertNotNil(searchResults)
        
        // Test non-existent model lookup
        XCTAssertNil(remoteRepository.getLocalModel(id: "nonexistent"))
        XCTAssertNil(localRepository.getLocalModel(id: "nonexistent"))
    }
    
    func testFileFormatValidation() async throws {
        // Test different file format validations
        let formats = [
            ("gguf", Data([0x47, 0x47, 0x55, 0x46] + Array(repeating: 0x01, count: 100))),
            ("ggml", Data([0x67, 0x67, 0x6D, 0x6C] + Array(repeating: 0x01, count: 100))),
            ("bin", Data(Array(repeating: 0x01, count: 100))),
            ("safetensors", Data(Array(repeating: 0x01, count: 100)))
        ]
        
        for (extension, data) in formats {
            let filePath = tempDirectory.appendingPathComponent("test_model.\(extension)")
            try data.write(to: filePath)
            
            let model = ModelInfo(
                id: "format-test-\(extension)",
                name: "Format Test Model (\(extension))",
                author: "Test Author",
                description: "Test Description",
                size: Int64(data.count),
                parameters: "1B",
                localPath: filePath,
                isLocal: true
            )
            
            // Should not throw for valid formats
            let isValid = try await remoteRepository.verifyModelIntegrity(model)
            XCTAssertTrue(isValid, "Format \(extension) should be valid")
        }
    }
}

// MARK: - Performance Tests

extension DownloadIntegrationTests {
    
    func testIntegrityVerificationPerformance() throws {
        // Create a larger test file for performance testing
        let largeData = Data(repeating: 0x42, count: 1024 * 1024) // 1MB
        let largePath = tempDirectory.appendingPathComponent("large_model.bin")
        try largeData.write(to: largePath)
        
        let largeModel = ModelInfo(
            id: "performance-test",
            name: "Performance Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(largeData.count),
            parameters: "1B",
            localPath: largePath,
            isLocal: true
        )
        
        // Measure verification performance
        measure {
            let expectation = XCTestExpectation(description: "Integrity verification")
            
            Task {
                do {
                    _ = try await remoteRepository.verifyModelIntegrity(largeModel)
                    expectation.fulfill()
                } catch {
                    XCTFail("Verification failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    @MainActor
    func testDownloadManagerPerformance() throws {
        // Test download manager operations performance
        let models = (1...100).map { index in
            ModelInfo(
                id: "perf-test-\(index)",
                name: "Performance Test Model \(index)",
                author: "Test Author",
                description: "Test Description",
                size: 1000000,
                parameters: "1B",
                downloadURL: URL(string: "https://example.com/model\(index).bin")
            )
        }
        
        measure {
            // Test statistics calculation performance
            let stats = downloadManager.getDownloadStatistics()
            XCTAssertNotNil(stats)
            
            // Test active downloads retrieval
            let activeDownloads = downloadManager.getActiveDownloads()
            XCTAssertNotNil(activeDownloads)
        }
    }
}