import XCTest
@testable import ManyLLM

@MainActor
final class MockInferenceEngineTests: XCTestCase {
    
    var mockEngine: MockInferenceEngine!
    
    override func setUp() {
        super.setUp()
        mockEngine = MockInferenceEngine()
    }
    
    override func tearDown() {
        mockEngine = nil
        super.tearDown()
    }
    
    // MARK: - Basic Functionality Tests
    
    func testEngineInitialization() {
        XCTAssertNotNil(mockEngine.loadedModel)
        XCTAssertTrue(mockEngine.isReady)
        XCTAssertFalse(mockEngine.isProcessing)
        XCTAssertEqual(mockEngine.capabilities.supportsStreaming, true)
        XCTAssertEqual(mockEngine.capabilities.supportsChatHistory, true)
    }
    
    func testParameterValidation() {
        let validParameters = InferenceParameters(temperature: 0.7, maxTokens: 100)
        XCTAssertNoThrow(try mockEngine.validateParameters(validParameters))
        
        let invalidParameters = InferenceParameters(temperature: 3.0, maxTokens: 100)
        XCTAssertThrowsError(try mockEngine.validateParameters(invalidParameters))
    }
    
    // MARK: - Response Generation Tests
    
    func testBasicResponseGeneration() async throws {
        let parameters = InferenceParameters(temperature: 0.7, maxTokens: 100)
        let response = try await mockEngine.generateResponse(
            prompt: "Hello, how are you?",
            parameters: parameters,
            context: nil
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.finishReason, .completed)
        XCTAssertNotNil(response.tokenCount)
        XCTAssertGreaterThan(response.inferenceTime, 0)
        XCTAssertEqual(response.model, "Mock Model")
    }
    
    func testResponseWithContext() async throws {
        // Create mock processed documents
        let document = ProcessedDocument(
            originalURL: URL(fileURLWithPath: "/test.txt"),
            filename: "test.txt",
            fileSize: 1000,
            mimeType: "text/plain",
            content: "This is test content",
            metadata: DocumentMetadata(),
            isActive: true
        )
        
        let parameters = InferenceParameters(temperature: 0.7, maxTokens: 100)
        let response = try await mockEngine.generateResponse(
            prompt: "What does the document say?",
            parameters: parameters,
            context: [document]
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertTrue(response.content.contains("document"))
    }
    
    func testStreamingResponse() async throws {
        let parameters = InferenceParameters(temperature: 0.7, maxTokens: 50)
        let stream = try await mockEngine.generateStreamingResponse(
            prompt: "Tell me a short story",
            parameters: parameters,
            context: nil
        )
        
        var receivedTokens: [String] = []
        
        do {
            for try await token in stream {
                receivedTokens.append(token)
            }
        } catch {
            XCTFail("Streaming should not throw error: \(error)")
        }
        
        XCTAssertFalse(receivedTokens.isEmpty)
        
        let fullResponse = receivedTokens.joined()
        XCTAssertFalse(fullResponse.isEmpty)
    }
    
    func testChatResponseGeneration() async throws {
        let messages = [
            ChatMessage(content: "Hello", role: .user),
            ChatMessage(content: "Hi there! How can I help you?", role: .assistant),
            ChatMessage(content: "What's the weather like?", role: .user)
        ]
        
        let parameters = InferenceParameters(temperature: 0.7, maxTokens: 100)
        let response = try await mockEngine.generateChatResponse(
            messages: messages,
            parameters: parameters,
            context: nil
        )
        
        XCTAssertFalse(response.content.isEmpty)
        XCTAssertEqual(response.finishReason, .completed)
    }
    
    func testStreamingChatResponse() async throws {
        let messages = [
            ChatMessage(content: "Hello", role: .user)
        ]
        
        let parameters = InferenceParameters(temperature: 0.7, maxTokens: 50)
        let stream = try await mockEngine.generateStreamingChatResponse(
            messages: messages,
            parameters: parameters,
            context: nil
        )
        
        var receivedTokens: [String] = []
        
        do {
            for try await token in stream {
                receivedTokens.append(token)
            }
        } catch {
            XCTFail("Streaming chat should not throw error: \(error)")
        }
        
        XCTAssertFalse(receivedTokens.isEmpty)
    }
    
    // MARK: - Configuration Tests
    
    func testPredefinedResponses() async throws {
        let testPrompt = "Test prompt"
        let testResponse = "Test response"
        
        mockEngine.setPredefinedResponse(for: testPrompt, response: testResponse)
        
        let parameters = InferenceParameters()
        let response = try await mockEngine.generateResponse(
            prompt: testPrompt,
            parameters: parameters,
            context: nil
        )
        
        XCTAssertEqual(response.content, testResponse)
    }
    
    func testResponseDelayConfiguration() async throws {
        mockEngine.responseDelay = 0.1 // Very short delay for testing
        
        let startTime = Date()
        let parameters = InferenceParameters()
        _ = try await mockEngine.generateResponse(
            prompt: "Test",
            parameters: parameters,
            context: nil
        )
        let elapsed = Date().timeIntervalSince(startTime)
        
        XCTAssertGreaterThanOrEqual(elapsed, 0.1)
    }
    
    func testModelLoading() {
        let newModelInfo = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1_000_000_000,
            parameters: "1B",
            isLocal: true,
            compatibility: .compatible
        )
        
        mockEngine.loadMockModel(newModelInfo)
        
        XCTAssertEqual(mockEngine.loadedModel?.modelInfo.id, "test-model")
        XCTAssertEqual(mockEngine.loadedModel?.modelInfo.name, "Test Model")
    }
    
