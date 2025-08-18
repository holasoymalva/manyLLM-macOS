import SwiftUI
import UniformTypeIdentifiers

/// Enhanced Files section view with drag-and-drop support and document management
struct FilesView: View {
    @ObservedObject var documentManager: DocumentManager
    @Binding var isExpanded: Bool
    
    @State private var isDragOver = false
    @State private var showingFilePicker = false
    @State private var showingDocumentDetails: ProcessedDocument?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            FilesHeaderView(
                isExpanded: $isExpanded,
                contextSummary: documentManager.contextSummary,
                onAddFiles: { showingFilePicker = true },
                onClearAll: { documentManager.removeAllDocuments() },
                hasDocuments: !documentManager.documents.isEmpty
            )
            
            if isExpanded {
                // Processing status
                if documentManager.isProcessing {
                    ProcessingStatusView(
                        status: documentManager.processingStatus,
                        progress: documentManager.processingProgress,
                        onCancel: {
                            Task {
                                await documentManager.cancelProcessing()
                            }
                        }
                    )
                }
                
                // Document list or empty state
                if documentManager.documents.isEmpty && !documentManager.isProcessing {
                    EmptyFilesView(
                        supportedExtensions: documentManager.supportedExtensions,
                        onAddFiles: { showingFilePicker = true }
                    )
                } else {
                    DocumentListView(
                        documents: documentManager.documents,
                        onToggleActive: documentManager.toggleDocumentActive,
                        onRemove: documentManager.removeDocument,
                        onShowDetails: { document in
                            showingDocumentDetails = document
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .background(
            // Drag and drop background
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isDragOver ? Color.accentColor : Color.clear,
                            lineWidth: 2
                        )
                        .animation(.easeInOut(duration: 0.2), value: isDragOver)
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragOver) { providers in
            Task {
                await documentManager.handleDroppedFiles(providers)
            }
            return true
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [
                .pdf,
                .plainText,
                .commaSeparatedText,
                UTType(filenameExtension: "docx") ?? .data,
                UTType(filenameExtension: "doc") ?? .data
            ],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                Task {
                    await documentManager.uploadDocuments(from: urls)
                }
            case .failure(let error):
                documentManager.errorMessage = error.localizedDescription
                documentManager.showingError = true
            }
        }
        .sheet(item: $showingDocumentDetails) { document in
            DocumentDetailSheet(document: document)
        }
        .alert("Document Processing Error", isPresented: $documentManager.showingError) {
            Button("OK") { }
        } message: {
            Text(documentManager.errorMessage ?? "An unknown error occurred")
        }
    }
}

/// Files section header with controls
struct FilesHeaderView: View {
    @Binding var isExpanded: Bool
    let contextSummary: String
    let onAddFiles: () -> Void
    let onClearAll: () -> Void
    let hasDocuments: Bool
    
    var body: some View {
        HStack {
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Text("Files")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(contextSummary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            // Add files button
            Menu {
                Button("Add Files...") {
                    onAddFiles()
                }
                
                if hasDocuments {
                    Divider()
                    
                    Button("Clear All") {
                        onClearAll()
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Processing status indicator
struct ProcessingStatusView: View {
    let status: String
    let progress: Double
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                ProgressView()
                    .scaleEffect(0.7)
                
                Text(status)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10))
                .foregroundColor(.red)
            }
            
            if progress > 0 {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}

/// Empty state view for files section
struct EmptyFilesView: View {
    let supportedExtensions: [String]
    let onAddFiles: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.below.ecg")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No documents")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Drag files here or click + to add")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Text("Supports: \(supportedExtensions.map { $0.uppercased() }.joined(separator: ", "))")
                .font(.system(size: 10))
                .foregroundColor(.secondary.opacity(0.8))
                .multilineTextAlignment(.center)
            
            Button("Add Files") {
                onAddFiles()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
}

/// List of documents
struct DocumentListView: View {
    let documents: [ProcessedDocument]
    let onToggleActive: (ProcessedDocument) -> Void
    let onRemove: (ProcessedDocument) -> Void
    let onShowDetails: (ProcessedDocument) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(documents) { document in
                DocumentItemView(
                    document: document,
                    onToggleActive: { onToggleActive(document) },
                    onRemove: { onRemove(document) },
                    onShowDetails: { onShowDetails(document) }
                )
            }
        }
        .padding(.horizontal, 8)
    }
}

/// Individual document item view
struct DocumentItemView: View {
    let document: ProcessedDocument
    let onToggleActive: () -> Void
    let onRemove: () -> Void
    let onShowDetails: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileIcon(for: document.filename))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            // File info
            VStack(alignment: .leading, spacing: 1) {
                Text(document.filename)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(document.fileSizeString)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    
                    if document.isChunked {
                        Text("•")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        
                        Text("\(document.chunkCount) chunks")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Context indicator and controls
            HStack(spacing: 6) {
                // Context eye icon
                Button(action: onToggleActive) {
                    Image(systemName: document.isActive ? "eye.fill" : "eye.slash")
                        .font(.system(size: 10))
                        .foregroundColor(document.isActive ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(document.isActive ? "Remove from context" : "Add to context")
                
                // More options (shown on hover)
                if isHovered {
                    Menu {
                        Button("View Details") {
                            onShowDetails()
                        }
                        
                        Button(document.isActive ? "Remove from Context" : "Add to Context") {
                            onToggleActive()
                        }
                        
                        Divider()
                        
                        Button("Remove") {
                            onRemove()
                        }
                        .foregroundColor(.red)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .menuStyle(.borderlessButton)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(document.isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onToggleActive()
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

/// Document detail sheet
struct DocumentDetailSheet: View {
    let document: ProcessedDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: fileIcon(for: document.filename))
                                .font(.system(size: 24))
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(document.filename)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                
                                Text(document.fileSizeString)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        if let title = document.metadata.title, title != document.filename {
                            Text(title)
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Document Information")
                            .font(.headline)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible(minimum: 100), alignment: .leading),
                            GridItem(.flexible(minimum: 200), alignment: .leading)
                        ], spacing: 8) {
                            
                            MetadataRow(label: "File Size", value: document.fileSizeString)
                            MetadataRow(label: "Type", value: document.mimeType)
                            MetadataRow(label: "Characters", value: "\(document.characterCount)")
                            MetadataRow(label: "Words", value: "\(document.wordCount)")
                            
                            if document.isChunked {
                                MetadataRow(label: "Chunks", value: "\(document.chunkCount)")
                            }
                            
                            if let pageCount = document.metadata.pageCount {
                                MetadataRow(label: "Pages", value: "\(pageCount)")
                            }
                            
                            if let author = document.metadata.author {
                                MetadataRow(label: "Author", value: author)
                            }
                            
                            MetadataRow(label: "Processed", value: formatDate(document.processedAt))
                            MetadataRow(label: "Context", value: document.isActive ? "Active" : "Inactive")
                        }
                    }
                    
                    // Content preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content Preview")
                            .font(.headline)
                        
                        ScrollView {
                            Text(String(document.content.prefix(1000)) + (document.content.count > 1000 ? "..." : ""))
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 200)
                        .padding(8)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Document Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Metadata row component
struct MetadataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        Text(label)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        
        Text(value)
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    let documentManager = DocumentManager()
    documentManager.addMockDocuments()
    
    return FilesView(
        documentManager: documentManager,
        isExpanded: .constant(true)
    )
    .frame(width: 250)
}