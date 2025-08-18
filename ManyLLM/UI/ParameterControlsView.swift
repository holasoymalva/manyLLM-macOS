import SwiftUI

/// Enhanced parameter controls for the top toolbar with validation feedback
struct ParameterControlsView: View {
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Temperature Slider
            ParameterSliderView(
                title: "Temperature",
                value: Binding(
                    get: { Double(parameterManager.parameters.temperature) },
                    set: { parameterManager.updateTemperature(Float($0)) }
                ),
                range: Double(ParameterManager.temperatureRange.lowerBound)...Double(ParameterManager.temperatureRange.upperBound),
                step: 0.1,
                format: "%.1f",
                validationStatus: parameterManager.getValidationStatus(for: .temperature),
                width: 80
            )
            
            // Max Tokens Slider
            ParameterSliderView(
                title: "Max Tokens",
                value: Binding(
                    get: { Double(parameterManager.parameters.maxTokens) },
                    set: { parameterManager.updateMaxTokens(Int($0)) }
                ),
                range: Double(ParameterManager.maxTokensRange.lowerBound)...Double(ParameterManager.maxTokensRange.upperBound),
                step: 1,
                format: "%.0f",
                validationStatus: parameterManager.getValidationStatus(for: .maxTokens),
                width: 80
            )
            
            // Top-P Slider (Advanced parameter, shown in compact form)
            ParameterSliderView(
                title: "Top-P",
                value: Binding(
                    get: { Double(parameterManager.parameters.topP) },
                    set: { parameterManager.updateTopP(Float($0)) }
                ),
                range: Double(ParameterManager.topPRange.lowerBound)...Double(ParameterManager.topPRange.upperBound),
                step: 0.05,
                format: "%.2f",
                validationStatus: parameterManager.getValidationStatus(for: .topP),
                width: 70
            )
        }
    }
}

/// Individual parameter slider with validation feedback
struct ParameterSliderView: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String
    let validationStatus: ValidationStatus
    let width: CGFloat
    
    @State private var isEditing = false
    @State private var showingTooltip = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Title with validation indicator
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if validationStatus == .invalid {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
            
            // Slider and value display
            HStack(spacing: 8) {
                Slider(value: $value, in: range, step: step) { editing in
                    isEditing = editing
                }
                .frame(width: width)
                .accentColor(sliderColor)
                
                // Value display with validation styling
                Text(String(format: format, value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(valueColor)
                    .frame(width: valueWidth, alignment: .trailing)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(valueBackgroundColor)
                    .cornerRadius(4)
            }
        }
        .onHover { hovering in
            showingTooltip = hovering
        }
        .help(tooltipText)
    }
    
    private var sliderColor: Color {
        switch validationStatus {
        case .valid:
            return .accentColor
        case .invalid:
            return .orange
        case .warning:
            return .yellow
        }
    }
    
    private var valueColor: Color {
        switch validationStatus {
        case .valid:
            return .secondary
        case .invalid:
            return .orange
        case .warning:
            return .yellow
        }
    }
    
    private var valueBackgroundColor: Color {
        if isEditing {
            return Color.accentColor.opacity(0.1)
        } else if validationStatus == .invalid {
            return Color.orange.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var valueWidth: CGFloat {
        switch title {
        case "Temperature", "Top-P":
            return 35
        case "Max Tokens":
            return 45
        default:
            return 40
        }
    }
    
    private var tooltipText: String {
        switch title {
        case "Temperature":
            return "Controls randomness (0.0 = deterministic, 2.0 = very creative)"
        case "Max Tokens":
            return "Maximum number of tokens to generate"
        case "Top-P":
            return "Nucleus sampling threshold (0.0 = most likely tokens only)"
        default:
            return ""
        }
    }
}

/// Quick parameter preset buttons
struct ParameterPresetsView: View {
    @ObservedObject var parameterManager: ParameterManager
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Presets:")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            ForEach(ParameterPreset.presets) { preset in
                Button(preset.name) {
                    parameterManager.loadPreset(preset)
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isCurrentPreset(preset) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
                .foregroundColor(isCurrentPreset(preset) ? .accentColor : .secondary)
                .help(preset.description)
            }
        }
    }
    
    private func isCurrentPreset(_ preset: ParameterPreset) -> Bool {
        return parameterManager.parameters.temperature == preset.parameters.temperature &&
               parameterManager.parameters.maxTokens == preset.parameters.maxTokens &&
               parameterManager.parameters.topP == preset.parameters.topP
    }
}

#Preview {
    VStack(spacing: 20) {
        ParameterControlsView(parameterManager: ParameterManager())
        
        Divider()
        
        ParameterPresetsView(parameterManager: ParameterManager())
    }
    .padding()
}