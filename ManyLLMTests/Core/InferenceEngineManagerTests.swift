import XCTest
@testable import ManyLLM

@MainActor
final class InferenceEngineManagerTests: XCTestCase {
    
    var engineManager: InferenceEngineManager!
    var mockModelInfo: ModelInfo!
    
    override func setUp() async throws {
        try await super.setUp()
        
        engineManager = InferenceEngineManager()
        
        // Create a mock model for testing
        mockModelInfo = ModelInfo(
            id: "test-model-integration",
            name: "Test Integration Model",
            author: "Test Author",
            description: "A test model for integration testing",
            size: 2_000_000_000, // 2GB
            parameters: "3B",
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible,
            version: "1.0.0",
            license: "MIT",
            tags: ["test", "integration"]
        )
        
        // Wait for initial engine setup
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    override func tearDown() async throws {
        if let engineManager = engineManager {
            try? await engineManager.unloadModel()
        }
        engineManager = nil
        mockModelInfo = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testEngineManagerInitialization() throws {
        XCTAssertNotNil(engineManager)
        XCTAssertFalse(engineManager.availableEngines.isEmpty)
        XCTAssertFalse(engineManager.isLoading)
    }
    
    func testAvailableEnginesSetup() throws {
        let engines = engineManager.availableEngines
        
        // Should always have mock engine
        XCTAssertTrue(engines.contains { $0.type == .mock })
        
        // Should have MLX engine entry (available or not)
        XCTAssertTrue(engines.contains { $0.type == .mlx })
        
        // Mock engine should always be available
        let mockEngine = engines.first { $0.type == .mock }
        XCTAssertNotNil(mockEngine)
        XCTAssertTrue(mockEngine!.isAvailable)
    }
    
    func testMLXEngineAvailability() throws {
        let engines = engineManager.availableEngines
        let mlxEngine = engines.first { $0.type == .mlx }
        
        XCTAssertNotNil(mlxEngine)
        
        // MLX availability depends on system
        if #available(macOS 13.0, *) {
            // On supported systems, availability depends on Apple Silicon
            XCTAssertNotNil(mlxEngine!.isAvailable)
        } else {
            // On older systems, should not be available
            XCTAssertFalse(mlxEngine!.isAvailable)
        }
    }
    
    // MARK: - Engine Switching Tests
    
    func testSwitchToMockEngine() async throws {
        try await engineManager.switchToEngine(.mock)
        
        XCTAssertNotNil(engineManager.currentEngine)
        XCTAssertTrue(engineManager.currentEngine is MockInferenceEngine)
        XCTAssertFalse(engineManager.isLoading)
    }
    
    func testSwitchToMLXEngine() async throws {
        // Only test if MLX is available
        guard engineManager.isEngineAvailable(.mlx) else {
            throw XCTSkip("MLX engine not available on this system")
        }
        
        try await engineManager.switchToEngine(.mlx)
        
        XCTAssertNotNil(engineManager.currentEngine)
        
        if #available(macOS 13.0, *) {
            XCTAssertTrue(engineManager.currentEngine is MLXInferenceEngine)
        }
        
        XCTAssertFalse(engineManager.isLoading)
    }
    
    func testSwitchToUnavailableEngine() async throws {
        // Try to switch to MLX on unsupported system
        if !engineManager.isEngineAvailable(.mlx) {
            do {
                try await engineManager.switchToEngine(.mlx)
                XCTFail("Should have thrown an error for unavailable engine")
            } catch {
                XCTAssertTrue(error is ManyLLMError)
            }
        }
    }
    
    func testMultipleEngineSwitches() async throws {
        // Switch to mock engine
        try await engineManager.switchToEngine(.mock)
        XCTAssertTrue(engineManager.currentEngine is MockInferenceEngine)
        
        // Switch to MLX if available, otherwise stay with mock
        if engineManager.isEngineAvailable(.mlx) {
            try await engineManager.switchToEngine(.mlx)
            if #available(macOS 13.0, *) {
                XCTAssertTrue(engineManager.currentEngine is MLXInferenceEngine)
            }
        }
        
        // Switch back to mock
        try await engineManager.switchToEngine(.mock)
        XCTAssertTrue(engineManager.currentEngine is MockInferenceEngine)
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadingWithMockEngine() async throws {
        try await engineManager.switchToEngine(.mock)
        
        XCTAssertNil(engineManager.loadedModel)
        
        try await engineManager.loadModel(mockModelInfo)
        
        XCTAssertNotNil(engineManager.loadedModel)
        XCTAssertEqual(engineManager.loadedModel?.modelInfo.id, mockModelInfo.id)
    }
    
    func testModelUnloading() async throws {
        try await engineManager.switchToEngine(.mock)
        try await engineManager.loadModel(mockModelInfo)
        
        XCTAssertNotNil(engineManager.loadedModel)
        
        try await engineManager.unloadModel()
        
        XCTAssertNil(engineManager.loadedModel)
    }
    