    func testModelUnloading() {
        XCTAssertNotNil(mockEngine.loadedModel)
        
        mockEngine.unloadModel()
        
        XCTAssertNil(mockEngine.loadedModel)
        XCTAssertFalse(mockEngine.isReady)
    }
    
    // MARK: - Error Simulation Tests
    
    func testErrorSimulation() async {
        mockEngine.shouldSimulateErrors = true
        mockEngine.errorProbability = 1.0 // Always error for testing
        
        let parameters = InferenceParameters()
        
        do {
            _ = try await mockEngine.generateResponse(
                prompt: "Test",
                parameters: parameters,
                context: nil
            )
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testCancellation() async throws {
        mockEngine.responseDelay = 2.0 // Long delay to allow cancellation
        
        let parameters = InferenceParameters()
        
        // Start a response generation
        let task = Task {
            try await mockEngine.generateResponse(
                prompt: "Test",
                parameters: parameters,
                context: nil
            )
        }
        
        // Cancel after a short delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        try await mockEngine.cancelInference()
        
        do {
            _ = try await task.value
            // If we get here, the response completed before cancellation
        } catch {
            // Expected if cancellation worked
        }
        
        XCTAssertFalse(mockEngine.isProcessing)
    }
    
    // MARK: - Parameter Influence Tests
    
    func testTemperatureInfluence() async throws {
        let highTempParams = InferenceParameters(temperature: 1.5, maxTokens: 100)
        let lowTempParams = InferenceParameters(temperature: 0.1, maxTokens: 100)
        
        let highTempResponse = try await mockEngine.generateResponse(
            prompt: "Tell me about creativity",
            parameters: highTempParams,
            context: nil
        )
        
        let lowTempResponse = try await mockEngine.generateResponse(
            prompt: "Tell me about creativity",
            parameters: lowTempParams,
            context: nil
        )
        
        // High temperature should mention creativity settings
        XCTAssertTrue(highTempResponse.content.contains("creativity"))
        
        // Low temperature should mention precision settings
        XCTAssertTrue(lowTempResponse.content.contains("precision"))
    }
    
    func testSystemPromptInfluence() async throws {
        let parametersWithSystemPrompt = InferenceParameters(
            temperature: 0.7,
            maxTokens: 100,
            systemPrompt: "You are a helpful assistant"
        )
        
        let response = try await mockEngine.generateResponse(
            prompt: "Hello",
            parameters: parametersWithSystemPrompt,
            context: nil
        )
        
        XCTAssertTrue(response.content.contains("system instructions"))
    }
}