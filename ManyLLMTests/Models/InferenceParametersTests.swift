import XCTest
@testable import ManyLLM

final class InferenceParametersTests: XCTestCase {
    
    func testInferenceParametersInitialization() {
        let params = InferenceParameters()
        
        XCTAssertEqual(params.temperature, 0.7)
        XCTAssertEqual(params.maxTokens, 2048)
        XCTAssertEqual(params.topP, 0.9)
        XCTAssertNil(params.topK)
        XCTAssertEqual(params.systemPrompt, "")
        XCTAssertTrue(params.stopSequences.isEmpty)
        XCTAssertNil(params.repeatPenalty)
        XCTAssertNil(params.seed)
    }
    
    func testInferenceParametersCustomInitialization() {
        let params = InferenceParameters(
            temperature: 1.0,
            maxTokens: 1000,
            topP: 0.8,
            topK: 50,
            systemPrompt: "You are a helpful assistant",
            stopSequences: ["<|end|>", "\n\n"],
            repeatPenalty: 1.1,
            seed: 42
        )
        
        XCTAssertEqual(params.temperature, 1.0)
        XCTAssertEqual(params.maxTokens, 1000)
        XCTAssertEqual(params.topP, 0.8)
        XCTAssertEqual(params.topK, 50)
        XCTAssertEqual(params.systemPrompt, "You are a helpful assistant")
        XCTAssertEqual(params.stopSequences.count, 2)
        XCTAssertEqual(params.repeatPenalty, 1.1)
        XCTAssertEqual(params.seed, 42)
    }
    
    func testInferenceParametersSerialization() throws {
        let originalParams = InferenceParameters(
            temperature: 0.8,
            maxTokens: 1500,
            topP: 0.95,
            systemPrompt: "Test prompt",
            stopSequences: ["STOP"]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalParams)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedParams = try decoder.decode(InferenceParameters.self, from: data)
        
        XCTAssertEqual(originalParams, decodedParams)
    }
    
    func testInferenceParametersValidation() {
        var params = InferenceParameters()
        
        // Valid parameters should not throw
        XCTAssertNoThrow(try params.validate())
        
        // Invalid temperature
        params.temperature = -0.1
        XCTAssertThrowsError(try params.validate()) { error in
            if case ManyLLMError.validationError(let message) = error {
                XCTAssertTrue(message.contains("Temperature"))
            } else {
                XCTFail("Expected validation error for temperature")
            }
        }
        
        params.temperature = 2.1
        XCTAssertThrowsError(try params.validate())
        
        // Reset temperature
        params.temperature = 0.7
        
        // Invalid max tokens
        params.maxTokens = 0
        XCTAssertThrowsError(try params.validate()) { error in
            if case ManyLLMError.validationError(let message) = error {
                XCTAssertTrue(message.contains("Max tokens"))
            } else {
                XCTFail("Expected validation error for max tokens")
            }
        }
        
        params.maxTokens = 50000
        XCTAssertThrowsError(try params.validate())
        
        // Reset max tokens
        params.maxTokens = 2048
        
        // Invalid top-p
        params.topP = -0.1
        XCTAssertThrowsError(try params.validate()) { error in
            if case ManyLLMError.validationError(let message) = error {
                XCTAssertTrue(message.contains("Top-p"))
            } else {
                XCTFail("Expected validation error for top-p")
            }
        }
        
        params.topP = 1.1
        XCTAssertThrowsError(try params.validate())
        
        // Reset top-p
        params.topP = 0.9
        
        // Invalid top-k
        params.topK = 0
        XCTAssertThrowsError(try params.validate()) { error in
            if case ManyLLMError.validationError(let message) = error {
                XCTAssertTrue(message.contains("Top-k"))
            } else {
                XCTFail("Expected validation error for top-k")
            }
        }
        
        // Reset top-k
        params.topK = nil
        
        // Invalid repeat penalty
        params.repeatPenalty = -0.1
        XCTAssertThrowsError(try params.validate()) { error in
            if case ManyLLMError.validationError(let message) = error {
                XCTAssertTrue(message.contains("Repeat penalty"))
            } else {
                XCTFail("Expected validation error for repeat penalty")
            }
        }
    }
    
    func testInferenceParametersModification() {
        let originalParams = InferenceParameters()
        
        let modifiedTemp = originalParams.withTemperature(1.0)
        XCTAssertEqual(modifiedTemp.temperature, 1.0)
        XCTAssertEqual(originalParams.temperature, 0.7) // Original unchanged
        
        let modifiedTokens = originalParams.withMaxTokens(1000)
        XCTAssertEqual(modifiedTokens.maxTokens, 1000)
        XCTAssertEqual(originalParams.maxTokens, 2048) // Original unchanged
        
        let modifiedPrompt = originalParams.withSystemPrompt("New prompt")
        XCTAssertEqual(modifiedPrompt.systemPrompt, "New prompt")
        XCTAssertEqual(originalParams.systemPrompt, "") // Original unchanged
    }
    
    func testInferenceParametersPresets() {
        let defaultParams = InferenceParameters.default
        XCTAssertEqual(defaultParams.temperature, 0.7)
        XCTAssertEqual(defaultParams.maxTokens, 2048)
        
        let creativeParams = InferenceParameters.creative
        XCTAssertEqual(creativeParams.temperature, 1.0)
        XCTAssertEqual(creativeParams.topP, 0.95)
        
        let preciseParams = InferenceParameters.precise
        XCTAssertEqual(preciseParams.temperature, 0.1)
        XCTAssertEqual(preciseParams.maxTokens, 1024)
        
        let balancedParams = InferenceParameters.balanced
        XCTAssertEqual(balancedParams.temperature, 0.7)
        XCTAssertEqual(balancedParams.topP, 0.9)
    }
}