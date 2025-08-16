import XCTest
@testable import ManyLLM

final class ManyLLMErrorTests: XCTestCase {
    
    func testErrorDescriptions() {
        let modelNotFoundError = ManyLLMError.modelNotFound("test-model")
        XCTAssertEqual(modelNotFoundError.errorDescription, "Model 'test-model' could not be found")
        
        let modelLoadError = ManyLLMError.modelLoadFailed("insufficient memory")
        XCTAssertEqual(modelLoadError.errorDescription, "Failed to load model: insufficient memory")
        
        let inferenceError = ManyLLMError.inferenceError("invalid parameters")
        XCTAssertEqual(inferenceError.errorDescription, "Inference failed: invalid parameters")
        
        let documentError = ManyLLMError.documentProcessingFailed("corrupted file")
        XCTAssertEqual(documentError.errorDescription, "Document processing failed: corrupted file")
        
        let networkError = ManyLLMError.networkError("connection timeout")
        XCTAssertEqual(networkError.errorDescription, "Network error: connection timeout")
        
        let storageError = ManyLLMError.storageError("disk full")
        XCTAssertEqual(storageError.errorDescription, "Storage error: disk full")
        
        let apiError = ManyLLMError.apiServerError("port in use")
        XCTAssertEqual(apiError.errorDescription, "API server error: port in use")
        
        let validationError = ManyLLMError.validationError("invalid input")
        XCTAssertEqual(validationError.errorDescription, "Validation error: invalid input")
        
        let resourceError = ManyLLMError.insufficientResources("low memory")
        XCTAssertEqual(resourceError.errorDescription, "Insufficient resources: low memory")
        
        let formatError = ManyLLMError.unsupportedFormat("XYZ")
        XCTAssertEqual(formatError.errorDescription, "Unsupported format: XYZ")
    }
    
    func testRecoverySuggestions() {
        let modelNotFoundError = ManyLLMError.modelNotFound("test-model")
        XCTAssertNotNil(modelNotFoundError.recoverySuggestion)
        XCTAssertTrue(modelNotFoundError.recoverySuggestion!.contains("download"))
        
        let modelLoadError = ManyLLMError.modelLoadFailed("insufficient memory")
        XCTAssertNotNil(modelLoadError.recoverySuggestion)
        XCTAssertTrue(modelLoadError.recoverySuggestion!.contains("memory"))
        
        let inferenceError = ManyLLMError.inferenceError("invalid parameters")
        XCTAssertNotNil(inferenceError.recoverySuggestion)
        XCTAssertTrue(inferenceError.recoverySuggestion!.contains("parameters"))
        
        let documentError = ManyLLMError.documentProcessingFailed("corrupted file")
        XCTAssertNotNil(documentError.recoverySuggestion)
        XCTAssertTrue(documentError.recoverySuggestion!.contains("supported format"))
        
        let networkError = ManyLLMError.networkError("connection timeout")
        XCTAssertNotNil(networkError.recoverySuggestion)
        XCTAssertTrue(networkError.recoverySuggestion!.contains("internet connection"))
        
        let storageError = ManyLLMError.storageError("disk full")
        XCTAssertNotNil(storageError.recoverySuggestion)
        XCTAssertTrue(storageError.recoverySuggestion!.contains("disk space"))
        
        let resourceError = ManyLLMError.insufficientResources("low memory")
        XCTAssertNotNil(resourceError.recoverySuggestion)
        XCTAssertTrue(resourceError.recoverySuggestion!.contains("smaller model"))
        
        let formatError = ManyLLMError.unsupportedFormat("XYZ")
        XCTAssertNotNil(formatError.recoverySuggestion)
        XCTAssertTrue(formatError.recoverySuggestion!.contains("supported file format"))
    }
    
    func testFailureReasons() {
        let modelNotFoundError = ManyLLMError.modelNotFound("test-model")
        XCTAssertNotNil(modelNotFoundError.failureReason)
        XCTAssertTrue(modelNotFoundError.failureReason!.contains("could not be located"))
        
        let modelLoadError = ManyLLMError.modelLoadFailed("insufficient memory")
        XCTAssertNotNil(modelLoadError.failureReason)
        XCTAssertTrue(modelLoadError.failureReason!.contains("could not be loaded"))
        
        let inferenceError = ManyLLMError.inferenceError("invalid parameters")
        XCTAssertNotNil(inferenceError.failureReason)
        XCTAssertTrue(inferenceError.failureReason!.contains("failed to generate"))
        
        let documentError = ManyLLMError.documentProcessingFailed("corrupted file")
        XCTAssertNotNil(documentError.failureReason)
        XCTAssertTrue(documentError.failureReason!.contains("could not be processed"))
        
        let validationError = ManyLLMError.validationError("invalid input")
        XCTAssertNotNil(validationError.failureReason)
        XCTAssertTrue(validationError.failureReason!.contains("validation failed"))
    }
    
    func testErrorEquality() {
        let error1 = ManyLLMError.modelNotFound("test-model")
        let error2 = ManyLLMError.modelNotFound("test-model")
        let error3 = ManyLLMError.modelNotFound("other-model")
        let error4 = ManyLLMError.modelLoadFailed("test-model")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }
    
    func testAllErrorTypes() {
        // Ensure all error types can be created and have descriptions
        let errors: [ManyLLMError] = [
            .modelNotFound("test"),
            .modelLoadFailed("test"),
            .inferenceError("test"),
            .documentProcessingFailed("test"),
            .networkError("test"),
            .storageError("test"),
            .apiServerError("test"),
            .validationError("test"),
            .insufficientResources("test"),
            .unsupportedFormat("test")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertNotNil(error.failureReason)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
            XCTAssertFalse(error.failureReason!.isEmpty)
        }
    }
}