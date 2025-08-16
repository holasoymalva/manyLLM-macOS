import Foundation

/// Comprehensive error types for the ManyLLM application
enum ManyLLMError: LocalizedError, Equatable {
    case modelNotFound(String)
    case modelLoadFailed(String)
    case inferenceError(String)
    case documentProcessingFailed(String)
    case networkError(String)
    case storageError(String)
    case apiServerError(String)
    case validationError(String)
    case insufficientResources(String)
    case unsupportedFormat(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotFound(let modelName):
            return "Model '\(modelName)' could not be found"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .inferenceError(let reason):
            return "Inference failed: \(reason)"
        case .documentProcessingFailed(let reason):
            return "Document processing failed: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .apiServerError(let reason):
            return "API server error: \(reason)"
        case .validationError(let reason):
            return "Validation error: \(reason)"
        case .insufficientResources(let reason):
            return "Insufficient resources: \(reason)"
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .modelNotFound:
            return "Please check that the model exists and try again, or download the model from the model browser."
        case .modelLoadFailed:
            return "Try restarting the application or freeing up system memory before loading the model."
        case .inferenceError:
            return "Check your input parameters and try again. If the problem persists, try reloading the model."
        case .documentProcessingFailed:
            return "Ensure the document is not corrupted and is in a supported format (PDF, DOCX, TXT, CSV)."
        case .networkError:
            return "Check your internet connection and try again."
        case .storageError:
            return "Check available disk space and file permissions."
        case .apiServerError:
            return "Check API server configuration and try restarting the server."
        case .validationError:
            return "Please correct the input and try again."
        case .insufficientResources:
            return "Close other applications or try using a smaller model to free up system resources."
        case .unsupportedFormat:
            return "Please use a supported file format (PDF, DOCX, TXT, CSV)."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .modelNotFound:
            return "The specified model could not be located in the local storage or remote repository."
        case .modelLoadFailed:
            return "The model could not be loaded into memory, possibly due to insufficient resources or corruption."
        case .inferenceError:
            return "The model failed to generate a response, possibly due to invalid parameters or model state."
        case .documentProcessingFailed:
            return "The document could not be processed for text extraction or embedding generation."
        case .networkError:
            return "A network operation failed, preventing communication with remote services."
        case .storageError:
            return "A file system operation failed, preventing data persistence or retrieval."
        case .apiServerError:
            return "The API server encountered an error while processing a request."
        case .validationError:
            return "Input validation failed due to invalid or missing required data."
        case .insufficientResources:
            return "The system does not have enough memory or processing power to complete the operation."
        case .unsupportedFormat:
            return "The file format is not supported by the current document processing pipeline."
        }
    }
}