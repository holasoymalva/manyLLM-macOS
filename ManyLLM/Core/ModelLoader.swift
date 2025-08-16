import Foundation

/// Represents a loaded model ready for inference
struct LoadedModel {
    let info: ModelInfo
    let loadedAt: Date
    let memoryUsage: Int64
    let engineType: String
    
    init(info: ModelInfo, loadedAt: Date = Date(), memoryUsage: Int64, engineType: String) {
        self.info = info
        self.loadedAt = loadedAt
        self.memoryUsage = memoryUsage
        self.engineType = engineType
    }
    
    /// Human-readable memory usage
    var memoryUsageString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: memoryUsage)
    }
}

/// Protocol for loading and managing models in memory
protocol ModelLoader {
    /// Load a model from the given path
    func loadModel(from path: URL) async throws -> LoadedModel
    
    /// Load a model using ModelInfo
    func loadModel(_ model: ModelInfo) async throws -> LoadedModel
    
    /// Unload a currently loaded model
    func unloadModel(_ model: LoadedModel) async throws
    
    /// Check if a model is currently loaded
    func isModelLoaded(_ model: ModelInfo) -> Bool
    
    /// Get the currently loaded model, if any
    func getCurrentlyLoadedModel() -> LoadedModel?
    
    /// Get memory usage of loaded models
    func getMemoryUsage() -> Int64
    
    /// Check if system has enough resources to load a model
    func canLoadModel(_ model: ModelInfo) -> Bool
    
    /// Get estimated memory requirements for a model
    func getEstimatedMemoryRequirement(_ model: ModelInfo) -> Int64
    
    /// Validate model compatibility before loading
    func validateModelCompatibility(_ model: ModelInfo) throws
    
    /// Get supported model formats
    var supportedFormats: [String] { get }
    
    /// Get engine name/type
    var engineName: String { get }
}