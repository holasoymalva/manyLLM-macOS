import SwiftUI
import os.log

/// Test view for verifying MLX integration
@available(macOS 13.0, *)
struct MLXTestView: View {
    
    @StateObject private var engineManager = InferenceEngineManager()
    @StateObject private var chatManager = ChatManager()
    @State private var verificationResults: VerificationResults?
    @State private var isRunningVerification = false
    @State private var showingResults = false
    @State private var testOutput = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text("MLX Integration Test")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Verify that MLX inference engine integration is working correctly")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // System Information
            GroupBox("System Information") {
                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "MLX Available", value: MLXInferenceEngine.isAvailable() ? "Yes" : "No")
                    InfoRow(label: "macOS Version", value: ProcessInfo.processInfo.operatingSystemVersionString)
                    InfoRow(label: "Available Engines", value: "\(engineManager.availableEngines.count)")
                    InfoRow(label: "Current Engine", value: engineManager.currentEngine?.engineName ?? "None")
                }
            }
            
            // Available Engines
            GroupBox("Available Engines") {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(engineManager.availableEngines) { engine in
                        HStack {
                            Image(systemName: engine.isAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(engine.isAvailable ? .green : .red)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(engine.name)
                                    .font(.body)
                                    .fontWeight(.medium)
                                
                                Text(engine.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if engine.isAvailable {
                                Button("Switch") {
                                    Task {
                                        try? await engineManager.switchToEngine(engine.type)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            
            // Test Controls
            VStack(spacing: 12) {
                Button(action: runVerification) {
                    HStack {
                        if isRunningVerification {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "play.circle.fill")
                        }
                        
                        Text(isRunningVerification ? "Running Verification..." : "Run Integration Verification")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningVerification)
                
                if let results = verificationResults {
                    HStack(spacing: 16) {
                        Button("Show Results") {
                            showingResults = true
                        }
                        .buttonStyle(.bordered)
                        
                        Text(await results.summary)
                            .font(.body)
                            .foregroundColor(await results.allPassed ? .green : .red)
                    }
                }
            }
            
            // Test Output
            if !testOutput.isEmpty {
                GroupBox("Test Output") {
                    ScrollView {
                        Text(testOutput)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 200)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 700)
        .sheet(isPresented: $showingResults) {
            if let results = verificationResults {
                VerificationResultsView(results: results)
            }
        }
    }
    
    private func runVerification() {
        isRunningVerification = true
        testOutput = ""
        
        Task {
            let verification = MLXIntegrationVerification()
            let results = await verification.runVerification()
            
            await MainActor.run {
                self.verificationResults = results
                self.isRunningVerification = false
                self.testOutput = await results.detailedReport()
            }
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

struct VerificationResultsView: View {
    let results: VerificationResults
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // Summary
                VStack(spacing: 8) {
                    Text(await results.summary)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(await results.allPassed ? .green : .red)
                    
                    Text("\(await results.failedCount) failed, \(await results.passedCount) passed")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                
                // Detailed Results
                ScrollView {
                    Text(await results.detailedReport())
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
            }
            .padding()
            .navigationTitle("Verification Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Preview

#Preview {
    if #available(macOS 13.0, *) {
        MLXTestView()
    } else {
        Text("MLX Test View requires macOS 13.0+")
    }
}