import Foundation
import CryptoKit
import OSLog

/// Handles model integrity verification using checksums and file validation
class ModelIntegrityVerifier {
    private let logger = Logger(subsystem: "com.manyllm.app", category: "ModelIntegrityVerifier")
    private let fileManager = FileManager.default
    
    /// Verification result
    struct VerificationResult {
        let isValid: Bool
        let checksumMatch: Bool?
        let fileSizeMatch: Bool
        let fileReadable: Bool
        let actualSize: Int64
        let expectedSize: Int64
        let actualChecksum: String?
        let expectedChecksum: String?
        let verificationTime: TimeInterval
        let errors: [String]
    }
    
    /// Verify model integrity comprehensively
    func verifyModel(_ model: ModelInfo) async throws -> VerificationResult {
        let startTime = Date()
        var errors: [String] = []
        
        logger.info("Starting integrity verification for model: \(model.name)")
        
        guard let localPath = model.localPath else {
            throw ManyLLMError.modelNotFound("Model has no local path")
        }
        
        // Check if file exists
        guard fileManager.fileExists(atPath: localPath.path) else {
            throw ManyLLMError.modelNotFound("Model file does not exist at path: \(localPath.path)")
        }
        
        // Check if file is readable
        let fileReadable = fileManager.isReadableFile(atPath: localPath.path)
        if !fileReadable {
            errors.append("Model file is not readable")
        }
        
        // Get file attributes
        let attributes = try fileManager.attributesOfItem(atPath: localPath.path)
        guard let actualSize = attributes[.size] as? Int64 else {
            throw ManyLLMError.storageError("Could not determine file size")
        }
        
        // Check file size
        let fileSizeMatch = actualSize == model.size
        if !fileSizeMatch {
            let sizeDifference = abs(actualSize - model.size)
            let tolerance = max(model.size / 100, 1024 * 1024) // 1% or 1MB tolerance
            
            if sizeDifference > tolerance {
                errors.append("File size mismatch: expected \(model.size), got \(actualSize)")
            }
        }
        
        // Calculate checksum if we have an expected one
        var actualChecksum: String?
        var checksumMatch: Bool?
        var expectedChecksum: String?
        
        if let modelChecksum = getExpectedChecksum(for: model) {
            expectedChecksum = modelChecksum
            actualChecksum = try await calculateChecksum(at: localPath)
            checksumMatch = actualChecksum == modelChecksum
            
            if checksumMatch == false {
                errors.append("Checksum mismatch: expected \(modelChecksum), got \(actualChecksum ?? "nil")")
            }
        }
        
        // Perform basic file format validation
        do {
            try await validateFileFormat(at: localPath, model: model)
        } catch {
            errors.append("File format validation failed: \(error.localizedDescription)")
        }
        
        let verificationTime = Date().timeIntervalSince(startTime)
        let isValid = errors.isEmpty && fileReadable
        
        let result = VerificationResult(
            isValid: isValid,
            checksumMatch: checksumMatch,
            fileSizeMatch: fileSizeMatch,
            fileReadable: fileReadable,
            actualSize: actualSize,
            expectedSize: model.size,
            actualChecksum: actualChecksum,
            expectedChecksum: expectedChecksum,
            verificationTime: verificationTime,
            errors: errors
        )
        
        logger.info("Integrity verification completed for \(model.name): \(isValid ? "VALID" : "INVALID") (\(String(format: "%.2f", verificationTime))s)")
        
        if !errors.isEmpty {
            logger.warning("Verification errors for \(model.name): \(errors.joined(separator: ", "))")
        }
        
        return result
    }
    
    /// Quick integrity check (file existence and basic size check)
    func quickVerify(_ model: ModelInfo) throws -> Bool {
        guard let localPath = model.localPath else {
            return false
        }
        
        guard fileManager.fileExists(atPath: localPath.path) else {
            return false
        }
        
        guard fileManager.isReadableFile(atPath: localPath.path) else {
            return false
        }
        
        // Quick size check with tolerance
        do {
            let attributes = try fileManager.attributesOfItem(atPath: localPath.path)
            if let actualSize = attributes[.size] as? Int64 {
                let sizeDifference = abs(actualSize - model.size)
                let tolerance = max(model.size / 10, 10 * 1024 * 1024) // 10% or 10MB tolerance for quick check
                return sizeDifference <= tolerance
            }
        } catch {
            logger.error("Failed to get file attributes for quick verification: \(error.localizedDescription)")
            return false
        }
        
        return true
    }
    
    /// Repair a corrupted model by re-downloading
    func repairModel(_ model: ModelInfo, using repository: ModelRepository) async throws -> ModelInfo {
        logger.info("Attempting to repair model: \(model.name)")
        
        // Delete the corrupted file
        if let localPath = model.localPath, fileManager.fileExists(atPath: localPath.path) {
            try fileManager.removeItem(at: localPath)
            logger.info("Removed corrupted model file: \(localPath.path)")
        }
        
        // Re-download the model
        let repairedModel = try await repository.downloadModel(model) { progress in
            // Progress handling would be done by the caller
        }
        
        // Verify the repaired model
        let verification = try await verifyModel(repairedModel)
        if !verification.isValid {
            throw ManyLLMError.storageError("Model repair failed - downloaded model is still invalid")
        }
        
        logger.info("Successfully repaired model: \(model.name)")
        return repairedModel
    }
}

