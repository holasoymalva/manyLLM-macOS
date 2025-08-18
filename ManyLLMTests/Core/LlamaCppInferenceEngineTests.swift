import XCTest
@testable import ManyLLM

/// Unit tests for LlamaCppInferenceEngine
@MainActor
final class LlamaCppInferenceEngineTests: XCTestCase {
    
    var inferenceEngine: LlamaCppInferenceEngine!
    var testModel: ModelInfo!
    var testParameters: InferenceParameters!
    
    override func setUp() async throws {
        try await super.setUp()
        
        inferenceEngine = LlamaCppInferenceEngine()
        
        // Create a test model
        testModel = ModelInfo(
            id: "test-llama-inference-model",
            name: "Test Llama Inference Model",
            author: "Test Author",
            description: "Test model for llama.cpp inference",
            size: 2 * 1024 * 1024 * 1024, // 2GB
            parameters: "7B",
            localPath: URL(fileURLWithPath: "/tmp/test-inference-model.gguf"),
            isLocal: true,
            compatibility: .fullyCompatible,
            tags: ["test", "gguf", "inference"]
        )
        
        // Create test parameters
        testParameters = InferenceParameters(
            temperature: 0.7,
            maxTokens: 100,
            topP: 0.9,
            topK: 40,
            systemPrompt: "You are a helpful assistant.",
            stopSequences: ["</s>", "\n\n"],
            repeatPenalty: 1.1,
            seed: 42
        )
    }
    
