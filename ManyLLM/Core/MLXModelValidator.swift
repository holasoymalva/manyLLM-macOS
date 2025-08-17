import Foundation
import os.log

/// Utility class for validating MLX model files and compatibility
@available(macOS 13.0, *)
class MLXModelValidator {
    
    private let logger = Logger(subsystem: "com.manyllm.app", category: "MLXModelValidator")
    
    // MARK: - Model File Validation
    
    /// Validates that a model file is compatible with MLX
    func validateModelFile(at path: URL) throws -> ModelValidationResult {
        logger.info("Validating model file at: \(path.path)")
        
        // Check file existence
        guard FileManager.default.fileExists(atPath: path.path) else {
            throw ManyLLMError.modelNotFound("Model file not found at: \(path.path)")
        }
        
        // Check file extension
        let fileExtension = path.pathExtension.lowercased()
        let supportedFormats = ["mlx", "safetensors", "gguf"]
        
        guard supportedFormats.contains(fileExtension) else {
            throw ManyLLMError.modelLoadFailed("Unsupported file format: .\(fileExtension)")
        }
        
        // Check file size
        let fileSize = try getFileSize(at: path)
        guard fileSize > 0 else {
            throw ManyLLMError.modelLoadFailed("Model file is empty")
        }
        
        // Validate file structure based on format
        let structureValidation = try validateFileStructure(at: path, format: fileExtension)
        
        // Check system compatibility
        let systemCompatibility = validateSystemCompatibility()
        
        let result = ModelValidationResult(
            isValid: structureValidation.isValid && systemCompatibility.isCompatible,
            fileFormat: fileExtension,
            fileSize: fileSize,
            estimatedParameters: estimateParameters(from: fileSize),
            systemCompatibility: systemCompatibility,
            validationMessages: structureValidation.messages + systemCompatibility.messages
        )
        
        logger.info("Validation result: \(result.isValid ? "VALID" : "INVALID")")
        return result
    }
    
    /// Validates multiple model files in a directory
    func validateModelsInDirectory(at directoryPath: URL) throws -> [ModelValidationResult] {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directoryPath.path) else {
            throw ManyLLMError.modelNotFound("Directory not found: \(directoryPath.path)")
        }
        
