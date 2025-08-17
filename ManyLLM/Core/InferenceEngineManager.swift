import Foundation
import SwiftUI
import os.log

/// Manages different inference engines and provides a unified interface
@MainActor
class InferenceEngineManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentEngine: InferenceEngine?
    @Published var availableEngines: [EngineInfo] = []
    @Published var isLoading: Bool = false
    @Published var loadedModel: LoadedModel?
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.manyllm.app", category: "InferenceEngineManager")
    private var mockEngine: MockInferenceEngine?
    private var mlxEngine: MLXInferenceEngine?
    
    // MARK: - Initialization
    
    init() {
        setupAvailableEngines()
        initializeDefaultEngine()
    }
    
    // MARK: - Public Methods
    
    /// Switch to a specific engine type
    func switchToEngine(_ engineType: EngineType) async throws {
        logger.info("Switching to engine: \(engineType.rawValue)")
        
        isLoading = true
        defer { isLoading = false }
        
        // Unload current engine if any
        if let current = currentEngine {
            try await unloadCurrentEngine()
        }
        
        switch engineType {
        case .mock:
            try await switchToMockEngine()
        case .mlx:
            try await switchToMLXEngine()
        }
        
        logger.info("Successfully switched to \(engineType.rawValue) engine")
    }
    
    /// Load a model into the current engine
    func loadModel(_ model: ModelInfo) async throws {
        guard let engine = currentEngine else {
            throw ManyLLMError.inferenceError("No inference engine available")
        }
        
        logger.info("Loading model: \(model.name)")
        
        isLoading = true
        defer { isLoading = false }
        
        // For MLX engine, we need to load the model directly
        if let mlxEngine = engine as? MLXInferenceEngine {
            try await mlxEngine.loadModel(model)
            loadedModel = mlxEngine.loadedModel
        } else if let mockEngine = engine as? MockInferenceEngine {
            // Mock engine simulates loading
            mockEngine.loadMockModel(model)
            loadedModel = mockEngine.loadedModel
        }
        
        logger.info("Successfully loaded model: \(model.name)")
    }
    
    /// Unload the current model
    func unloadModel() async throws {
        guard let engine = currentEngine else { return }
        
        logger.info("Unloading current model")
        
        if let mlxEngine = engine as? MLXInferenceEngine {
            try await mlxEngine.unloadCurrentModel()
        } else if let mockEngine = engine as? MockInferenceEngine {
            mockEngine.unloadModel()
        }
        
        loadedModel = nil
        logger.info("Successfully unloaded model")
    }
    
    /// Get the best available engine for a given model
    func getBestEngineForModel(_ model: ModelInfo) -> EngineType {
        // Check if MLX is available and model is compatible
        if #available(macOS 13.0, *), MLXInferenceEngine.isAvailable() {
            // Check if model format is supported by MLX
            if let localPath = model.localPath {
                let fileExtension = localPath.pathExtension.lowercased()
                let mlxSupportedFormats = ["mlx", "safetensors", "gguf"]
                if mlxSupportedFormats.contains(fileExtension) {
                    return .mlx
                }
            }
        }
        
        // Fallback to mock engine
        return .mock
    }
    
    /// Check if a specific engine is available
    func isEngineAvailable(_ engineType: EngineType) -> Bool {
        switch engineType {
        case .mock:
            return true
        case .mlx:
            if #available(macOS 13.0, *) {
                return MLXInferenceEngine.isAvailable()
            }
            return false
        }
    }
    
    /// Get engine capabilities
    func getEngineCapabilities(_ engineType: EngineType) -> InferenceCapabilities? {
        switch engineType {
        case .mock:
            return mockEngine?.capabilities ?? MockInferenceEngine().capabilities
        case .mlx:
            if #available(macOS 13.0, *) {
                return mlxEngine?.capabilities ?? MLXInferenceEngine().capabilities
            }
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func setupAvailableEngines() {
        availableEngines = []
        
        // Always add mock engine
        availableEngines.append(EngineInfo(
            type: .mock,
            name: "Mock Engine",
            description: "Development and testing engine",
            isAvailable: true,
            capabilities: MockInferenceEngine().capabilities
        ))
        
        // Add MLX engine if available
        if #available(macOS 13.0, *), MLXInferenceEngine.isAvailable() {
            availableEngines.append(EngineInfo(
                type: .mlx,
                name: "MLX Engine",
                description: "Apple Silicon optimized inference",
                isAvailable: true,
                capabilities: MLXInferenceEngine().capabilities
            ))
        } else {
            availableEngines.append(EngineInfo(
                type: .mlx,
                name: "MLX Engine",
                description: "Requires Apple Silicon and macOS 13+",
                isAvailable: false,
                capabilities: nil
            ))
        }
    }
    
    private func initializeDefaultEngine() {
        Task {
            do {
                // Try to use MLX engine if available, otherwise fall back to mock
                let defaultEngineType: EngineType = isEngineAvailable(.mlx) ? .mlx : .mock
                try await switchToEngine(defaultEngineType)
            } catch {
                logger.error("Failed to initialize default engine: \(error.localizedDescription)")
                // Fallback to mock engine
                try? await switchToEngine(.mock)
            }
        }
    }
    
    private func switchToMockEngine() async throws {
        if mockEngine == nil {
            mockEngine = MockInferenceEngine()
        }
        
        currentEngine = mockEngine
        loadedModel = mockEngine?.loadedModel
    }
    
    private func switchToMLXEngine() async throws {
        guard #available(macOS 13.0, *) else {
            throw ManyLLMError.inferenceError("MLX requires macOS 13.0 or later")
        }
        
        guard MLXInferenceEngine.isAvailable() else {
            throw ManyLLMError.inferenceError("MLX requires Apple Silicon")
        }
        
        if mlxEngine == nil {
            mlxEngine = MLXInferenceEngine()
        }
        
        currentEngine = mlxEngine
        loadedModel = mlxEngine?.loadedModel
    }
    
    private func unloadCurrentEngine() async throws {
        if let mlxEngine = currentEngine as? MLXInferenceEngine {
            try await mlxEngine.unloadCurrentModel()
        } else if let mockEngine = currentEngine as? MockInferenceEngine {
            mockEngine.unloadModel()
        }
        
        currentEngine = nil
        loadedModel = nil
    }
}

// MARK: - Supporting Types

/// Information about an available inference engine
struct EngineInfo: Identifiable {
    let id = UUID()
    let type: EngineType
    let name: String
    let description: String
    let isAvailable: Bool
    let capabilities: InferenceCapabilities?
    
    var displayName: String {
        return isAvailable ? name : "\(name) (Unavailable)"
    }
}

/// Types of inference engines
enum EngineType: String, CaseIterable {
    case mock = "mock"
    case mlx = "mlx"
    
    var displayName: String {
        switch self {
        case .mock:
            return "Mock Engine"
        case .mlx:
            return "MLX Engine"
        }
    }
    
    var description: String {
        switch self {
        case .mock:
            return "Development and testing engine with simulated responses"
        case .mlx:
            return "Apple Silicon optimized inference using MLX framework"
        }
    }
}