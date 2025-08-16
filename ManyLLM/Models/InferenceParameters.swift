import Foundation

/// Parameters for controlling model inference behavior
struct InferenceParameters: Codable, Equatable {
    var temperature: Float
    var maxTokens: Int
    var topP: Float
    var topK: Int?
    var systemPrompt: String
    var stopSequences: [String]
    var repeatPenalty: Float?
    var seed: Int?
    
    init(
        temperature: Float = 0.7,
        maxTokens: Int = 2048,
        topP: Float = 0.9,
        topK: Int? = nil,
        systemPrompt: String = "",
        stopSequences: [String] = [],
        repeatPenalty: Float? = nil,
        seed: Int? = nil
    ) {
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.topP = topP
        self.topK = topK
        self.systemPrompt = systemPrompt
        self.stopSequences = stopSequences
        self.repeatPenalty = repeatPenalty
        self.seed = seed
    }
    
    /// Validate parameter values and return any validation errors
    func validate() throws {
        if temperature < 0.0 || temperature > 2.0 {
            throw ManyLLMError.validationError("Temperature must be between 0.0 and 2.0")
        }
        
        if maxTokens < 1 || maxTokens > 32768 {
            throw ManyLLMError.validationError("Max tokens must be between 1 and 32768")
        }
        
        if topP < 0.0 || topP > 1.0 {
            throw ManyLLMError.validationError("Top-p must be between 0.0 and 1.0")
        }
        
        if let topK = topK, topK < 1 {
            throw ManyLLMError.validationError("Top-k must be greater than 0")
        }
        
        if let repeatPenalty = repeatPenalty, repeatPenalty < 0.0 {
            throw ManyLLMError.validationError("Repeat penalty must be non-negative")
        }
    }
    
    /// Create a copy with modified temperature
    func withTemperature(_ temperature: Float) -> InferenceParameters {
        var copy = self
        copy.temperature = temperature
        return copy
    }
    
    /// Create a copy with modified max tokens
    func withMaxTokens(_ maxTokens: Int) -> InferenceParameters {
        var copy = self
        copy.maxTokens = maxTokens
        return copy
    }
    
    /// Create a copy with modified system prompt
    func withSystemPrompt(_ systemPrompt: String) -> InferenceParameters {
        var copy = self
        copy.systemPrompt = systemPrompt
        return copy
    }
    
    /// Default parameters for different use cases
    static let `default` = InferenceParameters()
    
    static let creative = InferenceParameters(
        temperature: 1.0,
        maxTokens: 2048,
        topP: 0.95
    )
    
    static let precise = InferenceParameters(
        temperature: 0.1,
        maxTokens: 1024,
        topP: 0.8
    )
    
    static let balanced = InferenceParameters(
        temperature: 0.7,
        maxTokens: 2048,
        topP: 0.9
    )
}