import SwiftUI

/// Bottom input area for typing messages and configuring system prompts
struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var isProcessing: Bool
    @ObservedObject var parameterManager: ParameterManager
    
    let onSendMessage: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // System Prompt Dropdown
            HStack {
                Text("System Prompt:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                SystemPromptDropdownView(parameterManager: parameterManager)
                
                Spacer()
            }
            
            // Message Input Field with Send Button
            HStack(alignment: .bottom, spacing: 8) {
                // Text input field
                ZStack(alignment: .topLeading) {
                    // Background
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    isTextFieldFocused ? Color.accentColor : Color(NSColor.separatorColor),
                                    lineWidth: isTextFieldFocused ? 2 : 1
                                )
                        )
                    
                    // Text editor
                    TextEditor(text: $messageText)
                        .font(.system(size: 14))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                onSendMessage()
                            }
                        }
                    
                    // Placeholder text
                    if messageText.isEmpty {
                        Text("Type your message here...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 44, maxHeight: 120)
                
                // Send button
                Button(action: onSendMessage) {
                    Image(systemName: isProcessing ? "stop.circle.fill" : "paperplane.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .background(sendButtonBackground)
                .cornerRadius(12)
                .disabled(shouldDisableSendButton)
                .animation(.easeInOut(duration: 0.2), value: isProcessing)
            }
            
            // Input hints
            if messageText.isEmpty && !isProcessing {
                HStack(spacing: 16) {
                    InputHint(icon: "command", text: "⌘ + Enter to send")
                    InputHint(icon: "doc.text", text: "Drag files to add context")
                    InputHint(icon: "gear", text: "Adjust parameters above")
                }
                .opacity(0.7)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(NSColor.separatorColor)),
            alignment: .top
        )
        .onAppear {
            // Focus the text field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var sendButtonBackground: some View {
        Group {
            if isProcessing {
                Color.red
            } else if shouldDisableSendButton {
                Color.secondary.opacity(0.3)
            } else {
                Color.accentColor
            }
        }
    }
    
    private var shouldDisableSendButton: Bool {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing
    }
}

/// Small hint text with icon
struct InputHint: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    VStack {
        Spacer()
        
        ChatInputView(
            messageText: .constant(""),
            isProcessing: .constant(false),
            parameterManager: ParameterManager(),
            onSendMessage: {}
        )
    }
    .frame(width: 600, height: 300)
}