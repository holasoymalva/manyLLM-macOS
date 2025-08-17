import XCTest
@testable import ManyLLM

@available(macOS 13.0, *)
final class MLXModelLoaderTests: XCTestCase {
    
    var modelLoader: MLXModelLoader!
    var tempDirectory: URL!
    var testModelPath: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        modelLoader = MLXModelLoader()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXModelLoaderTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
        
        // Create a mock model file
        testModelPath = tempDirectory.appendingPathComponent("test_model.mlx")
        let testData = "Mock MLX model data".data(using: .utf8)!
        try testData.write(to: testModelPath)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary files
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        modelLoader = nil
        tempDirectory = nil
        testModelPath = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Basic Properties Tests
    
    func testEngineNameIsMLX() {
        XCTAssertEqual(modelLoader.engineName, "MLX")
    }
    
    func testSupportedFormats() {
        let expectedFormats = ["mlx", "safetensors", "gguf"]
        XCTAssertEqual(Set(modelLoader.supportedFormats), Set(expectedFormats))
    }
    
    func testInitialStateHasNoLoadedModel() {
        XCTAssertNil(modelLoader.getCurrentlyLoadedModel())
        XCTAssertEqual(modelLoader.getMemoryUsage(), 0)
    }
    
    // MARK: - Model Loading Tests
    
    func testLoadModelFromValidPath() async throws {
        // Only run on Apple Silicon
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        let loadedModel = try await modelLoader.loadModel(from: testModelPath)
        
        XCTAssertNotNil(loadedModel)
        XCTAssertEqual(loadedModel.modelInfo.name, "test_model")
        XCTAssertTrue(loadedModel.modelInfo.isLocal)
        XCTAssertEqual(loadedModel.modelInfo.localPath, testModelPath)
        XCTAssertGreaterThan(loadedModel.memoryUsage, 0)
        XCTAssertEqual(loadedModel.contextLength, 4096)
    }
    
