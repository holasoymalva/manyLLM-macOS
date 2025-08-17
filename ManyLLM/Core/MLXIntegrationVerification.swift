import Foundation
import os.log

/// Standalone verification for MLX inference engine integration
/// This can be called from the app to verify the integration works correctly
@available(macOS 13.0, *)
class MLXIntegrationVerification {
    
    private let logger = Logger(subsystem: "com.manyllm.app", category: "MLXIntegrationVerification")
    
    /// Run integration verification tests
    func runVerification() async -> VerificationResults {
        logger.info("Starting MLX integration verification")
        
        var results = VerificationResults()
        
        // Test 1: Engine Manager Creation
        await results.add(test: "Engine Manager Creation", result: testEngineManagerCreation())
        
        // Test 2: MLX Engine Availability
        await results.add(test: "MLX Engine Availability", result: testMLXEngineAvailability())
        
        // Test 3: Engine Switching
        await results.add(test: "Engine Switching", result: testEngineSwitching())
        
        // Test 4: Mock Engine Integration
        await results.add(test: "Mock Engine Integration", result: testMockEngineIntegration())
        
        // Test 5: Parameter Validation
        await results.add(test: "Parameter Validation", result: testParameterValidation())
        
        // Test 6: Chat Manager Integration
        await results.add(test: "Chat Manager Integration", result: testChatManagerIntegration())
        
        logger.info("MLX integration verification completed: \(results.passedCount)/\(results.totalCount) passed")
        
        return results
    }
    
    // MARK: - Individual Verification Tests
    
    @MainActor
    private func testEngineManagerCreation() async -> VerificationResult {
        do {
            let engineManager = InferenceEngineManager()
            
            guard !engineManager.availableEngines.isEmpty else {
                return VerificationResult(passed: false, message: "No engines available")
            }
            
            guard engineManager.availableEngines.contains(where: { $0.type == .mock }) else {
                return VerificationResult(passed: false, message: "Mock engine not available")
            }
            
            return VerificationResult(passed: true, message: "Engine manager created with \(engineManager.availableEngines.count) engines")
            
        } catch {
            return VerificationResult(passed: false, message: "Failed to create engine manager: \(error)")
        }
    }
    
    private func testMLXEngineAvailability() async -> VerificationResult {
        let isAvailable = MLXInferenceEngine.isAvailable()
        
        if isAvailable {
            return VerificationResult(passed: true, message: "MLX engine is available on this system")
        } else {
            return VerificationResult(passed: true, message: "MLX engine not available (expected on Intel Macs or older macOS)")
        }
    }
    
    @MainActor
    private func testEngineSwitching() async -> VerificationResult {
        do {
            let engineManager = InferenceEngineManager()
            
            // Wait for initial setup
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            // Test switching to mock engine
            try await engineManager.switchToEngine(.mock)
            
            guard engineManager.currentEngine is MockInferenceEngine else {
                return VerificationResult(passed: false, message: "Failed to switch to mock engine")
            }
            
            // Test switching to MLX engine if available
            if engineManager.isEngineAvailable(.mlx) {
                try await engineManager.switchToEngine(.mlx)
                
                if #available(macOS 13.0, *) {
                    guard engineManager.currentEngine is MLXInferenceEngine else {
                        return VerificationResult(passed: false, message: "Failed to switch to MLX engine")
                    }
                }
            }
            
            return VerificationResult(passed: true, message: "Engine switching works correctly")
            
        } catch {
            return VerificationResult(passed: false, message: "Engine switching failed: \(error)")
        }
    }
    
    @MainActor
    private func testMockEngineIntegration() async -> VerificationResult {
        do {
            let engineManager = InferenceEngineManager()
            try await engineManager.switchToEngine(.mock)
            
            guard let mockEngine = engineManager.currentEngine as? MockInferenceEngine else {
                return VerificationResult(passed: false, message: "Could not get mock engine")
            }
            
            // Test basic properties
            guard mockEngine.capabilities.supportsStreaming else {
                return VerificationResult(passed: false, message: "Mock engine doesn't support streaming")
            }
            
            // Test parameter validation
            let parameters = InferenceParameters()
            try mockEngine.validateParameters(parameters)
            
            return VerificationResult(passed: true, message: "Mock engine integration working correctly")
            
        } catch {
            return VerificationResult(passed: false, message: "Mock engine integration failed: \(error)")
        }
    }
    
    private func testParameterValidation() async -> VerificationResult {
        do {
            let engine = MLXInferenceEngine()
            
            // Test valid parameters
            let validParams = InferenceParameters(
                temperature: 0.7,
                maxTokens: 1024,
                topP: 0.9
            )
            
            try engine.validateParameters(validParams)
            
            // Test invalid parameters
            let invalidParams = InferenceParameters(
                temperature: 3.0, // Invalid
                maxTokens: 1024,
                topP: 0.9
            )
            
            do {
                try engine.validateParameters(invalidParams)
                return VerificationResult(passed: false, message: "Should have failed validation for invalid parameters")
            } catch {
                // Expected to fail
            }
            
            return VerificationResult(passed: true, message: "Parameter validation working correctly")
            
        } catch {
            return VerificationResult(passed: false, message: "Parameter validation failed: \(error)")
        }
    }
    
    @MainActor
    private func testChatManagerIntegration() async -> VerificationResult {
        do {
            let engineManager = InferenceEngineManager()
            let chatManager = ChatManager(engineManager: engineManager)
            
            // Wait for initialization
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            
            guard chatManager.currentInferenceEngine != nil else {
                return VerificationResult(passed: false, message: "Chat manager has no inference engine")
            }
            
            guard !chatManager.availableEngines.isEmpty else {
                return VerificationResult(passed: false, message: "Chat manager has no available engines")
            }
            
            // Test engine switching through chat manager
            try await chatManager.switchToEngine(.mock)
            
            guard chatManager.currentInferenceEngine is MockInferenceEngine else {
                return VerificationResult(passed: false, message: "Chat manager engine switching failed")
            }
            
            return VerificationResult(passed: true, message: "Chat manager integration working correctly")
            
        } catch {
            return VerificationResult(passed: false, message: "Chat manager integration failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    /// Create a test model for verification
    private func createTestModel() -> ModelInfo {
        return ModelInfo(
            id: "verification-test-model",
            name: "Verification Test Model",
            author: "ManyLLM Team",
            description: "A test model for verification purposes",
            size: 1_000_000_000, // 1GB
            parameters: "1B",
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible,
            version: "1.0.0",
            license: "MIT",
            tags: ["test", "verification"]
        )
    }
}

// MARK: - Verification Result Types

actor VerificationResults {
    private var results: [(name: String, result: VerificationResult)] = []
    
    func add(test name: String, result: VerificationResult) {
        results.append((name: name, result: result))
    }
    
    var totalCount: Int {
        return results.count
    }
    
    var passedCount: Int {
        return results.filter { $0.result.passed }.count
    }
    
    var failedCount: Int {
        return totalCount - passedCount
    }
    
    var allPassed: Bool {
        return failedCount == 0
    }
    
    var summary: String {
        return "Verification: \(passedCount)/\(totalCount) passed"
    }
    
    func detailedReport() -> String {
        var report = "MLX Integration Verification Results\n"
        report += "===================================\n\n"
        
        for (name, result) in results {
            let status = result.passed ? "✓ PASS" : "✗ FAIL"
            report += "\(status) \(name)\n"
            report += "   \(result.message)\n\n"
        }
        
        report += "Summary: \(summary)\n"
        
        return report
    }
}

struct VerificationResult {
    let passed: Bool
    let message: String
}