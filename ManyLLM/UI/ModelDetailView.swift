import SwiftUI

/// Detailed view for a specific model with comprehensive information
struct ModelDetailView: View {
    let model: ModelInfo
    @ObservedObject var downloadManager: ModelDownloadManager
    @State private var compatibilityResult: ModelCompatibilityResult?
    @State private var isLoadingCompatibility = false
    @Environment(\.dismiss) private var dismiss
    
    private let compatibilityChecker = ModelCompatibilityChecker()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header section
                    ModelDetailHeader(model: model, downloadManager: downloadManager)
                    
                    Divider()
                    
                    // Basic information
                    ModelBasicInfoSection(model: model)
                    
                    Divider()
                    
                    // Compatibility section
                    ModelCompatibilitySection(
                        model: model,
                        compatibilityResult: compatibilityResult,
                        isLoading: isLoadingCompatibility
                    )
                    
                    Divider()
                    
                    // Technical specifications
                    ModelSpecificationsSection(model: model)
                    
                    Divider()
                    
                    // Tags and metadata
                    ModelMetadataSection(model: model)
                    
                    if model.isLocal {
                        Divider()
                        
                        // Local model actions
                        ModelLocalActionsSection(model: model)
                    }
                }
                .padding()
            }
            .navigationTitle(model.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadCompatibilityInfo()
        }
    }
    
    @MainActor
    private func loadCompatibilityInfo() async {
        isLoadingCompatibility = true
        
        // Simulate async compatibility check
        await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        compatibilityResult = compatibilityChecker.checkCompatibility(for: model)
        isLoadingCompatibility = false
    }
}

/// Header section with model name, author, and primary actions
struct ModelDetailHeader: View {
    let model: ModelInfo
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("by \(model.author)")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ModelStatusBadge(model: model, downloadManager: downloadManager)
            }
            
            Text(model.description)
                .font(.body)
                .foregroundColor(.primary)
            
            // Primary action buttons
            HStack(spacing: 12) {
                if let downloadProgress = downloadManager.getDownloadProgress(for: model.id) {
                    DownloadProgressView(
                        downloadProgress: downloadProgress,
                        onCancel: {
                            try? downloadManager.cancelDownload(modelId: model.id)
                        }
                    )
                } else if model.isLocal {
                    Button("Load Model") {
                        // Handle model loading
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoaded)
                    
                    Button("Delete") {
                        // Handle model deletion
                    }
                    .buttonStyle(.bordered)
                } else if model.canDownload {
                    Button("Download") {
                        Task {
                            try await downloadManager.downloadModel(model)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Spacer()
            }
        }
    }
}

/// Basic information section
struct ModelBasicInfoSection: View {
    let model: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Basic Information")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], alignment: .leading, spacing: 12) {
                InfoRow(label: "Parameters", value: model.parameters)
                InfoRow(label: "Size", value: model.sizeString)
                InfoRow(label: "Version", value: model.version ?? "Unknown")
                InfoRow(label: "License", value: model.license ?? "Unknown")
                
                if let createdAt = model.createdAt {
                    InfoRow(label: "Created", value: DateFormatter.shortDate.string(from: createdAt))
                }
                
                if let updatedAt = model.updatedAt {
                    InfoRow(label: "Updated", value: DateFormatter.shortDate.string(from: updatedAt))
                }
            }
        }
    }
}

/// Compatibility information section
struct ModelCompatibilitySection: View {
    let model: ModelInfo
    let compatibilityResult: ModelCompatibilityResult?
    let isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compatibility")
                .font(.headline)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Checking compatibility...")
                        .foregroundColor(.secondary)
                }
            } else if let result = compatibilityResult {
                VStack(alignment: .leading, spacing: 8) {
                    // Compatibility status
                    HStack {
                        Image(systemName: compatibilityIcon(for: result.compatibility))
                            .foregroundColor(compatibilityColor(for: result.compatibility))
                        
                        Text(result.compatibility.displayName)
                            .fontWeight(.medium)
                            .foregroundColor(compatibilityColor(for: result.compatibility))
                    }
                    
                    // Warnings
                    if result.hasWarnings {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Warnings:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.orange)
                            
                            ForEach(result.warnings, id: \.self) { warning in
                                HStack(alignment: .top) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                    
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Recommendations
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Recommendations:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                            
                            ForEach(result.recommendations, id: \.self) { recommendation in
                                HStack(alignment: .top) {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                    
                                    Text(recommendation)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func compatibilityIcon(for compatibility: ModelCompatibility) -> String {
        switch compatibility {
        case .fullyCompatible: return "checkmark.circle.fill"
        case .partiallyCompatible: return "exclamationmark.triangle.fill"
        case .incompatible: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    private func compatibilityColor(for compatibility: ModelCompatibility) -> Color {
        switch compatibility {
        case .fullyCompatible: return .green
        case .partiallyCompatible: return .orange
        case .incompatible: return .red
        case .unknown: return .gray
        }
    }
}

/// Technical specifications section
struct ModelSpecificationsSection: View {
    let model: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Requirements")
                .font(.headline)
            
            // This would be populated from compatibility check results
            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Memory Usage: \(estimatedMemoryUsage)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Recommended RAM: \(recommendedRAM)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Storage Required: \(model.sizeString)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var estimatedMemoryUsage: String {
        let estimatedBytes = model.size * 2 // 2x for loading overhead
        return ByteCountFormatter().string(fromByteCount: estimatedBytes)
    }
    
    private var recommendedRAM: String {
        let recommendedBytes = model.size * 3 // 3x for comfortable usage
        return ByteCountFormatter().string(fromByteCount: recommendedBytes)
    }
}

/// Metadata section with tags and additional information
struct ModelMetadataSection: View {
    let model: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags & Categories")
                .font(.headline)
            
            if !model.tags.isEmpty {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 100))
                ], spacing: 8) {
                    ForEach(model.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundColor(.accentColor)
                            .cornerRadius(6)
                    }
                }
            } else {
                Text("No tags available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Local model actions section
struct ModelLocalActionsSection: View {
    let model: ModelInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Model Actions")
                .font(.headline)
            
            VStack(spacing: 8) {
                if let localPath = model.localPath {
                    Button("Show in Finder") {
                        NSWorkspace.shared.selectFile(localPath.path, inFileViewerRootedAtPath: "")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Verify Integrity") {
                    // Handle integrity verification
                }
                .buttonStyle(.bordered)
                
                Button("Export Model Info") {
                    // Handle model info export
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

/// Reusable info row component
struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

// MARK: - Preview Support

#if DEBUG
struct ModelDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleModel = SampleModelProvider.sampleModels[0]
        let downloadManager = ModelDownloadManager(
            remoteRepository: try! RemoteModelRepository(localRepository: try! LocalModelRepository()),
            localRepository: try! LocalModelRepository()
        )
        
        ModelDetailView(model: sampleModel, downloadManager: downloadManager)
    }
}
#endif