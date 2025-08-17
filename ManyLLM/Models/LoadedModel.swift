import Foundation

/// Represents a model that has been loaded into memory and is ready for inference
struct LoadedModel: Identifiable, Equatable {
    let id: String
    let modelInfo: ModelInfo
    let loadedAt: Date
    let memoryUsage: Int64
    let contextLength: Int
    let vocabularySize: Int?
    let architecture: String?
    
    init(
        id: String,
        modelInfo: ModelInfo,
        loadedAt: Date = Date(),
        memoryUsage: Int64,
        contextLength: Int,
        vocabularySize: Int? = nil,
        architecture: String? = nil
    ) {
        self.id = id
        self.modelInfo = modelInfo
        self.loadedAt = loadedAt
        self.memoryUsage = memoryUsage
        self.contextLength = contextLength
        self.vocabularySize = vocabularySize
        self.architecture = architecture
    }
    
    /// Human-readable memory usage string
    var memoryUsageString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: memoryUsage)
    }
    
    /// Display name for the loaded model
    var displayName: String {
        return modelInfo.displayName
    }
    
    /// How long the model has been loaded
    var loadDuration: TimeInterval {
        return Date().timeIntervalSince(loadedAt)
    }
    
    static func == (lhs: LoadedModel, rhs: LoadedModel) -> Bool {
        return lhs.id == rhs.id && lhs.modelInfo.id == rhs.modelInfo.id
    }
}