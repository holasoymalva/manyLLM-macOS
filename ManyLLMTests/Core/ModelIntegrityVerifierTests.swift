import XCTest
@testable import ManyLLM

final class ModelIntegrityVerifierTests: XCTestCase {
    var verifier: ModelIntegrityVerifier!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        verifier = ModelIntegrityVerifier()
        
        // Create temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ManyLLMIntegrityTests")
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDownWithError() throws {
        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)
        
        verifier = nil
    }
    
    func testVerifyValidModel() async throws {
        // Create a test model file
        let testData = Data("This is a test model file with some content".utf8)
        let modelPath = tempDirectory.appendingPathComponent("valid_model.bin")
        try testData.write(to: modelPath)
        
        let model = ModelInfo(
            id: "valid-test",
            name: "Valid Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        let result = try await verifier.verifyModel(model)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.fileReadable)
        XCTAssertTrue(result.fileSizeMatch)
        XCTAssertEqual(result.actualSize, Int64(testData.count))
        XCTAssertEqual(result.expectedSize, Int64(testData.count))
        XCTAssertTrue(result.errors.isEmpty)
        XCTAssertGreaterThan(result.verificationTime, 0)
    }
    
    func testVerifyModelWithSizeMismatch() async throws {
        // Create a test model file
        let testData = Data("Small file".utf8)
        let modelPath = tempDirectory.appendingPathComponent("size_mismatch.bin")
        try testData.write(to: modelPath)
        
        let model = ModelInfo(
            id: "size-mismatch-test",
            name: "Size Mismatch Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000000, // Much larger than actual file
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        let result = try await verifier.verifyModel(model)
        
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.fileReadable)
        XCTAssertFalse(result.fileSizeMatch)
        XCTAssertEqual(result.actualSize, Int64(testData.count))
        XCTAssertEqual(result.expectedSize, 1000000)
        XCTAssertFalse(result.errors.isEmpty)
        XCTAssertTrue(result.errors.first?.contains("File size mismatch") == true)
    }
    
    func testVerifyNonExistentModel() async throws {
        let model = ModelInfo(
            id: "nonexistent-test",
            name: "Non-existent Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: tempDirectory.appendingPathComponent("nonexistent.bin"),
            isLocal: true
        )
        
        do {
            _ = try await verifier.verifyModel(model)
            XCTFail("Should have thrown error for non-existent model")
        } catch let error as ManyLLMError {
            if case .modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("does not exist"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testVerifyModelWithoutLocalPath() async throws {
        let model = ModelInfo(
            id: "no-path-test",
            name: "No Path Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: nil,
            isLocal: false
        )
        
        do {
            _ = try await verifier.verifyModel(model)
            XCTFail("Should have thrown error for model without local path")
        } catch let error as ManyLLMError {
            if case .modelNotFound(let message) = error {
                XCTAssertTrue(message.contains("no local path"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testQuickVerify() throws {
        // Create a test model file
        let testData = Data("Quick verify test data".utf8)
        let modelPath = tempDirectory.appendingPathComponent("quick_verify.bin")
        try testData.write(to: modelPath)
        
        let validModel = ModelInfo(
            id: "quick-valid",
            name: "Quick Valid Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        XCTAssertTrue(try verifier.quickVerify(validModel))
        
        // Test with non-existent model
        let invalidModel = ModelInfo(
            id: "quick-invalid",
            name: "Quick Invalid Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: tempDirectory.appendingPathComponent("nonexistent.bin"),
            isLocal: true
        )
        
        XCTAssertFalse(try verifier.quickVerify(invalidModel))
        
        // Test with model without local path
        let noPathModel = ModelInfo(
            id: "quick-no-path",
            name: "Quick No Path Model",
            author: "Test Author",
            description: "Test Description",
            size: 1000,
            parameters: "1B",
            localPath: nil,
            isLocal: false
        )
        
        XCTAssertFalse(try verifier.quickVerify(noPathModel))
    }
    
    func testFileFormatValidation() async throws {
        // Test GGUF format
        let ggufData = Data([0x47, 0x47, 0x55, 0x46] + Array(repeating: 0x00, count: 100)) // "GGUF" + padding
        let ggufPath = tempDirectory.appendingPathComponent("test_model.gguf")
        try ggufData.write(to: ggufPath)
        
        let ggufModel = ModelInfo(
            id: "gguf-test",
            name: "GGUF Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(ggufData.count),
            parameters: "1B",
            localPath: ggufPath,
            isLocal: true
        )
        
        let ggufResult = try await verifier.verifyModel(ggufModel)
        XCTAssertTrue(ggufResult.isValid)
        
        // Test GGML format
        let ggmlData = Data([0x67, 0x67, 0x6D, 0x6C] + Array(repeating: 0x01, count: 100)) // "ggml" + padding
        let ggmlPath = tempDirectory.appendingPathComponent("test_model.ggml")
        try ggmlData.write(to: ggmlPath)
        
        let ggmlModel = ModelInfo(
            id: "ggml-test",
            name: "GGML Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(ggmlData.count),
            parameters: "1B",
            localPath: ggmlPath,
            isLocal: true
        )
        
        let ggmlResult = try await verifier.verifyModel(ggmlModel)
        XCTAssertTrue(ggmlResult.isValid)
        
        // Test invalid GGUF format
        let invalidGgufData = Data([0x00, 0x00, 0x00, 0x00] + Array(repeating: 0x01, count: 100))
        let invalidGgufPath = tempDirectory.appendingPathComponent("invalid_model.gguf")
        try invalidGgufData.write(to: invalidGgufPath)
        
        let invalidGgufModel = ModelInfo(
            id: "invalid-gguf-test",
            name: "Invalid GGUF Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(invalidGgufData.count),
            parameters: "1B",
            localPath: invalidGgufPath,
            isLocal: true
        )
        
        let invalidResult = try await verifier.verifyModel(invalidGgufModel)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertTrue(invalidResult.errors.contains { $0.contains("Invalid GGUF file signature") })
    }
    
    func testEmptyFileValidation() async throws {
        // Create empty file
        let emptyPath = tempDirectory.appendingPathComponent("empty_model.bin")
        try Data().write(to: emptyPath)
        
        let emptyModel = ModelInfo(
            id: "empty-test",
            name: "Empty Test Model",
            author: "Test Author",
            description: "Test Description",
            size: 0,
            parameters: "1B",
            localPath: emptyPath,
            isLocal: true
        )
        
        do {
            _ = try await verifier.verifyModel(emptyModel)
            XCTFail("Should have thrown error for empty model file")
        } catch let error as ManyLLMError {
            if case .storageError(let message) = error {
                XCTAssertTrue(message.contains("too small"))
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    func testVerificationResultFormatting() async throws {
        // Create a test model file
        let testData = Data("Test data for formatting".utf8)
        let modelPath = tempDirectory.appendingPathComponent("format_test.bin")
        try testData.write(to: modelPath)
        
        let model = ModelInfo(
            id: "format-test",
            name: "Format Test Model",
            author: "Test Author",
            description: "Test Description",
            size: Int64(testData.count),
            parameters: "1B",
            localPath: modelPath,
            isLocal: true
        )
        
        let result = try await verifier.verifyModel(model)
        
        // Test summary
        XCTAssertFalse(result.summary.isEmpty)
        XCTAssertTrue(result.summary.contains("successfully"))
        
        // Test detailed report
        let report = result.detailedReport
        XCTAssertFalse(report.isEmpty)
        XCTAssertTrue(report.contains("Model Integrity Verification Report"))
        XCTAssertTrue(report.contains("Overall Result"))
        XCTAssertTrue(report.contains("File Checks"))
        XCTAssertTrue(report.contains("Verification Time"))
    }
}