import SwiftUI

/// System prompt dropdown for the bottom input area
struct SystemPromptDropdownView: View {
    @ObservedObject var parameterManager: ParameterManager
    @State private var showingCustomPromptEditor = false
    @State private var customPromptText = ""
    
    var body: some View {
        Menu {
            // Preset options
            Section("Presets") {
                ForEach(ParameterManager.systemPromptPresets) { preset in
                    Button(action: {
                        parameterManager.selectSystemPromptPreset(preset.name)
                    }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.system(size: 13))
                                
                                Text(preset.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if parameterManager.selectedPresetName == preset.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Custom prompt option
            Button("Custom Prompt...") {
                customPromptText = parameterManager.parameters.systemPrompt
                showingCustomPromptEditor = true
            }
            
            // Clear prompt option
            if !parameterManager.parameters.systemPrompt.isEmpty {
                Button("Clear Prompt") {
                    parameterManager.selectSystemPromptPreset("Default")
                }
            }
            
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Text(displayText)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .help(tooltipText)
        .sheet(isPresented: $showingCustomPromptEditor) {
            CustomPromptEditorSheet(
                promptText: $customPromptText,
                onSave: { prompt in
                    parameterManager.updateSystemPrompt(prompt)
                }
            )
        }
    }
    
    private var displayText: String {
        if parameterManager.selectedPresetName == "Custom" {
            return "Custom"
        } else if parameterManager.selectedPresetName == "Default" {
            return "System Prompt"
        } else {
            return parameterManager.selectedPresetName
        }
    }
    
    private var tooltipText: String {
        if parameterManager.parameters.systemPrompt.isEmpty {
            return "No system prompt set"
        } else if parameterManager.selectedPresetName == "Custom" {
            return "Custom system prompt: \(String(parameterManager.parameters.systemPrompt.prefix(100)))"
        } else {
            return ParameterManager.systemPromptPresets.first { $0.name == parameterManager.selectedPresetName }?.description ?? ""
        }
    }
}

/// Custom prompt editor sheet
struct CustomPromptEditorSheet: View {
    @Binding var promptText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingText: String = ""
    @State private var characterCount: Int = 0
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom System Prompt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Define how the AI should behave and respond. This prompt will be sent with every message.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Prompt Text")
                            .font(.headline)
                        
                        Spacer()
                        
                        Text("\(characterCount) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    TextEditor(text: $editingText)
                        .font(.system(size: 14, design: .default))
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                        .frame(minHeight: 200)
                        .onChange(of: editingText) { newValue in
                            characterCount = newValue.count
                        }
                }
                
                // Example prompts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Example Prompts")
                        .font(.headline)
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(ParameterManager.systemPromptPresets.filter { !$0.prompt.isEmpty }) { preset in
                                ExamplePromptView(preset: preset) {
                                    editingText = preset.prompt
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("System Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editingText)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            editingText = promptText
            characterCount = promptText.count
        }
    }
}

/// Example prompt view for the editor
struct ExamplePromptView: View {
    let preset: SystemPromptPreset
    let onUse: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(preset.name)
                    .font(.system(size: 13, weight: .medium))
                
                Spacer()
                
                Button("Use") {
                    onUse()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
            }
            
            Text(preset.description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            Text(preset.prompt)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        SystemPromptDropdownView(parameterManager: ParameterManager())
        
        Divider()
        
        // Preview of the custom editor
        CustomPromptEditorSheet(
            promptText: .constant("You are a helpful assistant."),
            onSave: { _ in }
        )
    }
    .padding()
}