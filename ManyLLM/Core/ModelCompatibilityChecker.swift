import Foundation
import OSLog

/// Checks model compatibility with the current system
class ModelCompatibilityChecker {
    private let logger = Logger(subsystem: "com.manyllm.app", category: "ModelCompatibilityChecker")
    
    /// System information for compatibility checking
    private struct SystemInfo {
        let architecture: String
        let osVersion: String
        let availableMemory: UInt64
        let hasAppleSilicon: Bool
        let hasMLX: Bool
        
        init() {
            var systemInfo = utsname()
            uname(&systemInfo)
            
            self.architecture = withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingUTF8: $0) ?? "unknown"
                }
            }
            
            self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
            self.availableMemory = ProcessInfo.processInfo.physicalMemory
            self.hasAppleSilicon = architecture.contains("arm64")
            
            // Check if MLX is available (simplified check)
            self.hasMLX = hasAppleSilicon && ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 13
        }
    }
    
    private let systemInfo = SystemInfo()
    
    /// Check compatibility for a model
    func checkCompatibility(for model: ModelInfo) -> ModelCompatibilityResult {
        logger.debug("Checking compatibility for model: \(model.name)")
        
        var warnings: [String] = []
        var compatibility: ModelCompatibility = .fullyCompatible
        
        // Check model format compatibility
        let formatCompatibility = checkFormatCompatibility(model)
        if formatCompatibility.compatibility != .fullyCompatible {
            compatibility = formatCompatibility.compatibility
            warnings.append(contentsOf: formatCompatibility.warnings)
        }
        
        // Check memory requirements
        let memoryCompatibility = checkMemoryRequirements(model)
        if memoryCompatibility.compatibility != .fullyCompatible {
            compatibility = min(compatibility, memoryCompatibility.compatibility)
            warnings.append(contentsOf: memoryCompatibility.warnings)
        }
        
        // Check architecture compatibility
        let archCompatibility = checkArchitectureCompatibility(model)
        if archCompatibility.compatibility != .fullyCompatible {
            compatibility = min(archCompatibility.compatibility, compatibility)
            warnings.append(contentsOf: archCompatibility.warnings)
        }
        
        // Check parameter size compatibility
        let parameterCompatibility = checkParameterCompatibility(model)
        if parameterCompatibility.compatibility != .fullyCompatible {
            compatibility = min(parameterCompatibility.compatibility, compatibility)
            warnings.append(contentsOf: parameterCompatibility.warnings)
        }
        
        let result = ModelCompatibilityResult(
            compatibility: compatibility,
            warnings: warnings,
            recommendations: generateRecommendations(for: model, compatibility: compatibility),
            systemRequirements: generateSystemRequirements(for: model)
        )
        
        logger.info("Compatibility check for \(model.name): \(compatibility.rawValue) with \(warnings.count) warnings")
        return result
    }
    
    /// Check if the model format is supported
    private func checkFormatCompatibility(_ model: ModelInfo) -> (compatibility: ModelCompatibility, warnings: [String]) {
        var warnings: [String] = []
        
        switch model.compatibility {
        case .fullyCompatible:
            return (.fullyCompatible, [])
            
        case .partiallyCompatible:
            warnings.append("This model may have limited functionality on your system")
            return (.partiallyCompatible, warnings)
            
        case .incompatible:
            warnings.append("This model format is not supported on your system")
            return (.incompatible, warnings)
            
        case .unknown:
            warnings.append("Model compatibility has not been verified for your system")
            return (.partiallyCompatible, warnings)
        }
    }
    
    /// Check memory requirements
    private func checkMemoryRequirements(_ model: ModelInfo) -> (compatibility: ModelCompatibility, warnings: [String]) {
        var warnings: [String] = []
        
        // Estimate memory requirements (model size + overhead)
        let estimatedMemoryNeeded = UInt64(model.size) * 2 // 2x for loading overhead
        let availableMemory = systemInfo.availableMemory
        
        if estimatedMemoryNeeded > availableMemory {
            warnings.append("Model requires approximately \(ByteCountFormatter().string(fromByteCount: Int64(estimatedMemoryNeeded))) but only \(ByteCountFormatter().string(fromByteCount: Int64(availableMemory))) is available")
            return (.incompatible, warnings)
        } else if estimatedMemoryNeeded > availableMemory / 2 {
            warnings.append("Model will use significant system memory (\(ByteCountFormatter().string(fromByteCount: Int64(estimatedMemoryNeeded))))")
            return (.partiallyCompatible, warnings)
        }
        
        return (.fullyCompatible, warnings)
    }
    
    /// Check architecture compatibility
    private func checkArchitectureCompatibility(_ model: ModelInfo) -> (compatibility: ModelCompatibility, warnings: [String]) {
        var warnings: [String] = []
        
        // Check if model benefits from Apple Silicon
        if systemInfo.hasAppleSilicon {
            if model.tags.contains("mlx") || model.tags.contains("apple-silicon") {
                return (.fullyCompatible, [])
            } else if model.tags.contains("cpu-only") {
                warnings.append("This model is optimized for CPU and may not utilize Apple Silicon GPU acceleration")
                return (.partiallyCompatible, warnings)
            }
        } else {
            // Intel Mac
            if model.tags.contains("mlx") || model.tags.contains("apple-silicon") {
                warnings.append("This model is optimized for Apple Silicon and may have reduced performance on Intel Macs")
                return (.partiallyCompatible, warnings)
            }
        }
        
        return (.fullyCompatible, warnings)
    }
    
    /// Check parameter size compatibility
    private func checkParameterCompatibility(_ model: ModelInfo) -> (compatibility: ModelCompatibility, warnings: [String]) {
        var warnings: [String] = []
        
        // Extract parameter count from string (e.g., "7B", "13B", "70B")
        let parameterString = model.parameters.uppercased()
        let parameterCount: Double
        
        if parameterString.hasSuffix("B") {
            parameterCount = Double(parameterString.dropLast()) ?? 0
        } else if parameterString.hasSuffix("M") {
            parameterCount = (Double(parameterString.dropLast()) ?? 0) / 1000
        } else {
            return (.fullyCompatible, []) // Unknown format, assume compatible
        }
        
        // Check against system capabilities
        if parameterCount >= 70 {
            if systemInfo.availableMemory < 64 * 1024 * 1024 * 1024 { // 64GB
                warnings.append("Large models (70B+) require significant memory and may run slowly")
                return (.partiallyCompatible, warnings)
            }
        } else if parameterCount >= 30 {
            if systemInfo.availableMemory < 32 * 1024 * 1024 * 1024 { // 32GB
                warnings.append("Medium-large models (30B+) may require substantial memory")
                return (.partiallyCompatible, warnings)
            }
        }
        
        return (.fullyCompatible, warnings)
    }
    
    /// Generate recommendations based on compatibility
    private func generateRecommendations(for model: ModelInfo, compatibility: ModelCompatibility) -> [String] {
        var recommendations: [String] = []
        
        switch compatibility {
        case .fullyCompatible:
            recommendations.append("This model should run optimally on your system")
            
        case .partiallyCompatible:
            recommendations.append("Consider closing other applications to free up memory")
            if !systemInfo.hasAppleSilicon && model.tags.contains("mlx") {
                recommendations.append("Consider using a CPU-optimized version for better performance")
            }
            
        case .incompatible:
            recommendations.append("This model is not compatible with your current system")
            recommendations.append("Consider upgrading your hardware or using a smaller model")
            
        case .unknown:
            recommendations.append("Test the model with a small prompt first to verify functionality")
            recommendations.append("Monitor system performance during initial use")
        }
        
        return recommendations
    }
    
    /// Generate system requirements for the model
    private func generateSystemRequirements(for model: ModelInfo) -> SystemRequirements {
        let estimatedMemory = UInt64(model.size) * 2
        
        return SystemRequirements(
            minimumMemory: estimatedMemory,
            recommendedMemory: estimatedMemory + (4 * 1024 * 1024 * 1024), // +4GB buffer
            minimumStorage: UInt64(model.size),
            recommendedStorage: UInt64(model.size) * 2,
            supportedArchitectures: ["arm64", "x86_64"],
            minimumOSVersion: "macOS 12.0",
            recommendedOSVersion: "macOS 14.0"
        )
    }
}

