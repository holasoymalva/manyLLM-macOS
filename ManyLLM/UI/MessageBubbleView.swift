import SwiftUI

/// Message bubble view that displays individual chat messages
struct MessageBubbleView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.role == .user {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                // Message content bubble
                MessageContentView(message: message)
                
                // Message metadata (timestamp, model info, etc.)
                MessageMetadataView(message: message)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

/// The main content bubble for a message
struct MessageContentView: View {
    let message: ChatMessage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Document references (if any)
            if message.hasDocumentReferences {
                DocumentReferencesView(references: message.metadata?.documentReferences ?? [])
            }
            
            // Message text
            Text(message.content)
                .font(.system(size: 14, design: .default))
                .foregroundColor(message.role == .user ? .white : .primary)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(bubbleBackground)
        .cornerRadius(16, corners: bubbleCorners)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var bubbleBackground: some View {
        Group {
            if message.role == .user {
                Color.accentColor
            } else {
                Color(NSColor.controlBackgroundColor)
            }
        }
    }
    
    private var bubbleCorners: RectCorner {
        switch message.role {
        case .user:
            return [.topLeft, .topRight, .bottomLeft]
        case .assistant:
            return [.topLeft, .topRight, .bottomRight]
        case .system:
            return .allCorners
        }
    }
}

/// View showing document references within a message
struct DocumentReferencesView: View {
    let references: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                Text("Referenced documents:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                ForEach(references, id: \.self) { reference in
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        
                        Text(reference)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}

/// Metadata view showing timestamp and other message info
struct MessageMetadataView: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(spacing: 8) {
            // Role indicator
            Text(message.role.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            // Timestamp
            Text(message.formattedTimestamp)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Model info (for assistant messages)
            if message.role == .assistant, let modelUsed = message.metadata?.modelUsed {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(modelUsed)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Inference time (for assistant messages)
            if message.role == .assistant, let inferenceTime = message.metadata?.inferenceTime {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text(String(format: "%.1fs", inferenceTime))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            // Token count (for assistant messages)
            if message.role == .assistant, let tokenCount = message.metadata?.tokenCount {
                Text("•")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Text("\(tokenCount) tokens")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Custom corner specification for SwiftUI
struct RectCorner: OptionSet {
    let rawValue: Int
    
    static let topLeft = RectCorner(rawValue: 1 << 0)
    static let topRight = RectCorner(rawValue: 1 << 1)
    static let bottomLeft = RectCorner(rawValue: 1 << 2)
    static let bottomRight = RectCorner(rawValue: 1 << 3)
    
    static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}

/// Extension to support custom corner radius
extension View {
    func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

/// Custom shape for rounded corners
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        
        // Top edge and top-right corner
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                       radius: topRight,
                       startAngle: Angle(degrees: -90),
                       endAngle: Angle(degrees: 0),
                       clockwise: false)
        }
        
        // Right edge and bottom-right corner
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                       radius: bottomRight,
                       startAngle: Angle(degrees: 0),
                       endAngle: Angle(degrees: 90),
                       clockwise: false)
        }
        
        // Bottom edge and bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                       radius: bottomLeft,
                       startAngle: Angle(degrees: 90),
                       endAngle: Angle(degrees: 180),
                       clockwise: false)
        }
        
        // Left edge and top-left corner
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                       radius: topLeft,
                       startAngle: Angle(degrees: 180),
                       endAngle: Angle(degrees: 270),
                       clockwise: false)
        }
        
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: 16) {
        // User message
        MessageBubbleView(
            message: ChatMessage(
                content: "Hello! Can you help me understand this document?",
                role: .user,
                metadata: MessageMetadata(documentReferences: ["document.pdf"])
            )
        )
        
        // Assistant message
        MessageBubbleView(
            message: ChatMessage(
                content: "Of course! I'd be happy to help you understand the document. Based on the content you've shared, I can see that it covers several important topics. Let me break down the key points for you.",
                role: .assistant,
                metadata: MessageMetadata(
                    modelUsed: "Llama 3 8B",
                    inferenceTime: 2.3,
                    tokenCount: 67,
                    documentReferences: ["document.pdf"]
                )
            )
        )
    }
    .padding()
    .frame(width: 500)
}