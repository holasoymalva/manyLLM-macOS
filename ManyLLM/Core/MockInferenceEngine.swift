import Foundation

/// Mock inference engine for testing and development
class MockInferenceEngine: InferenceEngine, ObservableObject {
    
    // MARK: - Configuration
    
    /// Configurable delay for simulating inference time
    var responseDelay: TimeInterval = 1.0
    
    /// Configurable streaming delay between tokens
    var streamingTokenDelay: TimeInterval = 0.05
    
    /// Whether to simulate errors occasionally
    var shouldSimulateErrors: Bool = false
    
    /// Error simulation probability (0.0 to 1.0)
    var errorProbability: Double = 0.1
    
    /// Predefined responses for testing specific scenarios
    var predefinedResponses: [String: String] = [:]
    
    // MARK: - InferenceEngine Protocol Properties
    
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var loadedModel: LoadedModel?
    
    var isReady: Bool {
        return loadedModel != nil && !isProcessing
    }
    
    let capabilities = InferenceCapabilities(
        supportsStreaming: true,
        supportsChatHistory: true,
        supportsSystemPrompts: true,
        supportsStopSequences: true,
        supportsTemperature: true,
        supportsTopP: true,
        supportsTopK: false,
        supportsRepeatPenalty: false,
        supportsSeed: true,
        maxContextLength: 4096,
        maxTokens: 2048
    )
    
    // MARK: - Private Properties
    
    private var currentTask: Task<Void, Never>?
    private let mockResponses = [
        "I understand your question. Let me provide a helpful response based on the information available.",
        "That's an interesting point. Here's what I think about that topic.",
        "Based on the context you've provided, I can offer the following insights.",
        "I'd be happy to help you with that. Let me break this down for you.",
        "This is a great question that touches on several important aspects.",
        "From my understanding, there are a few key considerations here.",
        "I can see why you're asking about this. Let me explain the main points.",
        "That's a complex topic, but I'll do my best to provide a clear explanation."
    ]
    
    // MARK: - Initialization
    
    init() {
        // Create a mock loaded model for testing
        let mockModelInfo = ModelInfo(
            id: "mock-model-7b",
            name: "Mock Model",
            author: "ManyLLM Team",
            description: "A mock model for testing and development",
            size: 4_000_000_000, // 4GB
            parameters: "7B",
            isLocal: true,
            isLoaded: true,
            compatibility: .compatible,
            version: "1.0.0",
            license: "MIT",
            tags: ["mock", "testing"]
        )
        
        self.loadedModel = LoadedModel(
            id: "mock-loaded-model",
            modelInfo: mockModelInfo,
            memoryUsage: 3_200_000_000, // 3.2GB
            contextLength: 4096,
            vocabularySize: 32000,
            architecture: "MockTransformer"
        )
    }
    
    // MARK: - InferenceEngine Protocol Methods
    
