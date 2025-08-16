import SwiftUI

struct ContentView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Left Sidebar
            VStack {
                Text("Sidebar")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(width: 250)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main Content Area
            VStack(spacing: 0) {
                // Top Toolbar
                HStack {
                    Text("ManyLLM")
                        .font(.headline)
                    Spacer()
                    Text("Toolbar")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.windowBackgroundColor))
                
                // Chat Area
                VStack {
                    Spacer()
                    Text("Welcome to ManyLLM")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Bottom Input Area
                HStack {
                    TextField("Type your message...", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button("Send") {
                        // TODO: Implement send functionality
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

#Preview {
    ContentView()
}