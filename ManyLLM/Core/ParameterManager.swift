import Foundation
import SwiftUI

/// Manages inference parameters with validation and real-time updates
@MainActor
class ParameterManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var parameters = InferenceParameters()
    @Published var validationErrors: [String] = []
    @Published var hasValidationErrors: Bool = false
    
    // MARK: - System Prompt Presets
    
    static let systemPromptPresets: [SystemPromptPreset] = [
        SystemPromptPreset(
            name: "Default",
            prompt: "",
            description: "No system prompt - use model's default behavior"
        ),
        SystemPromptPreset(
            name: "Helpful Assistant",
            prompt: "You are a helpful, harmless, and honest AI assistant. Provide clear, accurate, and useful responses.",
            description: "General purpose helpful assistant"
        ),
        SystemPromptPreset(
            name: "Code Assistant",
            prompt: "You are an expert programmer and code reviewer. Provide clear, well-documented code examples and explanations. Focus on best practices, security, and maintainability.",
            description: "Specialized for programming tasks"
        ),
        SystemPromptPreset(
            name: "Research Assistant",
            prompt: "You are a research assistant. Provide thorough, well-sourced information. When uncertain, clearly state limitations and suggest further research directions.",
            description: "Focused on research and analysis"
        ),
        SystemPromptPreset(
            name: "Creative Writer",
            prompt: "You are a creative writing assistant. Help with storytelling, character development, and creative expression. Be imaginative while maintaining coherence.",
            description: "For creative writing tasks"
        ),
        SystemPromptPreset(
            name: "Technical Writer",
            prompt: "You are a technical writing expert. Create clear, concise documentation and explanations. Use appropriate technical terminology while remaining accessible.",
            description: "For technical documentation"
        )
    ]
    
    @Published var selectedPresetName: String = "Default"
    
    // MARK: - Parameter Ranges and Validation
    
    static let temperatureRange: ClosedRange<Float> = 0.0...2.0
    static let maxTokensRange: ClosedRange<Int> = 1...8192
    static let topPRange: ClosedRange<Float> = 0.0...1.0
    
    // MARK: - Initialization
    
    init() {
        validateParameters()
    }
    
    // MARK: - Parameter Updates
    
    /// Update temperature with validation
    func updateTemperature(_ temperature: Float) {
        let clampedValue = max(Self.temperatureRange.lowerBound, 
                              min(Self.temperatureRange.upperBound, temperature))
        parameters.temperature = clampedValue
        validateParameters()
    }
    
    /// Update max tokens with validation
    func updateMaxTokens(_ maxTokens: Int) {
        let clampedValue = max(Self.maxTokensRange.lowerBound,
                              min(Self.maxTokensRange.upperBound, maxTokens))
        parameters.maxTokens = clampedValue
        validateParameters()
    }
    
    /// Update top-p with validation
    func updateTopP(_ topP: Float) {
        let clampedValue = max(Self.topPRange.lowerBound,
                              min(Self.topPRange.upperBound, topP))
        parameters.topP = clampedValue
        validateParameters()
    }
    
    /// Update system prompt from preset
    func selectSystemPromptPreset(_ presetName: String) {
        selectedPresetName = presetName
        if let preset = Self.systemPromptPresets.first(where: { $0.name == presetName }) {
            parameters.systemPrompt = preset.prompt
        }
        validateParameters()
    }
    
    /// Update system prompt directly
    func updateSystemPrompt(_ prompt: String) {
        parameters.systemPrompt = prompt
        // Update selected preset to "Custom" if prompt doesn't match any preset
        if !Self.systemPromptPresets.contains(where: { $0.prompt == prompt }) {
            selectedPresetName = "Custom"
        }
        validateParameters()
    }
    
    /// Reset parameters to defaults
    func resetToDefaults() {
        parameters = InferenceParameters()
        selectedPresetName = "Default"
        validateParameters()
    }
    
    /// Load preset parameters
    func loadPreset(_ preset: ParameterPreset) {
        parameters = preset.parameters
        selectedPresetName = preset.systemPromptName
        validateParameters()
    }
    
    // MARK: - Validation
    
    private func validateParameters() {
        validationErrors.removeAll()
        
        do {
            try parameters.validate()
            hasValidationErrors = false
        } catch let error as ManyLLMError {
            validationErrors.append(error.localizedDescription)
            hasValidationErrors = true
        } catch {
            validationErrors.append("Unknown validation error")
            hasValidationErrors = true
        }
    }
    
    /// Get validation status for a specific parameter
    func getValidationStatus(for parameter: ParameterType) -> ValidationStatus {
        switch parameter {
        case .temperature:
            return parameters.temperature >= Self.temperatureRange.lowerBound && 
                   parameters.temperature <= Self.temperatureRange.upperBound ? .valid : .invalid
        case .maxTokens:
            return parameters.maxTokens >= Self.maxTokensRange.lowerBound && 
                   parameters.maxTokens <= Self.maxTokensRange.upperBound ? .valid : .invalid
        case .topP:
            return parameters.topP >= Self.topPRange.lowerBound && 
                   parameters.topP <= Self.topPRange.upperBound ? .valid : .invalid
        case .systemPrompt:
            return .valid // System prompt is always valid
        }
    }
}

// MARK: - Supporting Types

struct SystemPromptPreset: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let prompt: String
    let description: String
}

struct ParameterPreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let parameters: InferenceParameters
    let systemPromptName: String
    
    static let presets: [ParameterPreset] = [
        ParameterPreset(
            name: "Balanced",
            description: "Good balance of creativity and coherence",
            parameters: InferenceParameters.balanced,
            systemPromptName: "Default"
        ),
        ParameterPreset(
            name: "Creative",
            description: "More creative and varied responses",
            parameters: InferenceParameters.creative,
            systemPromptName: "Creative Writer"
        ),
        ParameterPreset(
            name: "Precise",
            description: "Focused and deterministic responses",
            parameters: InferenceParameters.precise,
            systemPromptName: "Helpful Assistant"
        ),
        ParameterPreset(
            name: "Code Generation",
            description: "Optimized for programming tasks",
            parameters: InferenceParameters(
                temperature: 0.2,
                maxTokens: 4096,
                topP: 0.8,
                systemPrompt: ""
            ),
            systemPromptName: "Code Assistant"
        )
    ]
}

enum ParameterType {
    case temperature
    case maxTokens
    case topP
    case systemPrompt
}

enum ValidationStatus {
    case valid
    case invalid
    case warning
}