/// Result of model compatibility check
struct ModelCompatibilityResult {
    let compatibility: ModelCompatibility
    let warnings: [String]
    let recommendations: [String]
    let systemRequirements: SystemRequirements
    
    var isCompatible: Bool {
        return compatibility != .incompatible
    }
    
    var hasWarnings: Bool {
        return !warnings.isEmpty
    }
}

/// System requirements for a model
struct SystemRequirements {
    let minimumMemory: UInt64
    let recommendedMemory: UInt64
    let minimumStorage: UInt64
    let recommendedStorage: UInt64
    let supportedArchitectures: [String]
    let minimumOSVersion: String
    let recommendedOSVersion: String
    
    var minimumMemoryString: String {
        ByteCountFormatter().string(fromByteCount: Int64(minimumMemory))
    }
    
    var recommendedMemoryString: String {
        ByteCountFormatter().string(fromByteCount: Int64(recommendedMemory))
    }
    
    var minimumStorageString: String {
        ByteCountFormatter().string(fromByteCount: Int64(minimumStorage))
    }
    
    var recommendedStorageString: String {
        ByteCountFormatter().string(fromByteCount: Int64(recommendedStorage))
    }
}

// Extension to make ModelCompatibility comparable for min() function
extension ModelCompatibility: Comparable {
    static func < (lhs: ModelCompatibility, rhs: ModelCompatibility) -> Bool {
        let order: [ModelCompatibility] = [.incompatible, .unknown, .partiallyCompatible, .fullyCompatible]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}