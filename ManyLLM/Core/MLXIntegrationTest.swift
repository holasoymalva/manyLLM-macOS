import Foundation
import os.log

/// Integration test for MLX framework functionality
/// This can be called manually to verify MLX integration works correctly
@available(macOS 13.0, *)
class MLXIntegrationTest {
    
    private let logger = Logger(subsystem: "com.manyllm.app", category: "MLXIntegrationTest")
    
    /// Run all MLX integration tests
    func runAllTests() async -> TestResults {
        logger.info("Starting MLX integration tests")
        
        var results = TestResults()
        
        // Test 1: MLX Availability
        results.add(test: "MLX Availability", result: testMLXAvailability())
        
        // Test 2: Model Loader Creation
        results.add(test: "Model Loader Creation", result: testModelLoaderCreation())
        
        // Test 3: Memory Manager
        results.add(test: "Memory Manager", result: testMemoryManager())
        
        // Test 4: Model Validator
        results.add(test: "Model Validator", result: testModelValidator())
        
        // Test 5: System Compatibility
        results.add(test: "System Compatibility", result: testSystemCompatibility())
        
        // Test 6: Memory Allocation Check
        results.add(test: "Memory Allocation", result: testMemoryAllocation())
        
        logger.info("MLX integration tests completed: \(results.passedCount)/\(results.totalCount) passed")
        
        return results
    }
    
    // MARK: - Individual Tests
    
    private func testMLXAvailability() -> TestResult {
        let isAvailable = MLXModelLoader.isMLXAvailable()
        
        if isAvailable {
            return TestResult(passed: true, message: "MLX is available on this system")
        } else {
            return TestResult(passed: false, message: "MLX is not available - requires Apple Silicon and macOS 13+")
        }
    }
    
    private func testModelLoaderCreation() -> TestResult {
        do {
            let modelLoader = MLXModelLoader()
            
            let engineName = modelLoader.engineName
            let supportedFormats = modelLoader.supportedFormats
            
            guard engineName == "MLX" else {
                return TestResult(passed: false, message: "Incorrect engine name: \(engineName)")
            }
            
            guard !supportedFormats.isEmpty else {
                return TestResult(passed: false, message: "No supported formats found")
            }
            
            return TestResult(passed: true, message: "Model loader created successfully with \(supportedFormats.count) supported formats")
            
        } catch {
            return TestResult(passed: false, message: "Failed to create model loader: \(error)")
        }
    }
    
    private func testMemoryManager() -> TestResult {
        do {
            let memoryManager = MLXMemoryManager()
            let memoryInfo = memoryManager.getCurrentMemoryUsage()
            
            guard memoryInfo.totalMemory > 0 else {
                return TestResult(passed: false, message: "Invalid total memory: \(memoryInfo.totalMemory)")
            }
            
            guard memoryInfo.availableMemory > 0 else {
                return TestResult(passed: false, message: "No available memory")
            }
            
            let canAllocate = memoryManager.canAllocateMemory(size: 100 * 1024 * 1024) // 100MB
            
            return TestResult(passed: true, message: "Memory manager working - Total: \(memoryInfo.formattedTotalMemory), Available: \(memoryInfo.formattedAvailableMemory), Can allocate 100MB: \(canAllocate)")
            
        } catch {
            return TestResult(passed: false, message: "Memory manager test failed: \(error)")
        }
    }
    
    private func testModelValidator() -> TestResult {
        do {
            let validator = MLXModelValidator()
            let systemCompatibility = validator.validateSystemCompatibility()
            
            let messageCount = systemCompatibility.messages.count
            
            guard messageCount > 0 else {
                return TestResult(passed: false, message: "No compatibility messages generated")
            }
            
            return TestResult(passed: true, message: "Model validator working - \(messageCount) compatibility checks performed, Compatible: \(systemCompatibility.isCompatible)")
            
        } catch {
            return TestResult(passed: false, message: "Model validator test failed: \(error)")
        }
    }
    
    private func testSystemCompatibility() -> TestResult {
        // Check macOS version
        guard #available(macOS 13.0, *) else {
            return TestResult(passed: false, message: "macOS 13.0+ required for MLX")
        }
        
        // Check processor architecture
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        let isAppleSilicon = machine?.hasPrefix("arm64") == true
        
        if isAppleSilicon {
            return TestResult(passed: true, message: "System compatible - Apple Silicon detected: \(machine ?? "unknown")")
        } else {
            return TestResult(passed: true, message: "System partially compatible - Intel Mac detected: \(machine ?? "unknown") (MLX will have limited performance)")
        }
    }
    
    private func testMemoryAllocation() -> TestResult {
        let memoryManager = MLXMemoryManager()
        
        // Test small allocation
        let smallSize: Int64 = 10 * 1024 * 1024 // 10MB
        let canAllocateSmall = memoryManager.canAllocateMemory(size: smallSize)
        
        // Test large allocation
        let largeSize: Int64 = 100 * 1024 * 1024 * 1024 // 100GB
        let canAllocateLarge = memoryManager.canAllocateMemory(size: largeSize)
        
        // Get recommendation for medium model
        let mediumModelSize: Int64 = 4 * 1024 * 1024 * 1024 // 4GB
        let recommendation = memoryManager.getRecommendedAllocation(for: mediumModelSize)
        
        if canAllocateSmall && !canAllocateLarge {
            return TestResult(passed: true, message: "Memory allocation working correctly - Small: ✓, Large: ✗, 4GB model: \(recommendation.strategy)")
        } else {
            return TestResult(passed: false, message: "Memory allocation logic issue - Small: \(canAllocateSmall), Large: \(canAllocateLarge)")
        }
    }
    
    // MARK: - Test File Creation (for file-based tests)
    
    private func createTestModelFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let testFile = tempDir.appendingPathComponent("test_model.mlx")
        
        let testData = Data(count: 1024 * 1024) // 1MB of zeros
        
        do {
            try testData.write(to: testFile)
            return testFile
        } catch {
            logger.error("Failed to create test model file: \(error)")
            return nil
        }
    }
    
    private func cleanupTestFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Test Result Types

struct TestResults {
    private var results: [(name: String, result: TestResult)] = []
    
    mutating func add(test name: String, result: TestResult) {
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
        return "Tests: \(passedCount)/\(totalCount) passed"
    }
    
    var detailedReport: String {
        var report = "MLX Integration Test Results\n"
        report += "============================\n\n"
        
        for (name, result) in results {
            let status = result.passed ? "✓ PASS" : "✗ FAIL"
            report += "\(status) \(name)\n"
            report += "   \(result.message)\n\n"
        }
        
        report += "Summary: \(summary)\n"
        
        return report
    }
}

struct TestResult {
    let passed: Bool
    let message: String
}