        let contents = try fileManager.contentsOfDirectory(at: directoryPath, includingPropertiesForKeys: nil)
        let modelFiles = contents.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["mlx", "safetensors", "gguf"].contains(ext)
        }
        
        var results: [ModelValidationResult] = []
        
        for modelFile in modelFiles {
            do {
                let result = try validateModelFile(at: modelFile)
                results.append(result)
            } catch {
                logger.error("Failed to validate \(modelFile.lastPathComponent): \(error.localizedDescription)")
                // Create a failed validation result
                let failedResult = ModelValidationResult(
                    isValid: false,
                    fileFormat: modelFile.pathExtension.lowercased(),
                    fileSize: 0,
                    estimatedParameters: "Unknown",
                    systemCompatibility: SystemCompatibilityResult(isCompatible: false, messages: []),
                    validationMessages: ["Validation failed: \(error.localizedDescription)"]
                )
                results.append(failedResult)
            }
        }
        
        return results
    }
    
    // MARK: - System Compatibility Validation
    
    /// Validates system compatibility for MLX
    func validateSystemCompatibility() -> SystemCompatibilityResult {
        var messages: [String] = []
        var isCompatible = true
        
        // Check macOS version
        if #available(macOS 13.0, *) {
            messages.append("✓ macOS 13.0+ requirement met")
        } else {
            messages.append("✗ Requires macOS 13.0 or later")
            isCompatible = false
        }
        
        // Check processor architecture
        if isAppleSilicon() {
            messages.append("✓ Apple Silicon processor detected")
        } else {
            messages.append("⚠ Intel processor detected - MLX performance will be limited")
            // Don't mark as incompatible, but note the limitation
        }
        
        // Check available memory
        let availableMemory = getAvailableMemory()
        let memoryGB = Double(availableMemory) / (1024 * 1024 * 1024)
        
        if memoryGB >= 8.0 {
            messages.append("✓ Sufficient memory available (\(String(format: "%.1f", memoryGB))GB)")
        } else {
            messages.append("⚠ Limited memory available (\(String(format: "%.1f", memoryGB))GB) - may affect large model performance")
        }
        
        return SystemCompatibilityResult(isCompatible: isCompatible, messages: messages)
    }
    
    // MARK: - Private Helper Methods
    
    private func validateFileStructure(at path: URL, format: String) throws -> FileStructureValidation {
        var messages: [String] = []
        var isValid = true
        
        switch format {
        case "mlx":
            isValid = try validateMLXStructure(at: path, messages: &messages)
        case "safetensors":
            isValid = try validateSafetensorsStructure(at: path, messages: &messages)
        case "gguf":
            isValid = try validateGGUFStructure(at: path, messages: &messages)
        default:
            messages.append("Unknown format: \(format)")
            isValid = false
        }
        
        return FileStructureValidation(isValid: isValid, messages: messages)
    }
    
    private func validateMLXStructure(at path: URL, messages: inout [String]) throws -> Bool {
        // Basic MLX file validation
        let fileSize = try getFileSize(at: path)
        
        if fileSize < 1024 {
            messages.append("⚠ MLX file seems unusually small")
            return false
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: path.path) else {
            messages.append("✗ File is not readable")
            return false
        }
        
        messages.append("✓ MLX file structure appears valid")
        return true
    }
    
    private func validateSafetensorsStructure(at path: URL, messages: inout [String]) throws -> Bool {
        // Basic Safetensors validation
        let fileSize = try getFileSize(at: path)
        
        if fileSize < 1024 {
            messages.append("⚠ Safetensors file seems unusually small")
            return false
        }
        
        // Try to read the header (first 8 bytes should contain header length)
        do {
            let fileHandle = try FileHandle(forReadingFrom: path)
            defer { fileHandle.closeFile() }
            
            let headerData = fileHandle.readData(ofLength: 8)
            if headerData.count == 8 {
                messages.append("✓ Safetensors header found")
                return true
            } else {
                messages.append("⚠ Invalid Safetensors header")
                return false
            }
        } catch {
            messages.append("✗ Cannot read Safetensors file: \(error.localizedDescription)")
            return false
        }
    }
    
    private func validateGGUFStructure(at path: URL, messages: inout [String]) throws -> Bool {
        // Basic GGUF validation
        let fileSize = try getFileSize(at: path)
        
        if fileSize < 1024 {
            messages.append("⚠ GGUF file seems unusually small")
            return false
        }
        
        // Check for GGUF magic number
        do {
            let fileHandle = try FileHandle(forReadingFrom: path)
            defer { fileHandle.closeFile() }
            
            let magicData = fileHandle.readData(ofLength: 4)
            let magicString = String(data: magicData, encoding: .ascii)
            
            if magicString == "GGUF" {
                messages.append("✓ Valid GGUF magic number found")
                return true
            } else {
                messages.append("✗ Invalid GGUF magic number")
                return false
            }
        } catch {
            messages.append("✗ Cannot read GGUF file: \(error.localizedDescription)")
            return false
        }
    }
    
    private func getFileSize(at path: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func estimateParameters(from fileSize: Int64) -> String {
        let sizeInGB = Double(fileSize) / (1024 * 1024 * 1024)
        
        switch sizeInGB {
        case 0..<1:
            return "< 1B"
        case 1..<3:
            return "1-3B"
        case 3..<8:
            return "3-7B"
        case 8..<15:
            return "7-13B"
        case 15..<35:
            return "13-30B"
        case 35..<80:
            return "30-70B"
        default:
            return "70B+"
        }
    }
    
    private func isAppleSilicon() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return machine?.hasPrefix("arm64") == true
    }
    
    private func getAvailableMemory() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            var size: UInt64 = 0
            var sizeSize = MemoryLayout<UInt64>.size
            sysctlbyname("hw.memsize", &size, &sizeSize, nil, 0)
            
            let usedMemory = Int64(info.resident_size)
            return Int64(size) - usedMemory
        }
        
        return 8 * 1024 * 1024 * 1024 // 8GB fallback
    }
}

// MARK: - Validation Result Types

/// Result of model file validation
struct ModelValidationResult {
    let isValid: Bool
    let fileFormat: String
    let fileSize: Int64
    let estimatedParameters: String
    let systemCompatibility: SystemCompatibilityResult
    let validationMessages: [String]
    
    var fileSizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}

/// Result of system compatibility check
struct SystemCompatibilityResult {
    let isCompatible: Bool
    let messages: [String]
}

/// Result of file structure validation
private struct FileStructureValidation {
    let isValid: Bool
    let messages: [String]
}