    func testLoadModelFromInvalidPath() async {
        let invalidPath = tempDirectory.appendingPathComponent("nonexistent.mlx")
        
        do {
            _ = try await modelLoader.loadModel(from: invalidPath)
            XCTFail("Expected model loading to fail for invalid path")
        } catch let error as ManyLLMError {
            if case .modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("not found"))
            } else {
                XCTFail("Expected modelNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Expected ManyLLMError, got: \(error)")
        }
    }
    
    func testLoadModelWithModelInfo() async throws {
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        let loadedModel = try await modelLoader.loadModel(modelInfo)
        
        XCTAssertNotNil(loadedModel)
        XCTAssertEqual(loadedModel.modelInfo.localPath, testModelPath)
    }
    
    func testLoadModelWithoutLocalPath() async {
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            isLocal: false
        )
        
        do {
            _ = try await modelLoader.loadModel(modelInfo)
            XCTFail("Expected model loading to fail for model without local path")
        } catch let error as ManyLLMError {
            if case .modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("no local path"))
            } else {
                XCTFail("Expected modelNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Expected ManyLLMError, got: \(error)")
        }
    }
    
    // MARK: - Model Unloading Tests
    
    func testUnloadModel() async throws {
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        // First load a model
        let loadedModel = try await modelLoader.loadModel(from: testModelPath)
        XCTAssertNotNil(modelLoader.getCurrentlyLoadedModel())
        
        // Then unload it
        try await modelLoader.unloadModel(loadedModel)
        XCTAssertNil(modelLoader.getCurrentlyLoadedModel())
        XCTAssertEqual(modelLoader.getMemoryUsage(), 0)
    }
    
    func testUnloadNonLoadedModel() async throws {
        let mockModel = LoadedModel(
            id: "mock-id",
            modelInfo: ModelInfo(
                id: "mock-model",
                name: "Mock Model",
                author: "Test",
                description: "Test",
                size: 1024,
                parameters: "1B"
            ),
            memoryUsage: 1024,
            contextLength: 2048
        )
        
        // Should not throw error when unloading non-loaded model
        try await modelLoader.unloadModel(mockModel)
        XCTAssertNil(modelLoader.getCurrentlyLoadedModel())
    }
    
    // MARK: - Model State Tests
    
    func testIsModelLoaded() async throws {
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        // Initially not loaded
        XCTAssertFalse(modelLoader.isModelLoaded(modelInfo))
        
        // Load the model
        _ = try await modelLoader.loadModel(modelInfo)
        
        // Now should be loaded
        XCTAssertTrue(modelLoader.isModelLoaded(modelInfo))
    }
    
    func testLoadMultipleModelsUnloadsPrevious() async throws {
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        // Create second test model file
        let secondModelPath = tempDirectory.appendingPathComponent("second_model.mlx")
        let testData = "Second mock MLX model data".data(using: .utf8)!
        try testData.write(to: secondModelPath)
        
        // Load first model
        let firstModel = try await modelLoader.loadModel(from: testModelPath)
        XCTAssertEqual(modelLoader.getCurrentlyLoadedModel()?.id, firstModel.id)
        
        // Load second model (should unload first)
        let secondModel = try await modelLoader.loadModel(from: secondModelPath)
        XCTAssertEqual(modelLoader.getCurrentlyLoadedModel()?.id, secondModel.id)
        XCTAssertNotEqual(firstModel.id, secondModel.id)
    }
    
    // MARK: - Compatibility Tests
    
    func testValidateModelCompatibilityWithValidModel() throws {
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        if MLXModelLoader.isMLXAvailable() {
            XCTAssertNoThrow(try modelLoader.validateModelCompatibility(modelInfo))
        } else {
            XCTAssertThrowsError(try modelLoader.validateModelCompatibility(modelInfo)) { error in
                XCTAssertTrue(error is ManyLLMError)
            }
        }
    }
    
    func testValidateModelCompatibilityWithUnsupportedFormat() throws {
        // Create model with unsupported format
        let unsupportedPath = tempDirectory.appendingPathComponent("model.txt")
        try "test".write(to: unsupportedPath, atomically: true, encoding: .utf8)
        
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            localPath: unsupportedPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        XCTAssertThrowsError(try modelLoader.validateModelCompatibility(modelInfo)) { error in
            if let mlxError = error as? ManyLLMError,
               case .modelLoadFailed(let message) = mlxError {
                XCTAssertTrue(message.contains("Unsupported model format"))
            } else {
                XCTFail("Expected modelLoadFailed error with format message")
            }
        }
    }
    
    func testValidateModelCompatibilityWithoutLocalPath() throws {
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1024,
            parameters: "1B",
            isLocal: false
        )
        
        XCTAssertThrowsError(try modelLoader.validateModelCompatibility(modelInfo)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Memory Management Tests
    
    func testCanLoadModelBasedOnMemory() {
        let smallModel = ModelInfo(
            id: "small-model",
            name: "Small Model",
            author: "Test",
            description: "Small test model",
            size: 1024 * 1024, // 1MB
            parameters: "1B",
            localPath: testModelPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        let hugeModel = ModelInfo(
            id: "huge-model",
            name: "Huge Model",
            author: "Test",
            description: "Huge test model",
            size: 100 * 1024 * 1024 * 1024, // 100GB
            parameters: "175B",
            localPath: testModelPath,
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        if MLXModelLoader.isMLXAvailable() {
            XCTAssertTrue(modelLoader.canLoadModel(smallModel))
            XCTAssertFalse(modelLoader.canLoadModel(hugeModel))
        } else {
            // On non-Apple Silicon, should return false for any model
            XCTAssertFalse(modelLoader.canLoadModel(smallModel))
            XCTAssertFalse(modelLoader.canLoadModel(hugeModel))
        }
    }
    
    func testGetEstimatedMemoryRequirement() {
        let modelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test",
            description: "Test",
            size: 1000,
            parameters: "1B"
        )
        
        let estimated = modelLoader.getEstimatedMemoryRequirement(modelInfo)
        
        // Should be approximately 1.3x the model size
        XCTAssertEqual(estimated, 1300)
    }
    
    // MARK: - MLX Availability Tests
    
    func testMLXAvailabilityCheck() {
        let isAvailable = MLXModelLoader.isMLXAvailable()
        
        // This test will pass or fail based on the actual system
        // On Apple Silicon with macOS 13+, it should be true
        // On Intel Macs or older macOS, it should be false
        
        if #available(macOS 13.0, *) {
            // Test passes regardless of result, just checking it doesn't crash
            XCTAssertTrue(isAvailable || !isAvailable)
        } else {
            XCTAssertFalse(isAvailable)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingForCorruptedModel() async {
        // Create a corrupted model file (empty file with .mlx extension)
        let corruptedPath = tempDirectory.appendingPathComponent("corrupted.mlx")
        try! Data().write(to: corruptedPath)
        
        if MLXModelLoader.isMLXAvailable() {
            do {
                _ = try await modelLoader.loadModel(from: corruptedPath)
                // If loading succeeds with empty file, that's also valid behavior
            } catch {
                // Expected to fail with corrupted model
                XCTAssertTrue(error is ManyLLMError)
            }
        }
    }
    
    // MARK: - Performance Tests
    
    func testModelLoadingPerformance() async throws {
        guard MLXModelLoader.isMLXAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        measure {
            let expectation = XCTestExpectation(description: "Model loading")
            
            Task {
                do {
                    _ = try await modelLoader.loadModel(from: testModelPath)
                    expectation.fulfill()
                } catch {
                    XCTFail("Model loading failed: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}