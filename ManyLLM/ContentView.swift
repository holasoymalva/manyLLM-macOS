import SwiftUI

struct ContentView: View {
    @State private var sidebarCollapsed = false
    @State private var workspacesExpanded = true
    @State private var filesExpanded = true
    @State private var selectedModel = "Llama 3 8B Ollama"
    @State private var temperature: Double = 0.7
    @State private var maxTokens: Double = 600
    @State private var systemPrompt = "Default"
    @State private var messageText = ""
    
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            if !sidebarCollapsed {
                VStack(spacing: 0) {
                    // Workspaces Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: { workspacesExpanded.toggle() }) {
                                Image(systemName: workspacesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("Workspaces")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        
                        if workspacesExpanded {
                            VStack(alignment: .leading, spacing: 4) {
                                WorkspaceItem(name: "Current Chat", isSelected: true)
                                WorkspaceItem(name: "Research Project", isSelected: false)
                                WorkspaceItem(name: "Code Review", isSelected: false)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Files Section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button(action: { filesExpanded.toggle() }) {
                                Image(systemName: filesExpanded ? "chevron.down" : "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text("Files")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("2 of 3 files in context")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        
                        if filesExpanded {
                            VStack(alignment: .leading, spacing: 4) {
                                FileItem(name: "document.pdf", size: "2.3 MB", hasContext: true)
                                FileItem(name: "notes.txt", size: "45 KB", hasContext: true)
                                FileItem(name: "data.csv", size: "1.1 MB", hasContext: false)
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                    
                    Spacer()
                }
                .frame(width: 250)
                .background(Color(NSColor.controlBackgroundColor))
            }
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Toolbar
                HStack(spacing: 16) {
                    // ManyLLM Logo/Brand
                    HStack(spacing: 8) {
                        // Cat-bee logo placeholder (using SF Symbol for now)
                        Image(systemName: "pawprint.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.orange)
                        
                        Text("ManyLLM")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Model Dropdown
                    Menu {
                        Button("Llama 3 8B Ollama") { selectedModel = "Llama 3 8B Ollama" }
                        Button("GPT-4 Compatible") { selectedModel = "GPT-4 Compatible" }
                        Button("Browse Models...") { }
                    } label: {
                        HStack {
                            Text(selectedModel)
                                .font(.system(size: 13))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    
                    // Temperature Slider
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Temperature")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $temperature, in: 0...2.0, step: 0.1)
                                .frame(width: 80)
                            Text(String(format: "%.1f", temperature))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                    
                    // Max Tokens Slider
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Tokens")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        HStack {
                            Slider(value: $maxTokens, in: 1...2048, step: 1)
                                .frame(width: 80)
                            Text("\(Int(maxTokens))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    
                    // Settings Gear
                    Button(action: {}) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Start Button
                    Button("Start") {
                        // TODO: Implement start functionality
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(NSColor.separatorColor)),
                    alignment: .bottom
                )
                
                // Chat Area with Welcome State
                VStack(spacing: 16) {
                    Spacer()
                    
                    // ManyLLM Cat-bee Logo (larger version)
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.orange)
                    
                    Text("Welcome to ManyLLM Preview")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text("Your private, local AI assistant")
                        .font(.body)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
                
                // Bottom Input Area
                VStack(spacing: 12) {
                    // System Prompt Dropdown
                    HStack {
                        Text("System Prompt:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        
                        Menu {
                            Button("Default") { systemPrompt = "Default" }
                            Button("Creative Writing") { systemPrompt = "Creative Writing" }
                            Button("Code Assistant") { systemPrompt = "Code Assistant" }
                            Button("Research Helper") { systemPrompt = "Research Helper" }
                        } label: {
                            HStack {
                                Text(systemPrompt)
                                    .font(.system(size: 12))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8))
                            }
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    // Message Input Field
                    HStack(spacing: 8) {
                        TextField("Type your message here...", text: $messageText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                        
                        Button(action: {}) {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 32, height: 32)
                        .background(Color.accentColor)
                        .cornerRadius(8)
                        .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { sidebarCollapsed.toggle() }) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
// MARK: - Supporting Views

struct WorkspaceItem: View {
    let name: String
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Text(name)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? .primary : .secondary)
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Handle workspace selection
        }
    }
}

struct FileItem: View {
    let name: String
    let size: String
    let hasContext: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: fileIcon(for: name))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(size)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasContext {
                Image(systemName: "eye.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            // TODO: Handle file selection
        }
    }
    
    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "txt":
            return "doc.text"
        case "csv":
            return "tablecells"
        case "docx", "doc":
            return "doc"
        default:
            return "doc"
        }
    }
}