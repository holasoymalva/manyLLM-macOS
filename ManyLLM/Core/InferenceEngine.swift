import Foundation

/// Response from an inference operation
struct InferenceResponse {
    let content: String
    let finishReason: FinishReason
    let tokenCount: Int?
    let inferenceTime: TimeInterval
    let model: String
    
    enum FinishReason: String, Codable {
        case completed = "completed"
        case maxTokens = "max_tokens"
        case stopSequence = "stop_sequence"
        case error = "error"
        case cancelled = "cancelled"
    }
}

/// Protocol for generating text responses using loaded models
protocol InferenceEngine {
    /// Generate a response for the given prompt
    func generateResponse(
        prompt: String,
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> InferenceResponse
    
    /// Generate a streaming response for the given prompt
    func generateStreamingResponse(
        prompt: String,
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> AsyncThrowingStream<String, Error>
    
    /// Generate a response with chat history context
    func generateChatResponse(
        messages: [ChatMessage],
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> InferenceResponse
    
    /// Generate a streaming chat response
    func generateStreamingChatResponse(
        messages: [ChatMessage],
        parameters: InferenceParameters,
        context: [ProcessedDocument]?
    ) async throws -> AsyncThrowingStream<String, Error>
    
    /// Cancel an ongoing inference operation
    func cancelInference() async throws
    
    /// Check if the engine is currently processing
    var isProcessing: Bool { get }
    
    /// Get the currently loaded model
    var loadedModel: LoadedModel? { get }
    
    /// Check if the engine is ready for inference
    var isReady: Bool { get }
    
    /// Get engine-specific capabilities
    var capabilities: InferenceCapabilities { get }
    
    /// Validate parameters for this engine
    func validateParameters(_ parameters: InferenceParameters) throws
}

/// Capabilities supported by an inference engine
struct InferenceCapabilities {
    let supportsStreaming: Bool
    let supportsChatHistory: Bool
    let supportsSystemPrompts: Bool
    let supportsStopSequences: Bool
    let supportsTemperature: Bool
    let supportsTopP: Bool
    let supportsTopK: Bool
    let supportsRepeatPenalty: Bool
    let supportsSeed: Bool
    let maxContextLength: Int?
    let maxTokens: Int?
    
    init(
        supportsStreaming: Bool = true,
        supportsChatHistory: Bool = true,
        supportsSystemPrompts: Bool = true,
        supportsStopSequences: Bool = true,
        supportsTemperature: Bool = true,
        supportsTopP: Bool = true,
        supportsTopK: Bool = false,
        supportsRepeatPenalty: Bool = false,
        supportsSeed: Bool = false,
        maxContextLength: Int? = nil,
        maxTokens: Int? = nil
    ) {
        self.supportsStreaming = supportsStreaming
        self.supportsChatHistory = supportsChatHistory
        self.supportsSystemPrompts = supportsSystemPrompts
        self.supportsStopSequences = supportsStopSequences
        self.supportsTemperature = supportsTemperature
        self.supportsTopP = supportsTopP
        self.supportsTopK = supportsTopK
        self.supportsRepeatPenalty = supportsRepeatPenalty
        self.supportsSeed = supportsSeed
        self.maxContextLength = maxContextLength
        self.maxTokens = maxTokens
    }
}