// MARK: - Private Methods

private extension ModelIntegrityVerifier {
    
    /// Calculate SHA-256 checksum of a file
    func calculateChecksum(at url: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let data = try Data(contentsOf: url)
                    let hash = SHA256.hash(data: data)
                    let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: hashString)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get expected checksum for a model (would be stored in metadata or fetched from repository)
    func getExpectedChecksum(for model: ModelInfo) -> String? {
        // In a real implementation, this would:
        // 1. Check model metadata for stored checksum
        // 2. Fetch checksum from remote repository
        // 3. Look up checksum in a local database
        
        // For now, return nil (no checksum available)
        return nil
    }
    
    /// Validate file format based on model type
    func validateFileFormat(at url: URL, model: ModelInfo) async throws {
        let fileExtension = url.pathExtension.lowercased()
        
        // Read first few bytes to check file signature
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }
        
        let headerData = handle.readData(ofLength: 16)
        guard headerData.count >= 4 else {
            throw ManyLLMError.storageError("File is too small to be a valid model")
        }
        
        // Check for common model file formats
        try validateModelFileSignature(headerData, extension: fileExtension, model: model)
    }
    
    /// Validate model file signature based on format
    func validateModelFileSignature(_ headerData: Data, extension: String, model: ModelInfo) throws {
        let header = headerData.prefix(16)
        
        switch extension {
        case "gguf":
            // GGUF format signature: "GGUF"
            let ggufSignature = Data([0x47, 0x47, 0x55, 0x46]) // "GGUF"
            if !header.starts(with: ggufSignature) {
                throw ManyLLMError.storageError("Invalid GGUF file signature")
            }
            
        case "ggml":
            // GGML format signature: "ggml"
            let ggmlSignature = Data([0x67, 0x67, 0x6D, 0x6C]) // "ggml"
            if !header.starts(with: ggmlSignature) {
                throw ManyLLMError.storageError("Invalid GGML file signature")
            }
            
        case "bin", "safetensors":
            // For .bin and .safetensors files, we do basic validation
            // SafeTensors has a specific header format, but we'll do minimal validation
            if header.allSatisfy({ $0 == 0 }) {
                throw ManyLLMError.storageError("File appears to be empty or corrupted")
            }
            
        case "pth", "pt":
            // PyTorch model files - check for pickle signature
            let pickleSignature = Data([0x80, 0x02]) // Pickle protocol 2
            let pickleSignature3 = Data([0x80, 0x03]) // Pickle protocol 3
            let pickleSignature4 = Data([0x80, 0x04]) // Pickle protocol 4
            
            if !header.starts(with: pickleSignature) &&
               !header.starts(with: pickleSignature3) &&
               !header.starts(with: pickleSignature4) {
                // Not a strict requirement, just log a warning
                logger.warning("PyTorch file may not have expected pickle signature")
            }
            
        default:
            // For unknown extensions, just check it's not empty
            if header.allSatisfy({ $0 == 0 }) {
                throw ManyLLMError.storageError("File appears to be empty or corrupted")
            }
        }
        
        logger.debug("File format validation passed for \(extension) file")
    }
}

// MARK: - Extensions

extension ModelIntegrityVerifier.VerificationResult {
    
    /// Human-readable summary of verification result
    var summary: String {
        if isValid {
            return "Model integrity verified successfully"
        } else {
            return "Model integrity verification failed: \(errors.joined(separator: ", "))"
        }
    }
    
    /// Detailed verification report
    var detailedReport: String {
        var report = ["Model Integrity Verification Report"]
        report.append("=====================================")
        report.append("Overall Result: \(isValid ? "VALID" : "INVALID")")
        report.append("Verification Time: \(String(format: "%.2f", verificationTime))s")
        report.append("")
        
        report.append("File Checks:")
        report.append("- File Readable: \(fileReadable ? "✓" : "✗")")
        report.append("- Size Match: \(fileSizeMatch ? "✓" : "✗") (Expected: \(expectedSize), Actual: \(actualSize))")
        
        if let checksumMatch = checksumMatch {
            report.append("- Checksum Match: \(checksumMatch ? "✓" : "✗")")
            if let expected = expectedChecksum, let actual = actualChecksum {
                report.append("  Expected: \(expected)")
                report.append("  Actual: \(actual)")
            }
        } else {
            report.append("- Checksum: Not available")
        }
        
        if !errors.isEmpty {
            report.append("")
            report.append("Errors:")
            for error in errors {
                report.append("- \(error)")
            }
        }
        
        return report.joined(separator: "\n")
    }
}