    func generateResponse(
        prompt: String,
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> InferenceResponse {
        
        try validateParameters(parameters)
        
        guard isReady else {
            throw ManyLLMError.inferenceError("Mock engine is not ready")
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        defer {
            Task { @MainActor in
                isProcessing = false
            }
        }
        
        // Simulate processing delay
        try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        
        // Check for cancellation
        try Task.checkCancellation()
        
        // Simulate occasional errors if enabled
        if shouldSimulateErrors && Double.random(in: 0...1) < errorProbability {
            throw ManyLLMError.inferenceError("Simulated inference error for testing")
        }
        
        let startTime = Date()
        let responseContent = generateMockResponse(prompt: prompt, parameters: parameters, context: context)
        let inferenceTime = Date().timeIntervalSince(startTime)
        
        return InferenceResponse(
            content: responseContent,
            finishReason: .completed,
            tokenCount: estimateTokenCount(responseContent),
            inferenceTime: inferenceTime,
            model: loadedModel?.modelInfo.name ?? "Mock Model"
        )
    }
    
    func generateStreamingResponse(
        prompt: String,
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> AsyncThrowingStream<String, Error> {
        
        try validateParameters(parameters)
        
        guard isReady else {
            throw ManyLLMError.inferenceError("Mock engine is not ready")
        }
        
        await MainActor.run {
            isProcessing = true
        }
        
        return AsyncThrowingStream { continuation in
            currentTask = Task {
                defer {
                    Task { @MainActor in
                        isProcessing = false
                    }
                }
                
                do {
                    // Simulate processing delay
                    try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
                    
                    // Check for cancellation
                    try Task.checkCancellation()
                    
                    // Simulate occasional errors if enabled
                    if shouldSimulateErrors && Double.random(in: 0...1) < errorProbability {
                        continuation.finish(throwing: ManyLLMError.inferenceError("Simulated streaming error"))
                        return
                    }
                    
                    let responseContent = generateMockResponse(prompt: prompt, parameters: parameters, context: context)
                    let words = responseContent.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
                    
                    // Stream words with delay to simulate real-time generation
                    for (index, word) in words.enumerated() {
                        try Task.checkCancellation()
                        
                        let tokenToSend = index == 0 ? word : " " + word
                        continuation.yield(tokenToSend)
                        
                        // Add delay between tokens
                        if index < words.count - 1 {
                            try await Task.sleep(nanoseconds: UInt64(streamingTokenDelay * 1_000_000_000))
                        }
                    }
                    
                    continuation.finish()
                    
                } catch is CancellationError {
                    continuation.finish(throwing: ManyLLMError.inferenceError("Inference was cancelled"))
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func generateChatResponse(
        messages: [ChatMessage],
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> InferenceResponse {
        
        // Convert chat messages to a single prompt
        let prompt = formatChatMessages(messages, parameters: parameters)
        return try await generateResponse(prompt: prompt, parameters: parameters, context: context)
    }
    
    func generateStreamingChatResponse(
        messages: [ChatMessage],
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> AsyncThrowingStream<String, Error> {
        
        // Convert chat messages to a single prompt
        let prompt = formatChatMessages(messages, parameters: parameters)
        return try await generateStreamingResponse(prompt: prompt, parameters: parameters, context: context)
    }
    
    func cancelInference() async throws {
        currentTask?.cancel()
        currentTask = nil
        
        await MainActor.run {
            isProcessing = false
        }
    }
    
    func validateParameters(_ parameters: InferenceParameters) throws {
        try parameters.validate()
        
        // Additional mock-specific validation
        if parameters.maxTokens > capabilities.maxTokens ?? Int.max {
            throw ManyLLMError.validationError("Max tokens exceeds engine capability")
        }
    }
    
    // MARK: - Mock-Specific Methods
    
    /// Set a predefined response for a specific prompt (useful for testing)
    func setPredefinedResponse(for prompt: String, response: String) {
        predefinedResponses[prompt] = response
    }
    
    /// Clear all predefined responses
    func clearPredefinedResponses() {
        predefinedResponses.removeAll()
    }
    
    /// Simulate loading a different model
    func loadMockModel(_ modelInfo: ModelInfo) {
        let loadedModel = LoadedModel(
            id: "mock-\(modelInfo.id)",
            modelInfo: modelInfo,
            memoryUsage: Int64.random(in: 1_000_000_000...8_000_000_000), // 1-8GB
            contextLength: Int.random(in: 2048...8192),
            vocabularySize: Int.random(in: 30000...50000),
            architecture: "MockTransformer"
        )
        
        self.loadedModel = loadedModel
    }
    
    /// Simulate unloading the current model
    func unloadModel() {
        loadedModel = nil
    }
    
    // MARK: - Private Helper Methods
    
    private func generateMockResponse(
        prompt: String,
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) -> String {
        
        // Check for predefined response first
        if let predefinedResponse = predefinedResponses[prompt] {
            return predefinedResponse
        }
        
        // Generate contextual response based on input
        var response = ""
        
        // Add context awareness if documents are provided
        if let context = context, !context.isEmpty {
            let activeDocuments = context.filter { $0.isActive }
            if !activeDocuments.isEmpty {
                response += "Based on the \(activeDocuments.count) document(s) you've provided, "
            }
        }
        
        // Add system prompt awareness
        if !parameters.systemPrompt.isEmpty {
            response += "Following your system instructions, "
        }
        
        // Select a base response
        let baseResponse = mockResponses.randomElement() ?? mockResponses[0]
        response += baseResponse
        
        // Adjust response length based on maxTokens parameter
        let targetLength = min(parameters.maxTokens * 4, 500) // Rough token-to-character ratio
        if response.count < targetLength {
            response += " " + generateAdditionalContent(targetLength: targetLength - response.count)
        } else if response.count > targetLength {
            response = String(response.prefix(targetLength))
        }
        
        // Add temperature-based variation
        if parameters.temperature > 0.8 {
            response += " This response has been generated with high creativity settings."
        } else if parameters.temperature < 0.3 {
            response += " This response prioritizes precision and consistency."
        }
        
        return response
    }
    
    private func generateAdditionalContent(targetLength: Int) -> String {
        let additionalPhrases = [
            "This demonstrates the key concepts involved.",
            "There are several important factors to consider.",
            "The implementation details may vary depending on your specific use case.",
            "It's worth noting that best practices recommend careful consideration of these aspects.",
            "The results may differ based on the parameters and context provided."
        ]
        
        var content = ""
        while content.count < targetLength && !additionalPhrases.isEmpty {
            let phrase = additionalPhrases.randomElement() ?? ""
            if content.count + phrase.count + 1 <= targetLength {
                content += (content.isEmpty ? "" : " ") + phrase
            } else {
                break
            }
        }
        
        return content
    }
    
    private func formatChatMessages(_ messages: [ChatMessage], parameters: InferenceParameters) -> String {
        var prompt = ""
        
        // Add system prompt if provided
        if !parameters.systemPrompt.isEmpty {
            prompt += "System: \(parameters.systemPrompt)\n\n"
        }
        
        // Add conversation history
        for message in messages {
            let rolePrefix = message.role == .user ? "User" : "Assistant"
            prompt += "\(rolePrefix): \(message.content)\n"
        }
        
        prompt += "Assistant:"
        return prompt
    }
    
    private func estimateTokenCount(_ text: String) -> Int {
        // Rough estimation: 1 token ≈ 4 characters for English text
        return max(1, text.count / 4)
    }
}