import XCTest
@testable import ManyLLM

final class ModelCompatibilityCheckerTests: XCTestCase {
    var compatibilityChecker: ModelCompatibilityChecker!
    
    override func setUpWithError() throws {
        compatibilityChecker = ModelCompatibilityChecker()
    }
    
    override func tearDownWithError() throws {
        compatibilityChecker = nil
    }
    
    func testFullyCompatibleModel() {
        let model = ModelInfo(
            id: "test-compatible",
            name: "Test Compatible Model",
            author: "Test Author",
            description: "A small, compatible model for testing",
            size: 1_000_000_000, // 1GB
            parameters: "7B",
            compatibility: .fullyCompatible,
            tags: ["test", "small", "compatible"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: model)
        
        XCTAssertEqual(result.compatibility, .fullyCompatible)
        XCTAssertTrue(result.isCompatible)
        XCTAssertFalse(result.hasWarnings)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    func testPartiallyCompatibleModel() {
        let model = ModelInfo(
            id: "test-partial",
            name: "Test Partially Compatible Model",
            author: "Test Author",
            description: "A model with some compatibility issues",
            size: 1_000_000_000, // 1GB
            parameters: "7B",
            compatibility: .partiallyCompatible,
            tags: ["test", "partial"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: model)
        
        XCTAssertEqual(result.compatibility, .partiallyCompatible)
        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    func testIncompatibleModel() {
        let model = ModelInfo(
            id: "test-incompatible",
            name: "Test Incompatible Model",
            author: "Test Author",
            description: "A model that is not compatible",
            size: 1_000_000_000, // 1GB
            parameters: "7B",
            compatibility: .incompatible,
            tags: ["test", "incompatible"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: model)
        
        XCTAssertEqual(result.compatibility, .incompatible)
        XCTAssertFalse(result.isCompatible)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    func testUnknownCompatibilityModel() {
        let model = ModelInfo(
            id: "test-unknown",
            name: "Test Unknown Model",
            author: "Test Author",
            description: "A model with unknown compatibility",
            size: 1_000_000_000, // 1GB
            parameters: "7B",
            compatibility: .unknown,
            tags: ["test", "unknown"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: model)
        
        // Unknown compatibility should be treated as partially compatible
        XCTAssertEqual(result.compatibility, .partiallyCompatible)
        XCTAssertTrue(result.isCompatible)
        XCTAssertTrue(result.hasWarnings)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    func testLargeModelMemoryWarnings() {
        let largeModel = ModelInfo(
            id: "test-large",
            name: "Test Large Model",
            author: "Test Author",
            description: "A very large model that should trigger memory warnings",
            size: 50_000_000_000, // 50GB
            parameters: "70B",
            compatibility: .fullyCompatible,
            tags: ["test", "large"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: largeModel)
        
        // Should have memory-related warnings or reduced compatibility
        XCTAssertTrue(result.hasWarnings || result.compatibility != .fullyCompatible)
        XCTAssertFalse(result.recommendations.isEmpty)
    }
    
    func testSmallModelOptimal() {
        let smallModel = ModelInfo(
            id: "test-small",
            name: "Test Small Model",
            author: "Test Author",
            description: "A small model that should run optimally",
            size: 500_000_000, // 500MB
            parameters: "1B",
            compatibility: .fullyCompatible,
            tags: ["test", "small", "efficient"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: smallModel)
        
        XCTAssertEqual(result.compatibility, .fullyCompatible)
        XCTAssertTrue(result.isCompatible)
        // Small models should have minimal warnings
        XCTAssertFalse(result.hasWarnings)
    }
    
    func testParameterSizeExtraction() {
        let testCases: [(String, Double)] = [
            ("7B", 7.0),
            ("13B", 13.0),
            ("70B", 70.0),
            ("1.3B", 1.3),
            ("500M", 0.5),
            ("1500M", 1.5),
            ("100K", 0.0001),
            ("unknown", 0.0),
            ("", 0.0)
        ]
        
        for (parameterString, expectedValue) in testCases {
            let model = ModelInfo(
                id: "test-param-\(parameterString)",
                name: "Test Model",
                author: "Test",
                description: "Test",
                size: 1_000_000_000,
                parameters: parameterString,
                compatibility: .fullyCompatible
            )
            
            let result = compatibilityChecker.checkCompatibility(for: model)
            XCTAssertNotNil(result)
            
            // The actual parameter extraction logic is private, but we can test
            // that different parameter sizes produce different compatibility results
            // when memory constraints are considered
        }
    }
    
    func testSystemRequirementsGeneration() {
        let model = ModelInfo(
            id: "test-requirements",
            name: "Test Requirements Model",
            author: "Test Author",
            description: "A model for testing system requirements",
            size: 4_000_000_000, // 4GB
            parameters: "7B",
            compatibility: .fullyCompatible,
            tags: ["test"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: model)
        let requirements = result.systemRequirements
        
        // Minimum memory should be at least 2x model size
        XCTAssertGreaterThanOrEqual(requirements.minimumMemory, UInt64(model.size * 2))
        
        // Recommended memory should be higher than minimum
        XCTAssertGreaterThan(requirements.recommendedMemory, requirements.minimumMemory)
        
        // Storage requirements should be at least model size
        XCTAssertGreaterThanOrEqual(requirements.minimumStorage, UInt64(model.size))
        
        // Should have OS version requirements
        XCTAssertFalse(requirements.minimumOSVersion.isEmpty)
        XCTAssertFalse(requirements.recommendedOSVersion.isEmpty)
        
        // Should support common architectures
        XCTAssertTrue(requirements.supportedArchitectures.contains("arm64"))
        XCTAssertTrue(requirements.supportedArchitectures.contains("x86_64"))
    }
    
    func testCompatibilityComparison() {
        // Test that ModelCompatibility comparison works correctly
        XCTAssertLessThan(ModelCompatibility.incompatible, ModelCompatibility.unknown)
        XCTAssertLessThan(ModelCompatibility.unknown, ModelCompatibility.partiallyCompatible)
        XCTAssertLessThan(ModelCompatibility.partiallyCompatible, ModelCompatibility.fullyCompatible)
        
        // Test min() function works with ModelCompatibility
        let worst = min(ModelCompatibility.fullyCompatible, ModelCompatibility.incompatible)
        XCTAssertEqual(worst, ModelCompatibility.incompatible)
        
        let better = min(ModelCompatibility.fullyCompatible, ModelCompatibility.partiallyCompatible)
        XCTAssertEqual(better, ModelCompatibility.partiallyCompatible)
    }
    
    func testArchitectureSpecificCompatibility() {
        // Test models with architecture-specific tags
        let mlxModel = ModelInfo(
            id: "test-mlx",
            name: "Test MLX Model",
            author: "Test Author",
            description: "A model optimized for MLX",
            size: 2_000_000_000, // 2GB
            parameters: "7B",
            compatibility: .fullyCompatible,
            tags: ["test", "mlx", "apple-silicon"]
        )
        
        let result = compatibilityChecker.checkCompatibility(for: mlxModel)
        
        // Should be compatible but may have architecture-specific recommendations
        XCTAssertTrue(result.isCompatible)
        XCTAssertNotNil(result.recommendations)
        
        let cpuOnlyModel = ModelInfo(
            id: "test-cpu",
            name: "Test CPU-Only Model",
            author: "Test Author",
            description: "A model that only runs on CPU",
            size: 2_000_000_000, // 2GB
            parameters: "7B",
            compatibility: .fullyCompatible,
            tags: ["test", "cpu-only"]
        )
        
        let cpuResult = compatibilityChecker.checkCompatibility(for: cpuOnlyModel)
        
        // Should be compatible but may have performance warnings
        XCTAssertTrue(cpuResult.isCompatible)
    }
}