    func testModelLoadingWithoutEngine() async throws {
        // Clear current engine (simulate uninitialized state)
        // Note: This is tricky to test since the manager initializes with a default engine
        
        do {
            try await engineManager.loadModel(mockModelInfo)
            // Should succeed if there's a current engine
            XCTAssertNotNil(engineManager.currentEngine)
        } catch {
            // If it fails, should be due to no engine
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Engine Selection Tests
    
    func testBestEngineForModel() throws {
        // Test with a mock MLX-compatible model
        let mlxModel = ModelInfo(
            id: "mlx-model",
            name: "MLX Model",
            author: "Test",
            description: "MLX compatible model",
            size: 1_000_000_000,
            parameters: "1B",
            localPath: URL(fileURLWithPath: "/tmp/model.mlx"),
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible
        )
        
        let bestEngine = engineManager.getBestEngineForModel(mlxModel)
        
        if engineManager.isEngineAvailable(.mlx) {
            XCTAssertEqual(bestEngine, .mlx)
        } else {
            XCTAssertEqual(bestEngine, .mock)
        }
    }
    
    func testBestEngineForUnsupportedModel() throws {
        // Test with a model that's not MLX compatible
        let unsupportedModel = ModelInfo(
            id: "unsupported-model",
            name: "Unsupported Model",
            author: "Test",
            description: "Non-MLX model",
            size: 1_000_000_000,
            parameters: "1B",
            localPath: URL(fileURLWithPath: "/tmp/model.bin"),
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible
        )
        
        let bestEngine = engineManager.getBestEngineForModel(unsupportedModel)
        
        // Should fall back to mock engine for unsupported formats
        XCTAssertEqual(bestEngine, .mock)
    }
    
    // MARK: - Capabilities Tests
    
    func testEngineCapabilities() throws {
        let mockCapabilities = engineManager.getEngineCapabilities(.mock)
        XCTAssertNotNil(mockCapabilities)
        XCTAssertTrue(mockCapabilities!.supportsStreaming)
        
        let mlxCapabilities = engineManager.getEngineCapabilities(.mlx)
        if engineManager.isEngineAvailable(.mlx) {
            XCTAssertNotNil(mlxCapabilities)
            XCTAssertTrue(mlxCapabilities!.supportsStreaming)
        } else {
            XCTAssertNil(mlxCapabilities)
        }
    }
    
    // MARK: - Integration with ChatManager Tests
    
    func testChatManagerIntegration() async throws {
        let chatManager = ChatManager(engineManager: engineManager)
        
        // Test that chat manager uses the engine manager
        XCTAssertNotNil(chatManager.currentInferenceEngine)
        XCTAssertEqual(chatManager.availableEngines.count, engineManager.availableEngines.count)
        
        // Test engine switching through chat manager
        try await chatManager.switchToEngine(.mock)
        XCTAssertTrue(chatManager.currentInferenceEngine is MockInferenceEngine)
        
        // Test model loading through chat manager
        try await chatManager.loadModel(mockModelInfo)
        XCTAssertNotNil(chatManager.loadedModel)
        XCTAssertEqual(chatManager.loadedModel?.modelInfo.id, mockModelInfo.id)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingDuringEngineSwitch() async throws {
        // Test switching to an invalid engine type
        // Note: Since EngineType is an enum, we can't easily test invalid types
        // Instead, test switching when system doesn't support the engine
        
        if !engineManager.isEngineAvailable(.mlx) {
            do {
                try await engineManager.switchToEngine(.mlx)
                XCTFail("Should have thrown an error")
            } catch {
                XCTAssertTrue(error is ManyLLMError)
            }
        }
    }
    
    func testErrorHandlingDuringModelLoad() async throws {
        try await engineManager.switchToEngine(.mock)
        
        // Test loading an invalid model
        let invalidModel = ModelInfo(
            id: "invalid-model",
            name: "Invalid Model",
            author: "Test",
            description: "Invalid model for testing",
            size: 0,
            parameters: "0B",
            isLocal: false, // Not local, no path
            isLoaded: false,
            compatibility: .incompatible
        )
        
        // This might succeed with mock engine, so we just test it doesn't crash
        do {
            try await engineManager.loadModel(invalidModel)
        } catch {
            // Expected for some invalid models
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testConcurrentEngineSwitches() async throws {
        // Test multiple concurrent engine switches
        let tasks = (0..<5).map { _ in
            Task {
                try await engineManager.switchToEngine(.mock)
            }
        }
        
        // Wait for all tasks to complete
        for task in tasks {
            try await task.value
        }
        
        // Should end up with mock engine
        XCTAssertTrue(engineManager.currentEngine is MockInferenceEngine)
    }
    
    // MARK: - Performance Tests
    
    func testEngineSwitchingPerformance() async throws {
        measure {
            let expectation = XCTestExpectation(description: "Engine switching performance")
            
            Task {
                for _ in 0..<10 {
                    try await engineManager.switchToEngine(.mock)
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 5.0)
        }
    }
    
    func testEngineAvailabilityCheckPerformance() throws {
        measure {
            for _ in 0..<1000 {
                _ = engineManager.isEngineAvailable(.mock)
                _ = engineManager.isEngineAvailable(.mlx)
            }
        }
    }
}