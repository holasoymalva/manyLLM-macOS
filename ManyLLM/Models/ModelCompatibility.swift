import Foundation

/// Represents the compatibility level of a model with the current system
enum ModelCompatibility: String, Codable, CaseIterable {
    case fullyCompatible = "fully_compatible"
    case partiallyCompatible = "partially_compatible"
    case incompatible = "incompatible"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .fullyCompatible:
            return "Fully Compatible"
        case .partiallyCompatible:
            return "Partially Compatible"
        case .incompatible:
            return "Incompatible"
        case .unknown:
            return "Unknown"
        }
    }
    
    var description: String {
        switch self {
        case .fullyCompatible:
            return "This model is fully compatible with your system and will run optimally."
        case .partiallyCompatible:
            return "This model may have limited functionality or reduced performance on your system."
        case .incompatible:
            return "This model is not compatible with your current system configuration."
        case .unknown:
            return "Compatibility with your system has not been determined."
        }
    }
}