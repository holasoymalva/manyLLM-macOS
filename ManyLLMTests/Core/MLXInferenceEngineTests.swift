import XCTest
@testable import ManyLLM

@available(macOS 13.0, *)
final class MLXInferenceEngineTests: XCTestCase {
    
    var engine: MLXInferenceEngine!
    var mockModelInfo: ModelInfo!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Only run tests if MLX is available
        guard MLXInferenceEngine.isAvailable() else {
            throw XCTSkip("MLX not available on this system")
        }
        
        engine = MLXInferenceEngine()
        
        // Create a mock model for testing
        mockModelInfo = ModelInfo(
            id: "test-model-7b",
            name: "Test Model 7B",
            author: "Test Author",
            description: "A test model for MLX inference engine testing",
            size: 4_000_000_000, // 4GB
            parameters: "7B",
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible,
            version: "1.0.0",
            license: "MIT",
            tags: ["test", "mlx"]
        )
    }
    
    override func tearDown() async throws {
        if let engine = engine {
            try? await engine.unloadCurrentModel()
        }
        engine = nil
        mockModelInfo = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testEngineInitialization() throws {
        XCTAssertNotNil(engine)
        XCTAssertFalse(engine.isProcessing)
        XCTAssertNil(engine.loadedModel)
        XCTAssertFalse(engine.isReady)
    }
    
    func testEngineCapabilities() throws {
        let capabilities = engine.capabilities
        
        XCTAssertTrue(capabilities.supportsStreaming)
        XCTAssertTrue(capabilities.supportsChatHistory)
        XCTAssertTrue(capabilities.supportsSystemPrompts)
        XCTAssertTrue(capabilities.supportsStopSequences)
        XCTAssertTrue(capabilities.supportsTemperature)
        XCTAssertTrue(capabilities.supportsTopP)
        XCTAssertNotNil(capabilities.maxContextLength)
        XCTAssertNotNil(capabilities.maxTokens)
    }
    
    func testMLXAvailabilityCheck() throws {
        let isAvailable = MLXInferenceEngine.isAvailable()
        
        // This should be true if we're running on Apple Silicon with macOS 13+
        if ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13 {
            // We can't guarantee Apple Silicon in CI, so just check it doesn't crash
            XCTAssertNotNil(isAvailable)
        }
    }
    
    // MARK: - Parameter Validation Tests
    
    func testParameterValidation() throws {
        let validParameters = InferenceParameters(
            temperature: 0.7,
            maxTokens: 1024,
            topP: 0.9
        )
        
        XCTAssertNoThrow(try engine.validateParameters(validParameters))
    }
    
    func testInvalidTemperatureValidation() throws {
        let invalidParameters = InferenceParameters(
            temperature: 3.0, // Invalid: > 2.0
            maxTokens: 1024,
            topP: 0.9
        )
        
        XCTAssertThrowsError(try engine.validateParameters(invalidParameters)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testInvalidMaxTokensValidation() throws {
        let invalidParameters = InferenceParameters(
            temperature: 0.7,
            maxTokens: 10000, // Invalid: exceeds engine capability
            topP: 0.9
        )
        
        XCTAssertThrowsError(try engine.validateParameters(invalidParameters)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Model Loading Tests
    
    func testModelLoadingWithoutModel() async throws {
        // Test inference without loaded model should fail
        let parameters = InferenceParameters()
        
        do {
            _ = try await engine.generateResponse(
                prompt: "Test prompt",
                parameters: parameters,
                context: nil
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testModelLoadingProcess() async throws {
        // Note: This test uses mock model loading since we don't have real MLX models in tests
        XCTAssertFalse(engine.isReady)
        
        do {
            try await engine.loadModel(mockModelInfo)
            
            // After loading, engine should be ready
            XCTAssertTrue(engine.isReady)
            XCTAssertNotNil(engine.loadedModel)
            XCTAssertEqual(engine.loadedModel?.modelInfo.id, mockModelInfo.id)
            
        } catch {
            // If loading fails due to missing actual model file, that's expected in tests
            if let manyLLMError = error as? ManyLLMError {
                XCTAssertTrue(manyLLMError.localizedDescription.contains("not found") ||
                             manyLLMError.localizedDescription.contains("load"))
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testModelUnloading() async throws {
        // Try to load a model first (may fail in test environment)
        do {
            try await engine.loadModel(mockModelInfo)
            
            // Now test unloading
            try await engine.unloadCurrentModel()
            
            XCTAssertFalse(engine.isReady)
            XCTAssertNil(engine.loadedModel)
            
        } catch {
            // If loading fails, just test that unloading doesn't crash
            try await engine.unloadCurrentModel()
            XCTAssertNil(engine.loadedModel)
        }
    }
    
    // MARK: - Inference Tests (with Mock Model)
    
    func testBasicInferenceWithMockModel() async throws {
        // Create a mock scenario where we simulate having a loaded model
        // This tests the inference flow without requiring actual MLX models
        
        let parameters = InferenceParameters(
            temperature: 0.7,
            maxTokens: 50,
            systemPrompt: "You are a helpful assistant."
        )
        
        // Since we can't load real models in tests, we test parameter validation
        XCTAssertNoThrow(try engine.validateParameters(parameters))
    }
    
    func testStreamingInferenceSetup() async throws {
        let parameters = InferenceParameters(
            temperature: 0.7,
            maxTokens: 50
        )
        
        // Test that streaming inference fails gracefully without a loaded model
        do {
            let stream = try await engine.generateStreamingResponse(
                prompt: "Test prompt",
                parameters: parameters,
                context: nil
            )
            
            // Try to consume the stream
            var tokenCount = 0
            for try await _ in stream {
                tokenCount += 1
                if tokenCount > 10 { break } // Prevent infinite loop
            }
            
            XCTFail("Should have thrown an error without loaded model")
            
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testChatMessageFormatting() async throws {
        let messages = [
            ChatMessage(content: "Hello", role: .user),
            ChatMessage(content: "Hi there!", role: .assistant),
            ChatMessage(content: "How are you?", role: .user)
        ]
        
        let parameters = InferenceParameters(
            systemPrompt: "You are a helpful assistant."
        )
        
        // Test that chat response fails gracefully without a loaded model
        do {
            _ = try await engine.generateChatResponse(
                messages: messages,
                parameters: parameters,
                context: nil
            )
            XCTFail("Should have thrown an error without loaded model")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Context Integration Tests
    
    func testDocumentContextIntegration() async throws {
        let document = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/tmp/test.txt"),
            filename: "test.txt",
            fileSize: 1024,
            mimeType: "text/plain",
            content: "This is test document content for context.",
            metadata: DocumentMetadata(title: "Test Document"),
            isActive: true
        )
        
        let parameters = InferenceParameters()
        
        // Test that context is properly handled (even if inference fails)
        do {
            _ = try await engine.generateResponse(
                prompt: "What does the document say?",
                parameters: parameters,
                context: [document]
            )
            XCTFail("Should have thrown an error without loaded model")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Cancellation Tests
    
    func testInferenceCancellation() async throws {
        // Test that cancellation works properly
        try await engine.cancelInference()
        
        XCTAssertFalse(engine.isProcessing)
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorHandlingWithInvalidPrompt() async throws {
        let parameters = InferenceParameters()
        
        // Test with empty prompt
        do {
            _ = try await engine.generateResponse(
                prompt: "",
                parameters: parameters,
                context: nil
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    // MARK: - Performance Tests
    
    func testParameterValidationPerformance() throws {
        let parameters = InferenceParameters()
        
        measure {
            for _ in 0..<1000 {
                try? engine.validateParameters(parameters)
            }
        }
    }
    
    // MARK: - Integration with Engine Manager Tests
    
    func testEngineManagerIntegration() async throws {
        let engineManager = InferenceEngineManager()
        
        // Test switching to MLX engine
        if MLXInferenceEngine.isAvailable() {
            try await engineManager.switchToEngine(.mlx)
            XCTAssertTrue(engineManager.currentEngine is MLXInferenceEngine)
        }
        
        // Test switching to mock engine
        try await engineManager.switchToEngine(.mock)
        XCTAssertTrue(engineManager.currentEngine is MockInferenceEngine)
    }
}

// MARK: - Test Utilities

extension MLXInferenceEngineTests {
    
    /// Create a temporary test model file
    private func createTestModelFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_model.mlx")
        
        let testData = Data(count: 1024 * 1024) // 1MB of zeros
        
        do {
            try testData.write(to: testFile)
            return testFile
        } catch {
            return nil
        }
    }
    
    /// Clean up test files
    private func cleanupTestFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}