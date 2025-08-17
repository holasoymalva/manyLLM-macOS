import XCTest
@testable import ManyLLM

@available(macOS 13.0, *)
final class MLXModelValidatorTests: XCTestCase {
    
    var validator: MLXModelValidator!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        validator = MLXModelValidator()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MLXModelValidatorTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDirectory,
            withIntermediateDirectories: true
        )
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary files
        if FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        
        validator = nil
        tempDirectory = nil
        
        try super.tearDownWithError()
    }
    
    // MARK: - Model File Validation Tests
    
    func testValidateValidMLXFile() throws {
        let modelPath = createTestModelFile(name: "valid_model.mlx", size: 1024 * 1024) // 1MB
        
        let result = try validator.validateModelFile(at: modelPath)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.fileFormat, "mlx")
        XCTAssertEqual(result.fileSize, 1024 * 1024)
        XCTAssertEqual(result.estimatedParameters, "< 1B")
        XCTAssertFalse(result.validationMessages.isEmpty)
    }
    
    func testValidateValidSafetensorsFile() throws {
        let modelPath = createTestSafetensorsFile(name: "model.safetensors")
        
        let result = try validator.validateModelFile(at: modelPath)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.fileFormat, "safetensors")
        XCTAssertGreaterThan(result.fileSize, 0)
    }
    
    func testValidateValidGGUFFile() throws {
        let modelPath = createTestGGUFFile(name: "model.gguf")
        
        let result = try validator.validateModelFile(at: modelPath)
        
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.fileFormat, "gguf")
        XCTAssertGreaterThan(result.fileSize, 0)
    }
    
    func testValidateNonExistentFile() {
        let nonExistentPath = tempDirectory.appendingPathComponent("nonexistent.mlx")
        
        XCTAssertThrowsError(try validator.validateModelFile(at: nonExistentPath)) { error in
            if let mlxError = error as? ManyLLMError,
               case .modelNotFound(let message) = mlxError {
                XCTAssertTrue(message.contains("not found"))
            } else {
                XCTFail("Expected modelNotFound error")
            }
        }
    }
    
    func testValidateUnsupportedFileFormat() throws {
        let unsupportedPath = tempDirectory.appendingPathComponent("model.txt")
        try "test content".write(to: unsupportedPath, atomically: true, encoding: .utf8)
        
        XCTAssertThrowsError(try validator.validateModelFile(at: unsupportedPath)) { error in
            if let mlxError = error as? ManyLLMError,
               case .modelLoadFailed(let message) = mlxError {
                XCTAssertTrue(message.contains("Unsupported file format"))
            } else {
                XCTFail("Expected modelLoadFailed error")
            }
        }
    }
    
    func testValidateEmptyFile() throws {
        let emptyPath = tempDirectory.appendingPathComponent("empty.mlx")
        try Data().write(to: emptyPath)
        
        XCTAssertThrowsError(try validator.validateModelFile(at: emptyPath)) { error in
            if let mlxError = error as? ManyLLMError,
               case .modelLoadFailed(let message) = mlxError {
                XCTAssertTrue(message.contains("empty"))
            } else {
                XCTFail("Expected modelLoadFailed error for empty file")
            }
        }
    }
    
    // MARK: - Directory Validation Tests
    
    func testValidateModelsInDirectory() throws {
        // Create multiple test model files
        _ = createTestModelFile(name: "model1.mlx", size: 1024 * 1024)
        _ = createTestSafetensorsFile(name: "model2.safetensors")
        _ = createTestGGUFFile(name: "model3.gguf")
        
        // Create a non-model file (should be ignored)
        let textFile = tempDirectory.appendingPathComponent("readme.txt")
        try "This is not a model".write(to: textFile, atomically: true, encoding: .utf8)
        
        let results = try validator.validateModelsInDirectory(at: tempDirectory)
        
        XCTAssertEqual(results.count, 3) // Should find 3 model files
        
        let formats = Set(results.map { $0.fileFormat })
        XCTAssertEqual(formats, Set(["mlx", "safetensors", "gguf"]))
        
        // All should be valid
        XCTAssertTrue(results.allSatisfy { $0.isValid })
    }
    
    func testValidateModelsInNonExistentDirectory() {
        let nonExistentDir = tempDirectory.appendingPathComponent("nonexistent")
        
        XCTAssertThrowsError(try validator.validateModelsInDirectory(at: nonExistentDir)) { error in
            XCTAssertTrue(error is ManyLLMError)
        }
    }
    
    func testValidateModelsInEmptyDirectory() throws {
        let emptyDir = tempDirectory.appendingPathComponent("empty")
        try FileManager.default.createDirectory(at: emptyDir, withIntermediateDirectories: true)
        
        let results = try validator.validateModelsInDirectory(at: emptyDir)
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - System Compatibility Tests
    
    func testValidateSystemCompatibility() {
        let result = validator.validateSystemCompatibility()
        
        XCTAssertFalse(result.messages.isEmpty)
        
        // Should always pass on macOS 13+ (which is required for this test to run)
        if #available(macOS 13.0, *) {
            XCTAssertTrue(result.messages.contains { $0.contains("macOS 13.0+") })
        }
        
        // Should detect processor type
        XCTAssertTrue(result.messages.contains { $0.contains("processor") })
        
        // Should report memory information
        XCTAssertTrue(result.messages.contains { $0.contains("memory") })
    }
    
    // MARK: - Parameter Estimation Tests
    
    func testParameterEstimation() throws {
        let testCases: [(size: Int64, expectedRange: String)] = [
            (500 * 1024 * 1024, "< 1B"),           // 500MB
            (2 * 1024 * 1024 * 1024, "1-3B"),      // 2GB
            (5 * 1024 * 1024 * 1024, "3-7B"),      // 5GB
            (10 * 1024 * 1024 * 1024, "7-13B"),    // 10GB
            (25 * 1024 * 1024 * 1024, "13-30B"),   // 25GB
            (50 * 1024 * 1024 * 1024, "30-70B"),   // 50GB
            (100 * 1024 * 1024 * 1024, "70B+")     // 100GB
        ]
        
        for (size, expectedRange) in testCases {
            let modelPath = createTestModelFile(name: "test_\(size).mlx", size: size)
            let result = try validator.validateModelFile(at: modelPath)
            
            XCTAssertEqual(result.estimatedParameters, expectedRange,
                          "Size \(size) should estimate \(expectedRange), got \(result.estimatedParameters)")
        }
    }
    
    // MARK: - File Size String Tests
    
    func testFileSizeString() throws {
        let modelPath = createTestModelFile(name: "size_test.mlx", size: 1024 * 1024 * 1024) // 1GB
        let result = try validator.validateModelFile(at: modelPath)
        
        XCTAssertTrue(result.fileSizeString.contains("GB") || result.fileSizeString.contains("MB"))
        XCTAssertFalse(result.fileSizeString.isEmpty)
    }
    
    // MARK: - Error Handling Tests
    
    func testValidationWithCorruptedSafetensorsFile() throws {
        // Create a file with .safetensors extension but invalid content
        let corruptedPath = tempDirectory.appendingPathComponent("corrupted.safetensors")
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Invalid header
        try invalidData.write(to: corruptedPath)
        
        let result = try validator.validateModelFile(at: corruptedPath)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.validationMessages.contains { $0.contains("Invalid Safetensors") })
    }
    
    func testValidationWithCorruptedGGUFFile() throws {
        // Create a file with .gguf extension but invalid magic number
        let corruptedPath = tempDirectory.appendingPathComponent("corrupted.gguf")
        let invalidData = Data([0x00, 0x01, 0x02, 0x03]) // Invalid magic number
        try invalidData.write(to: corruptedPath)
        
        let result = try validator.validateModelFile(at: corruptedPath)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.validationMessages.contains { $0.contains("Invalid GGUF") })
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() throws {
        let modelPath = createTestModelFile(name: "perf_test.mlx", size: 10 * 1024 * 1024) // 10MB
        
        measure {
            do {
                _ = try validator.validateModelFile(at: modelPath)
            } catch {
                XCTFail("Validation failed: \(error)")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestModelFile(name: String, size: Int64) -> URL {
        let path = tempDirectory.appendingPathComponent(name)
        let data = Data(count: Int(size))
        try! data.write(to: path)
        return path
    }
    
    private func createTestSafetensorsFile(name: String) -> URL {
        let path = tempDirectory.appendingPathComponent(name)
        
        // Create a minimal valid safetensors file with proper header
        var data = Data()
        
        // Header length (8 bytes, little endian)
        let headerLength: UInt64 = 16
        withUnsafeBytes(of: headerLength.littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
        
        // Minimal header content (16 bytes)
        let headerContent = "{\"test\":\"data\"}"
        let headerData = headerContent.data(using: .utf8)!
        data.append(headerData)
        
        // Pad to make it larger
        data.append(Data(count: 1024))
        
        try! data.write(to: path)
        return path
    }
    
    private func createTestGGUFFile(name: String) -> URL {
        let path = tempDirectory.appendingPathComponent(name)
        
        // Create a minimal valid GGUF file with proper magic number
        var data = Data()
        
        // GGUF magic number
        data.append("GGUF".data(using: .ascii)!)
        
        // Add some dummy content to make it larger
        data.append(Data(count: 1024))
        
        try! data.write(to: path)
        return path
    }
}