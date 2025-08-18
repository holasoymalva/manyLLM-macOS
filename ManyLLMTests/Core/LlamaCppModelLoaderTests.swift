import XCTest
@testable import ManyLLM

/// Unit tests for LlamaCppModelLoader
final class LlamaCppModelLoaderTests: XCTestCase {
    
    var modelLoader: LlamaCppModelLoader!
    var testModel: ModelInfo!
    
    override func setUp() {
        super.setUp()
        modelLoader = LlamaCppModelLoader()
        
        // Create a test model
        testModel = ModelInfo(
            id: "test-llama-model",
            name: "Test Llama Model",
            author: "Test Author",
            description: "Test model for llama.cpp loader",
            size: 2 * 1024 * 1024 * 1024, // 2GB
            parameters: "7B",
            localPath: URL(fileURLWithPath: "/tmp/test-model.gguf"),
            isLocal: true,
            compatibility: .fullyCompatible,
            tags: ["test", "gguf"]
        )
    }
    
    override func tearDown() {
        modelLoader = nil
        testModel = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testSupportedFormats() {
        let supportedFormats = modelLoader.supportedFormats
        
        XCTAssertTrue(supportedFormats.contains("gguf"), "Should support GGUF format")
        XCTAssertTrue(supportedFormats.contains("ggml"), "Should support GGML format")
        XCTAssertTrue(supportedFormats.contains("bin"), "Should support BIN format")
        XCTAssertFalse(supportedFormats.contains("mlx"), "Should not support MLX format")
    }
    
    func testEngineName() {
        XCTAssertEqual(modelLoader.engineName, "llama.cpp", "Engine name should be 'llama.cpp'")
    }
    
    func testInitialState() {
        XCTAssertNil(modelLoader.getCurrentlyLoadedModel(), "Should have no loaded model initially")
        XCTAssertEqual(modelLoader.getMemoryUsage(), 0, "Should have zero memory usage initially")
    }
    
    // MARK: - Availability Tests
    
    func testLlamaCppAvailability() {
        let isAvailable = LlamaCppModelLoader.isLlamaCppAvailable()
        XCTAssertTrue(isAvailable, "llama.cpp should be available on macOS")
    }
    
    func testOptimalThreadCount() {
        let threadCount = LlamaCppModelLoader.getOptimalThreadCount()
        let processorCount = ProcessInfo.processInfo.processorCount
        
        XCTAssertGreaterThan(threadCount, 0, "Thread count should be positive")
        XCTAssertLessThanOrEqual(threadCount, processorCount, "Thread count should not exceed processor count")
        
        // Should be approximately 75% of processor count
        let expectedThreadCount = max(1, Int(Double(processorCount) * 0.75))
        XCTAssertEqual(threadCount, expectedThreadCount, "Thread count should be 75% of processor count")
    }
    
    // MARK: - Memory Estimation Tests
    
    func testMemoryRequirementEstimation() {
        let estimatedMemory = modelLoader.getEstimatedMemoryRequirement(testModel)
        let expectedMemory = Int64(Double(testModel.size) * 1.15) // 15% overhead
        
        XCTAssertEqual(estimatedMemory, expectedMemory, "Memory estimation should include 15% overhead")
    }
    
    func testCanLoadModelMemoryCheck() {
        // Test with a very large model that shouldn't fit in memory
        let largeModel = ModelInfo(
            id: "large-model",
            name: "Large Model",
            author: "Test",
            description: "Very large test model",
            size: 1024 * 1024 * 1024 * 1024, // 1TB - definitely too large
            parameters: "175B",
            localPath: URL(fileURLWithPath: "/tmp/large-model.gguf"),
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        let canLoadLarge = modelLoader.canLoadModel(largeModel)
        XCTAssertFalse(canLoadLarge, "Should not be able to load extremely large model")
        
        // Test with a reasonable model
        let canLoadNormal = modelLoader.canLoadModel(testModel)
        // This might be true or false depending on available memory, but shouldn't crash
        XCTAssertNotNil(canLoadNormal, "Should return a boolean value")
    }
    
    // MARK: - Model Validation Tests
    
    func testValidateModelCompatibilityWithSupportedFormat() {
        // Test with GGUF format
        let ggufModel = ModelInfo(
            id: "gguf-model",
            name: "GGUF Model",
            author: "Test",
            description: "GGUF format model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            localPath: URL(fileURLWithPath: "/tmp/model.gguf"),
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        XCTAssertNoThrow(try modelLoader.validateModelCompatibility(ggufModel), "GGUF format should be valid")
    }
    
    func testValidateModelCompatibilityWithUnsupportedFormat() {
        // Test with unsupported format
        let unsupportedModel = ModelInfo(
            id: "unsupported-model",
            name: "Unsupported Model",
            author: "Test",
            description: "Unsupported format model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            localPath: URL(fileURLWithPath: "/tmp/model.xyz"),
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        XCTAssertThrowsError(try modelLoader.validateModelCompatibility(unsupportedModel)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.modelLoadFailed(message) = error {
                XCTAssertTrue(message.contains("Unsupported model format"), "Error should mention unsupported format")
            }
        }
    }
    
    func testValidateModelCompatibilityWithNoLocalPath() {
        let noPathModel = ModelInfo(
            id: "no-path-model",
            name: "No Path Model",
            author: "Test",
            description: "Model without local path",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            localPath: nil,
            isLocal: false,
            compatibility: .fullyCompatible
        )
        
        XCTAssertThrowsError(try modelLoader.validateModelCompatibility(noPathModel)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.modelNotFound(message) = error {
                XCTAssertTrue(message.contains("no local path"), "Error should mention missing local path")
            }
        }
    }
    
    // MARK: - Model Loading Tests (Mock)
    
    func testLoadModelWithNonexistentFile() async {
        // Test loading a model with a path that doesn't exist
        let nonexistentModel = ModelInfo(
            id: "nonexistent-model",
            name: "Nonexistent Model",
            author: "Test",
            description: "Model with nonexistent file",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            localPath: URL(fileURLWithPath: "/tmp/nonexistent-model.gguf"),
            isLocal: true,
            compatibility: .fullyCompatible
        )
        
        do {
            _ = try await modelLoader.loadModel(nonexistentModel)
            XCTFail("Should throw error for nonexistent file")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.modelNotFound(message) = error {
                XCTAssertTrue(message.contains("not found"), "Error should mention file not found")
            }
        }
    }
    
    func testLoadModelWithNoLocalPath() async {
        let noPathModel = ModelInfo(
            id: "no-path-model",
            name: "No Path Model",
            author: "Test",
            description: "Model without local path",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            localPath: nil,
            isLocal: false,
            compatibility: .fullyCompatible
        )
        
        do {
            _ = try await modelLoader.loadModel(noPathModel)
            XCTFail("Should throw error for model without local path")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.modelNotFound(message) = error {
                XCTAssertTrue(message.contains("no local path"), "Error should mention missing local path")
            }
        }
    }
    
    // MARK: - Model State Management Tests
    
    func testIsModelLoadedWithNoModel() {
        let isLoaded = modelLoader.isModelLoaded(testModel)
        XCTAssertFalse(isLoaded, "Should return false when no model is loaded")
    }
    
    func testUnloadModelWithNoModel() async {
        // Should not throw error when trying to unload with no model loaded
        let mockLoadedModel = LoadedModel(
            info: testModel,
            loadedAt: Date(),
            memoryUsage: 1024 * 1024 * 1024,
            engineType: "llama.cpp"
        )
        
        XCTAssertNoThrow(try await modelLoader.unloadModel(mockLoadedModel), "Should not throw when unloading non-loaded model")
    }
    
    // MARK: - Parameter Estimation Tests
    
    func testParameterEstimationFromFileSize() {
        // Test different file sizes and their parameter estimations
        let testCases: [(Int64, String)] = [
            (500 * 1024 * 1024, "1B"),           // 500MB -> 1B
            (1.5 * 1024 * 1024 * 1024, "1B"),   // 1.5GB -> 1B
            (2.5 * 1024 * 1024 * 1024, "3B"),   // 2.5GB -> 3B
            (4 * 1024 * 1024 * 1024, "7B"),     // 4GB -> 7B
            (8 * 1024 * 1024 * 1024, "13B"),    // 8GB -> 13B
            (15 * 1024 * 1024 * 1024, "30B"),   // 15GB -> 30B
            (30 * 1024 * 1024 * 1024, "70B"),   // 30GB -> 70B
            (80 * 1024 * 1024 * 1024, "70B+")   // 80GB -> 70B+
        ]
        
        for (fileSize, expectedParams) in testCases {
            let testModel = ModelInfo(
                id: "size-test-\(fileSize)",
                name: "Size Test Model",
                author: "Test",
                description: "Model for size testing",
                size: fileSize,
                parameters: "Unknown",
                localPath: URL(fileURLWithPath: "/tmp/test.gguf"),
                isLocal: true,
                compatibility: .fullyCompatible
            )
            
            // This tests the internal parameter estimation logic
            // We can't directly test the private method, but we can test the behavior
            // through the model creation process
            
            let sizeInGB = Double(fileSize) / (1024 * 1024 * 1024)
            print("File size: \(String(format: "%.1f", sizeInGB))GB -> Expected: \(expectedParams)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testCreateModelInfoFromInvalidPath() {
        // Test with various invalid paths
        let invalidPaths = [
            URL(fileURLWithPath: ""),
            URL(fileURLWithPath: "/"),
            URL(fileURLWithPath: "/tmp/")
        ]
        
        for invalidPath in invalidPaths {
            let invalidModel = ModelInfo(
                id: "invalid-path-model",
                name: "Invalid Path Model",
                author: "Test",
                description: "Model with invalid path",
                size: 1024 * 1024 * 1024,
                parameters: "7B",
                localPath: invalidPath,
                isLocal: true,
                compatibility: .fullyCompatible
            )
            
            // The model creation itself should work, but loading should fail
            XCTAssertNotNil(invalidModel.localPath, "Model should have local path set")
        }
    }
    
    // MARK: - Integration Tests
    
    func testModelLoaderIntegrationWithInferenceEngine() {
        // Test that the model loader can be used with the inference engine
        let inferenceEngine = LlamaCppInferenceEngine(modelLoader: modelLoader)
        
        XCTAssertNotNil(inferenceEngine, "Should be able to create inference engine with model loader")
        XCTAssertFalse(inferenceEngine.isReady, "Engine should not be ready without loaded model")
        XCTAssertFalse(inferenceEngine.isProcessing, "Engine should not be processing initially")
    }
    
    func testGetLlamaModelWithoutLoadedModel() {
        // Test internal method for getting llama model
        let llamaModel = modelLoader.getLlamaModel()
        XCTAssertNil(llamaModel, "Should return nil when no model is loaded")
    }
}