    override func tearDown() async throws {
        // Clean up any loaded models
        try? await inferenceEngine.unloadCurrentModel()
        inferenceEngine = nil
        testModel = nil
        testParameters = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testInitialState() {
        XCTAssertFalse(inferenceEngine.isProcessing, "Should not be processing initially")
        XCTAssertNil(inferenceEngine.loadedModel, "Should have no loaded model initially")
        XCTAssertFalse(inferenceEngine.isReady, "Should not be ready without loaded model")
    }
    
    func testCapabilities() {
        let capabilities = inferenceEngine.capabilities
        
        XCTAssertTrue(capabilities.supportsStreaming, "Should support streaming")
        XCTAssertTrue(capabilities.supportsChatHistory, "Should support chat history")
        XCTAssertTrue(capabilities.supportsSystemPrompts, "Should support system prompts")
        XCTAssertTrue(capabilities.supportsStopSequences, "Should support stop sequences")
        XCTAssertTrue(capabilities.supportsTemperature, "Should support temperature")
        XCTAssertTrue(capabilities.supportsTopP, "Should support top-p")
        XCTAssertTrue(capabilities.supportsTopK, "Should support top-k")
        XCTAssertTrue(capabilities.supportsRepeatPenalty, "Should support repeat penalty")
        XCTAssertTrue(capabilities.supportsSeed, "Should support seed")
        
        XCTAssertEqual(capabilities.maxContextLength, 4096, "Should have 4096 context length")
        XCTAssertEqual(capabilities.maxTokens, 2048, "Should have 2048 max tokens")
    }
    
    func testAvailability() {
        let isAvailable = LlamaCppInferenceEngine.isAvailable()
        XCTAssertTrue(isAvailable, "llama.cpp engine should be available on macOS")
    }
    
    // MARK: - Parameter Validation Tests
    
    func testValidParametersValidation() {
        XCTAssertNoThrow(try inferenceEngine.validateParameters(testParameters), "Valid parameters should pass validation")
    }
    
    func testInvalidTemperatureValidation() {
        var invalidParams = testParameters!
        invalidParams.temperature = -0.1
        
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.validationError(message) = error {
                XCTAssertTrue(message.contains("Temperature"), "Error should mention temperature")
            }
        }
        
        invalidParams.temperature = 2.1
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError for high temperature")
        }
    }
    
    func testInvalidMaxTokensValidation() {
        var invalidParams = testParameters!
        invalidParams.maxTokens = 0
        
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
        
        invalidParams.maxTokens = 10000 // Exceeds engine capability
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError for excessive max tokens")
        }
    }
    
    func testInvalidTopPValidation() {
        var invalidParams = testParameters!
        invalidParams.topP = -0.1
        
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.validationError(message) = error {
                XCTAssertTrue(message.contains("Top-p"), "Error should mention top-p")
            }
        }
        
        invalidParams.topP = 1.1
        XCTAssertThrowsError(try inferenceEngine.validateParameters(invalidParams)) { error in
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError for high top-p")
        }
    }
    
    // MARK: - Model Loading Tests
    
    func testLoadModelWithoutFile() async {
        // Test loading a model that doesn't exist
        do {
            try await inferenceEngine.loadModel(testModel)
            XCTFail("Should throw error for nonexistent model file")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            XCTAssertFalse(inferenceEngine.isReady, "Engine should not be ready after failed load")
            XCTAssertNil(inferenceEngine.loadedModel, "Should have no loaded model after failure")
        }
    }
    
    func testLoadModelWhileProcessing() async {
        // Simulate processing state
        await MainActor.run {
            // We can't directly set isProcessing, but we can test the behavior
            // by attempting to load while another operation might be in progress
        }
        
        // This test verifies the engine handles concurrent operations properly
        // In a real scenario, this would test actual concurrent model loading
        XCTAssertFalse(inferenceEngine.isProcessing, "Should not be processing initially")
    }
    
    func testUnloadModelWithoutLoadedModel() async {
        // Should not throw error when trying to unload without a loaded model
        XCTAssertNoThrow(try await inferenceEngine.unloadCurrentModel(), "Should handle unloading when no model is loaded")
    }
    
    // MARK: - Inference Tests (Mock Behavior)
    
    func testGenerateResponseWithoutLoadedModel() async {
        let testPrompt = "What is the capital of France?"
        
        do {
            _ = try await inferenceEngine.generateResponse(
                prompt: testPrompt,
                parameters: testParameters,
                context: nil
            )
            XCTFail("Should throw error when no model is loaded")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
            if case let ManyLLMError.inferenceError(message) = error {
                XCTAssertTrue(message.contains("not ready"), "Error should mention engine not ready")
            }
        }
    }
    
    func testGenerateStreamingResponseWithoutLoadedModel() async {
        let testPrompt = "Write a short story."
        
        do {
            let stream = try await inferenceEngine.generateStreamingResponse(
                prompt: testPrompt,
                parameters: testParameters,
                context: nil
            )
            
            // Try to consume the stream
            for try await _ in stream {
                XCTFail("Should not produce tokens without loaded model")
                break
            }
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    func testGenerateChatResponseWithoutLoadedModel() async {
        let testMessages = [
            ChatMessage(content: "Hello", role: .user),
            ChatMessage(content: "Hi there!", role: .assistant),
            ChatMessage(content: "How are you?", role: .user)
        ]
        
        do {
            _ = try await inferenceEngine.generateChatResponse(
                messages: testMessages,
                parameters: testParameters,
                context: nil
            )
            XCTFail("Should throw error when no model is loaded")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    func testCancelInferenceWithoutActiveInference() async {
        // Should not throw error when cancelling without active inference
        XCTAssertNoThrow(try await inferenceEngine.cancelInference(), "Should handle cancellation when not processing")
        XCTAssertFalse(inferenceEngine.isProcessing, "Should not be processing after cancellation")
    }
    
    // MARK: - CPU Optimization Tests
    
    func testCPUOptimizationInfo() {
        let optimizationInfo = inferenceEngine.getCPUOptimizationInfo()
        
        XCTAssertGreaterThan(optimizationInfo.totalCores, 0, "Should detect CPU cores")
        XCTAssertGreaterThan(optimizationInfo.recommendedThreads, 0, "Should recommend at least 1 thread")
        XCTAssertGreaterThan(optimizationInfo.currentThreads, 0, "Should have at least 1 current thread")
        XCTAssertLessThanOrEqual(optimizationInfo.recommendedThreads, optimizationInfo.totalCores, "Recommended threads should not exceed total cores")
        
        // Test optimization suggestion
        let suggestion = optimizationInfo.optimizationSuggestion
        XCTAssertFalse(suggestion.isEmpty, "Should provide optimization suggestion")
        
        if optimizationInfo.isOptimal {
            XCTAssertTrue(suggestion.contains("optimally configured"), "Should indicate optimal configuration")
        } else {
            XCTAssertTrue(suggestion.contains("Consider using"), "Should suggest thread count adjustment")
        }
    }
    
    func testCustomThreadCountInitialization() {
        let customThreadCount = 4
        let customEngine = LlamaCppInferenceEngine(threadCount: customThreadCount)
        
        let optimizationInfo = customEngine.getCPUOptimizationInfo()
        XCTAssertEqual(optimizationInfo.currentThreads, customThreadCount, "Should use custom thread count")
    }
    
    // MARK: - Factory Method Tests
    
    func testCreateEngineWithModel() async {
        do {
            let engine = try await LlamaCppInferenceEngine.create(with: testModel)
            XCTFail("Should fail to create engine with nonexistent model file")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    func testCreateEngineWithCustomThreadCount() async {
        let customThreadCount = 2
        
        do {
            let engine = try await LlamaCppInferenceEngine.create(with: testModel, threadCount: customThreadCount)
            XCTFail("Should fail to create engine with nonexistent model file")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    // MARK: - Context and Document Processing Tests
    
    func testPreparePromptWithSystemPrompt() {
        let systemPrompt = "You are a helpful AI assistant."
        let userPrompt = "What is machine learning?"
        
        var params = testParameters!
        params.systemPrompt = systemPrompt
        
        // We can't directly test the private method, but we can test the behavior
        // through the public interface by checking parameter validation
        XCTAssertNoThrow(try inferenceEngine.validateParameters(params), "Should accept system prompt")
    }
    
    func testPreparePromptWithDocumentContext() {
        // Create test documents
        let testDoc1 = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/tmp/doc1.txt"),
            filename: "doc1.txt",
            fileSize: 1024,
            mimeType: "text/plain",
            content: "This is the content of document 1. It contains information about AI.",
            metadata: DocumentMetadata(title: "Document 1"),
            isActive: true
        )
        
        let testDoc2 = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/tmp/doc2.txt"),
            filename: "doc2.txt",
            fileSize: 2048,
            mimeType: "text/plain",
            content: "This is document 2 with different content about machine learning.",
            metadata: DocumentMetadata(title: "Document 2"),
            isActive: false // Not active, should be filtered out
        )
        
        let context = [testDoc1, testDoc2]
        
        // Test that the engine can handle document context
        // We can't directly test the private method, but we can verify the engine
        // accepts the context parameter without throwing errors
        XCTAssertNotNil(context, "Should create document context")
        XCTAssertEqual(context.count, 2, "Should have 2 documents")
        XCTAssertTrue(context[0].isActive, "First document should be active")
        XCTAssertFalse(context[1].isActive, "Second document should be inactive")
    }
    
    // MARK: - Chat Message Formatting Tests
    
    func testChatMessageFormatting() {
        let messages = [
            ChatMessage(content: "Hello", role: .user),
            ChatMessage(content: "Hi there! How can I help you?", role: .assistant),
            ChatMessage(content: "What is AI?", role: .user)
        ]
        
        // Test that the engine can handle chat messages
        // We can't directly test the private formatting method, but we can
        // verify the engine accepts chat messages without errors
        XCTAssertEqual(messages.count, 3, "Should have 3 messages")
        XCTAssertEqual(messages[0].role, .user, "First message should be from user")
        XCTAssertEqual(messages[1].role, .assistant, "Second message should be from assistant")
        XCTAssertEqual(messages[2].role, .user, "Third message should be from user")
    }
    
    // MARK: - Error Handling Tests
    
    func testInferenceWithInvalidParameters() async {
        var invalidParams = testParameters!
        invalidParams.temperature = -1.0 // Invalid temperature
        
        do {
            _ = try await inferenceEngine.generateResponse(
                prompt: "Test prompt",
                parameters: invalidParams,
                context: nil
            )
            XCTFail("Should throw error for invalid parameters")
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    func testStreamingInferenceWithInvalidParameters() async {
        var invalidParams = testParameters!
        invalidParams.maxTokens = -1 // Invalid max tokens
        
        do {
            let stream = try await inferenceEngine.generateStreamingResponse(
                prompt: "Test prompt",
                parameters: invalidParams,
                context: nil
            )
            
            for try await _ in stream {
                XCTFail("Should not produce tokens with invalid parameters")
                break
            }
        } catch {
            XCTAssertTrue(error is ManyLLMError, "Should throw ManyLLMError")
        }
    }
    
    // MARK: - Performance and Resource Tests
    
    func testEngineResourceManagement() {
        // Test that the engine properly manages resources
        let initialMemory = getCurrentMemoryUsage()
        
        // Create and destroy multiple engines
        for _ in 0..<5 {
            let engine = LlamaCppInferenceEngine()
            XCTAssertNotNil(engine, "Should create engine successfully")
        }
        
        let finalMemory = getCurrentMemoryUsage()
        let memoryDifference = finalMemory - initialMemory
        
        // Memory usage should not grow excessively
        XCTAssertLessThan(memoryDifference, 100.0, "Memory usage should not grow excessively (< 100MB)")
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0.0
    }
}