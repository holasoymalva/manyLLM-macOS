import SwiftUI

/// Test view to demonstrate MockInferenceEngine functionality
struct MockEngineTestView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Mock Inference Engine Test")
                .font(.title)
                .fontWeight(.bold)
            
            // Test Controls
            HStack(spacing: 16) {
                Button("Run Basic Tests") {
                    runBasicTests()
                }
                .disabled(isRunningTests)
                
                Button("Test Streaming") {
                    testStreaming()
                }
                .disabled(isRunningTests)
                
                Button("Test Error Handling") {
                    testErrorHandling()
                }
                .disabled(isRunningTests)
                
                Button("Clear Results") {
                    testResults.removeAll()
                }
            }
            
            // Test Results
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(testResults.enumerated()), id: \.offset) { index, result in
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                            
                            Text(result)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 300)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            
            // Live Chat Test
            Divider()
            
            Text("Live Chat Test")
                .font(.headline)
            
            ChatView()
                .frame(height: 400)
                .border(Color.secondary.opacity(0.3))
        }
        .padding()
        .frame(minWidth: 800, minHeight: 800)
    }
    
    private func runBasicTests() {
        isRunningTests = true
        testResults.removeAll()
        
        Task {
            await performBasicTests()
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    private func testStreaming() {
        isRunningTests = true
        
        Task {
            await performStreamingTest()
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    private func testErrorHandling() {
        isRunningTests = true
        
        Task {
            await performErrorTest()
            await MainActor.run {
                isRunningTests = false
            }
        }
    }
    
    @MainActor
    private func addResult(_ result: String) {
        testResults.append(result)
    }
    
    private func performBasicTests() async {
        guard let mockEngine = chatManager.currentInferenceEngine as? MockInferenceEngine else {
            await addResult("❌ Failed to get mock engine")
            return
        }
        
        await addResult("✅ Mock engine initialized")
        await addResult("📊 Engine ready: \(mockEngine.isReady)")
        await addResult("🔧 Supports streaming: \(mockEngine.capabilities.supportsStreaming)")
        
        // Test basic response
        do {
            let parameters = InferenceParameters(temperature: 0.7, maxTokens: 50)
            let response = try await mockEngine.generateResponse(
                prompt: "Hello, this is a test",
                parameters: parameters,
                context: nil
            )
            
            await addResult("✅ Basic response generated")
            await addResult("📝 Response length: \(response.content.count) chars")
            await addResult("⏱️ Inference time: \(String(format: "%.2f", response.inferenceTime))s")
            await addResult("🔢 Token count: \(response.tokenCount ?? 0)")
            
        } catch {
            await addResult("❌ Basic response failed: \(error.localizedDescription)")
        }
        
        // Test predefined response
        mockEngine.setPredefinedResponse(for: "test", response: "This is a predefined response")
        
        do {
            let parameters = InferenceParameters()
            let response = try await mockEngine.generateResponse(
                prompt: "test",
                parameters: parameters,
                context: nil
            )
            
            if response.content == "This is a predefined response" {
                await addResult("✅ Predefined response works")
            } else {
                await addResult("❌ Predefined response failed")
            }
            
        } catch {
            await addResult("❌ Predefined response test failed: \(error.localizedDescription)")
        }
    }
    
    private func performStreamingTest() async {
        guard let mockEngine = chatManager.currentInferenceEngine as? MockInferenceEngine else {
            await addResult("❌ Failed to get mock engine")
            return
        }
        
        await addResult("🔄 Testing streaming response...")
        
        // Configure faster streaming for testing
        mockEngine.streamingTokenDelay = 0.01
        
        do {
            let parameters = InferenceParameters(temperature: 0.7, maxTokens: 30)
            let stream = try await mockEngine.generateStreamingResponse(
                prompt: "Tell me a short story",
                parameters: parameters,
                context: nil
            )
            
            var tokenCount = 0
            var fullResponse = ""
            
            for try await token in stream {
                tokenCount += 1
                fullResponse += token
            }
            
            await addResult("✅ Streaming completed")
            await addResult("🔢 Received \(tokenCount) tokens")
            await addResult("📝 Full response: \(fullResponse.prefix(100))...")
            
        } catch {
            await addResult("❌ Streaming test failed: \(error.localizedDescription)")
        }
    }
    
    private func performErrorTest() async {
        guard let mockEngine = chatManager.currentInferenceEngine as? MockInferenceEngine else {
            await addResult("❌ Failed to get mock engine")
            return
        }
        
        await addResult("⚠️ Testing error simulation...")
        
        // Enable error simulation
        mockEngine.shouldSimulateErrors = true
        mockEngine.errorProbability = 1.0
        
        do {
            let parameters = InferenceParameters()
            _ = try await mockEngine.generateResponse(
                prompt: "This should error",
                parameters: parameters,
                context: nil
            )
            
            await addResult("❌ Error simulation failed - no error thrown")
            
        } catch {
            await addResult("✅ Error simulation works")
            await addResult("📋 Error message: \(error.localizedDescription)")
        }
        
        // Disable error simulation
        mockEngine.shouldSimulateErrors = false
        await addResult("🔧 Error simulation disabled")
    }
}

#Preview {
    MockEngineTestView()
}