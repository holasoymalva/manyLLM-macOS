import SwiftUI

/// Main settings view accessible from the settings gear
struct SettingsView: View {
    @ObservedObject var parameterManager: ParameterManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: SettingsTab = .parameters
    
    var body: some View {
        NavigationView {
            // Sidebar
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .listStyle(SidebarListStyle())
            .frame(minWidth: 200)
            
            // Content
            Group {
                switch selectedTab {
                case .parameters:
                    ParameterSettingsView(parameterManager: parameterManager)
                case .privacy:
                    PrivacySettingsView()
                case .api:
                    APISettingsView()
                case .general:
                    GeneralSettingsView()
                case .about:
                    AboutSettingsView()
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 700, minHeight: 500)
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Settings tabs
enum SettingsTab: String, CaseIterable {
    case parameters = "Parameters"
    case privacy = "Privacy"
    case api = "API"
    case general = "General"
    case about = "About"
    
    var title: String {
        return rawValue
    }
    
    var icon: String {
        switch self {
        case .parameters:
            return "slider.horizontal.3"
        case .privacy:
            return "shield.lefthalf.filled"
        case .api:
            return "network"
        case .general:
            return "gearshape"
        case .about:
            return "info.circle"
        }
    }
}

/// Parameter settings view
struct ParameterSettingsView: View {
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Inference Parameters")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Configure how the AI model generates responses. Changes apply immediately to new messages.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Parameter presets
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Presets")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ForEach(ParameterPreset.presets) { preset in
                            PresetCardView(preset: preset, parameterManager: parameterManager)
                        }
                    }
                }
                
                Divider()
                
                // Individual parameter controls
                VStack(alignment: .leading, spacing: 20) {
                    Text("Individual Parameters")
                        .font(.headline)
                    
                    // Temperature
                    ParameterDetailView(
                        title: "Temperature",
                        description: "Controls randomness in responses. Lower values make output more focused and deterministic, higher values make it more creative and varied.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.temperature) },
                            set: { parameterManager.updateTemperature(Float($0)) }
                        ),
                        range: Double(ParameterManager.temperatureRange.lowerBound)...Double(ParameterManager.temperatureRange.upperBound),
                        step: 0.1,
                        format: "%.1f",
                        validationStatus: parameterManager.getValidationStatus(for: .temperature)
                    )
                    
                    // Max Tokens
                    ParameterDetailView(
                        title: "Max Tokens",
                        description: "Maximum number of tokens (words/word pieces) the model can generate in a single response.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.maxTokens) },
                            set: { parameterManager.updateMaxTokens(Int($0)) }
                        ),
                        range: Double(ParameterManager.maxTokensRange.lowerBound)...Double(ParameterManager.maxTokensRange.upperBound),
                        step: 1,
                        format: "%.0f",
                        validationStatus: parameterManager.getValidationStatus(for: .maxTokens)
                    )
                    
                    // Top-P
                    ParameterDetailView(
                        title: "Top-P (Nucleus Sampling)",
                        description: "Limits token selection to the most probable tokens whose cumulative probability is below this threshold.",
                        value: Binding(
                            get: { Double(parameterManager.parameters.topP) },
                            set: { parameterManager.updateTopP(Float($0)) }
                        ),
                        range: Double(ParameterManager.topPRange.lowerBound)...Double(ParameterManager.topPRange.upperBound),
                        step: 0.05,
                        format: "%.2f",
                        validationStatus: parameterManager.getValidationStatus(for: .topP)
                    )
                }
                
                Divider()
                
                // System prompt section
                VStack(alignment: .leading, spacing: 12) {
                    Text("System Prompt")
                        .font(.headline)
                    
                    Text("The system prompt defines how the AI should behave and respond. It's sent with every message.")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    SystemPromptSettingsView(parameterManager: parameterManager)
                }
                
                // Validation errors
                if parameterManager.hasValidationErrors {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Parameter Validation Issues", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ForEach(parameterManager.validationErrors, id: \.self) { error in
                            Text("• \(error)")
                                .font(.body)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Reset button
                HStack {
                    Spacer()
                    
                    Button("Reset to Defaults") {
                        parameterManager.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
    }
}

/// Preset card view
struct PresetCardView: View {
    let preset: ParameterPreset
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(preset.name)
                .font(.system(size: 14, weight: .medium))
            
            Text(preset.description)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Temp: \(preset.parameters.temperature, specifier: "%.1f"), Tokens: \(preset.parameters.maxTokens)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Apply") {
                parameterManager.loadPreset(preset)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(12)
        .frame(height: 120)
        .background(isCurrentPreset ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isCurrentPreset ? Color.accentColor : Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
    
    private var isCurrentPreset: Bool {
        return parameterManager.parameters.temperature == preset.parameters.temperature &&
               parameterManager.parameters.maxTokens == preset.parameters.maxTokens &&
               parameterManager.parameters.topP == preset.parameters.topP
    }
}

/// Detailed parameter control view
struct ParameterDetailView: View {
    let title: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let validationStatus: ValidationStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                
                if validationStatus == .invalid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                }
                
                Spacer()
                
                Text(String(format: format, value))
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(validationStatus == .invalid ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
            }
            
            Text(description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            
            HStack {
                Text(String(format: format, range.lowerBound))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Slider(value: $value, in: range, step: step)
                    .accentColor(validationStatus == .invalid ? .orange : .accentColor)
                
                Text(String(format: format, range.upperBound))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// System prompt settings view
struct SystemPromptSettingsView: View {
    @ObservedObject var parameterManager: ParameterManager
    @State private var showingCustomEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current: \(parameterManager.selectedPresetName)")
                    .font(.system(size: 14, weight: .medium))
                
                Spacer()
                
                Button("Edit Custom...") {
                    showingCustomEditor = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            if !parameterManager.parameters.systemPrompt.isEmpty {
                Text(parameterManager.parameters.systemPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .lineLimit(5)
            } else {
                Text("No system prompt set")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .sheet(isPresented: $showingCustomEditor) {
            CustomPromptEditorSheet(
                promptText: .constant(parameterManager.parameters.systemPrompt),
                onSave: { prompt in
                    parameterManager.updateSystemPrompt(prompt)
                }
            )
        }
    }
}

/// Placeholder settings views
struct PrivacySettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Privacy settings will be implemented in a future version.")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct APISettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("API Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("API settings will be implemented in a future version.")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General Settings")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("General settings will be implemented in a future version.")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About ManyLLM")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("About information will be implemented in a future version.")
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView(parameterManager: ParameterManager())
}