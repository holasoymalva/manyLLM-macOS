import SwiftUI

/// View for displaying download progress with controls
struct DownloadProgressView: View {
    @ObservedObject var downloadProgress: DownloadProgress
    let onCancel: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Model name and status
            HStack {
                Text(downloadProgress.modelName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                StatusBadge(status: downloadProgress.status)
            }
            
            // Progress bar
            ProgressView(value: downloadProgress.progress)
                .progressViewStyle(LinearProgressViewStyle())
            
            // Progress details
            HStack {
                Text("\(Int(downloadProgress.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if downloadProgress.status == .downloading {
                    HStack(spacing: 4) {
                        if downloadProgress.downloadSpeed > 0 {
                            Text(downloadProgress.downloadSpeedString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let eta = downloadProgress.etaString {
                            Text("• \(eta) remaining")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Model size and controls
            HStack {
                Text(downloadProgress.modelSizeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if downloadProgress.status.isActive {
                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            
            // Error message if failed
            if downloadProgress.status == .failed, let error = downloadProgress.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

/// Status badge for download status
struct StatusBadge: View {
    let status: DownloadStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .pending:
            return Color.orange.opacity(0.2)
        case .downloading:
            return Color.blue.opacity(0.2)
        case .completed:
            return Color.green.opacity(0.2)
        case .failed:
            return Color.red.opacity(0.2)
        case .cancelled:
            return Color.gray.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch status {
        case .pending:
            return Color.orange
        case .downloading:
            return Color.blue
        case .completed:
            return Color.green
        case .failed:
            return Color.red
        case .cancelled:
            return Color.gray
        }
    }
}

/// Compact download progress indicator for toolbar/status areas
struct CompactDownloadIndicator: View {
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        HStack(spacing: 4) {
            if !downloadManager.activeDownloads.isEmpty {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.small)
                
                Text("\(downloadManager.activeDownloads.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .animation(.easeInOut, value: downloadManager.activeDownloads.count)
    }
}

/// Download history view
struct DownloadHistoryView: View {
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Download History")
                    .font(.headline)
                
                Spacer()
                
                if !downloadManager.downloadHistory.isEmpty {
                    Button("Clear History") {
                        downloadManager.clearDownloadHistory()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.secondary)
                }
            }
            
            if downloadManager.downloadHistory.isEmpty {
                Text("No download history")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(downloadManager.downloadHistory.reversed()) { record in
                        DownloadHistoryRow(record: record) {
                            Task {
                                try? await downloadManager.retryDownload(modelId: record.modelId)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

/// Individual download history row
struct DownloadHistoryRow: View {
    let record: DownloadRecord
    let onRetry: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.modelName)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    StatusBadge(status: record.status)
                    
                    if let duration = record.durationString {
                        Text(duration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(ByteCountFormatter().string(fromByteCount: record.modelSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if record.status == .failed {
                Button("Retry") {
                    onRetry()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.blue)
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}

/// Download statistics view
struct DownloadStatisticsView: View {
    let statistics: DownloadStatistics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Download Statistics")
                .font(.headline)
            
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Total Downloads:")
                        .foregroundColor(.secondary)
                    Text("\(statistics.totalDownloads)")
                }
                
                GridRow {
                    Text("Successful:")
                        .foregroundColor(.secondary)
                    Text("\(statistics.successfulDownloads)")
                        .foregroundColor(.green)
                }
                
                GridRow {
                    Text("Failed:")
                        .foregroundColor(.secondary)
                    Text("\(statistics.failedDownloads)")
                        .foregroundColor(.red)
                }
                
                GridRow {
                    Text("Active:")
                        .foregroundColor(.secondary)
                    Text("\(statistics.activeDownloads)")
                        .foregroundColor(.blue)
                }
                
                GridRow {
                    Text("Success Rate:")
                        .foregroundColor(.secondary)
                    Text("\(Int(statistics.successRate * 100))%")
                        .foregroundColor(statistics.successRate > 0.8 ? .green : .orange)
                }
                
                GridRow {
                    Text("Total Downloaded:")
                        .foregroundColor(.secondary)
                    Text(statistics.totalBytesDownloadedString)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview Support

#if DEBUG
struct DownloadProgressView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Active download
            DownloadProgressView(
                downloadProgress: {
                    let progress = DownloadProgress(
                        modelId: "test-1",
                        modelName: "Llama 3 8B Instruct",
                        modelSize: 4_600_000_000,
                        startTime: Date().addingTimeInterval(-120)
                    )
                    progress.progress = 0.65
                    progress.status = .downloading
                    progress.downloadSpeed = 2_500_000
                    progress.estimatedTimeRemaining = 180
                    return progress
                }(),
                onCancel: {}
            )
            
            // Failed download
            DownloadProgressView(
                downloadProgress: {
                    let progress = DownloadProgress(
                        modelId: "test-2",
                        modelName: "CodeLlama 7B",
                        modelSize: 3_800_000_000,
                        startTime: Date().addingTimeInterval(-300)
                    )
                    progress.progress = 0.23
                    progress.status = .failed
                    progress.error = ManyLLMError.networkError("Connection timeout")
                    return progress
                }(),
                onCancel: {}
            )
        }
        .padding()
        .frame(width: 400)
    }
}
#endif