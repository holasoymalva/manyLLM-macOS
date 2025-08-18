import SwiftUI

/// Model browser view with download functionality
struct ModelBrowserView: View {
    @StateObject private var downloadManager: ModelDownloadManager
    @State private var availableModels: [ModelInfo] = []
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedCategory: ModelCategory = .all
    @State private var searchFilters = ModelSearchFilters()
    @State private var showingFilters = false
    @State private var selectedModel: ModelInfo?
    @State private var showingModelDetail = false
    
    private let localRepository: LocalModelRepository
    private let remoteRepository: RemoteModelRepository
    
    init() {
        do {
            let localRepo = try LocalModelRepository()
            let remoteRepo = try RemoteModelRepository(localRepository: localRepo)
            self.localRepository = localRepo
            self.remoteRepository = remoteRepo
            self._downloadManager = StateObject(wrappedValue: ModelDownloadManager(
                remoteRepository: remoteRepo,
                localRepository: localRepo
            ))
        } catch {
            // Fallback initialization - in production you'd handle this better
            fatalError("Failed to initialize repositories: \(error)")
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                VStack(spacing: 12) {
                    HStack {
                        Text("Model Browser")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Download indicator
                        CompactDownloadIndicator(downloadManager: downloadManager)
                    }
                    
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search models...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    // Category filter and advanced filters
                    HStack {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(ModelCategory.allCases, id: \.self) { category in
                                Label(category.displayName, systemImage: category.systemImage).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        Spacer()
                        
                        Button("Filters") {
                            showingFilters = true
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                
                Divider()
                
                // Model list
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("Loading models...")
                        Spacer()
                    }
                } else if filteredModels.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "cube.box")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No models found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try adjusting your search or category filter")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredModels) { model in
                                ModelCard(
                                    model: model,
                                    downloadManager: downloadManager,
                                    onDownload: { model in
                                        Task {
                                            await downloadModel(model)
                                        }
                                    },
                                    onCancel: { modelId in
                                        cancelDownload(modelId)
                                    },
                                    onShowDetails: { model in
                                        selectedModel = model
                                        showingModelDetail = true
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }
                
                Divider()
                
                // Active downloads section
                if !downloadManager.activeDownloads.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Active Downloads")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(downloadManager.getActiveDownloads()) { download in
                                    DownloadProgressView(
                                        downloadProgress: download,
                                        onCancel: {
                                            cancelDownload(download.modelId)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Models")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Refresh") {
                        Task {
                            await loadModels()
                        }
                    }
                }
                
                ToolbarItem(placement: .secondaryAction) {
                    Button("Download History") {
                        // Show download history sheet
                    }
                }
            }
        }
        .task {
            await loadModels()
        }
        .sheet(isPresented: $showingFilters) {
            ModelSearchFiltersView(filters: $searchFilters)
        }
        .sheet(isPresented: $showingModelDetail) {
            if let model = selectedModel {
                ModelDetailView(model: model, downloadManager: downloadManager)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }
    
    private var filteredModels: [ModelInfo] {
        var models = availableModels
        
        // Filter by category first
        switch selectedCategory {
        case .all:
            break
        case .local:
            models = models.filter { $0.isLocal }
        case .remote:
            models = models.filter { !$0.isLocal }
        case .downloading:
            let downloadingIds = Set(downloadManager.activeDownloads.keys)
            models = models.filter { downloadingIds.contains($0.id) }
        case .compatible:
            let checker = ModelCompatibilityChecker()
            models = models.filter { model in
                let result = checker.checkCompatibility(for: model)
                return result.compatibility == .fullyCompatible
            }
        case .featured:
            models = models.filter { $0.tags.contains("featured") || $0.tags.contains("popular") }
        }
        
        // Apply search text filter
        if !searchText.isEmpty {
            let lowercaseQuery = searchText.lowercased()
            models = models.filter { model in
                model.name.lowercased().contains(lowercaseQuery) ||
                model.author.lowercased().contains(lowercaseQuery) ||
                model.description.lowercased().contains(lowercaseQuery) ||
                model.tags.contains { $0.lowercased().contains(lowercaseQuery) } ||
                model.parameters.lowercased().contains(lowercaseQuery)
            }
        }
        
        // Apply advanced filters
        models = applyAdvancedFilters(to: models)
        
        // Apply sorting
        return applySorting(to: models)
    }
    
    private func applyAdvancedFilters(to models: [ModelInfo]) -> [ModelInfo] {
        var filteredModels = models
        
        // Filter by compatibility
        if let compatibility = searchFilters.compatibility {
            let checker = ModelCompatibilityChecker()
            filteredModels = filteredModels.filter { model in
                let result = checker.checkCompatibility(for: model)
                return result.compatibility == compatibility
            }
        }
        
        // Filter by parameter size
        if let minParameters = searchFilters.minParameters {
            filteredModels = filteredModels.filter { model in
                extractParameterCount(from: model.parameters) >= minParameters
            }
        }
        
        if let maxParameters = searchFilters.maxParameters {
            filteredModels = filteredModels.filter { model in
                extractParameterCount(from: model.parameters) <= maxParameters
            }
        }
        
        // Filter by size
        if let minSize = searchFilters.minSize {
            filteredModels = filteredModels.filter { $0.size >= minSize }
        }
        
        if let maxSize = searchFilters.maxSize {
            filteredModels = filteredModels.filter { $0.size <= maxSize }
        }
        
        // Filter by author
        if let author = searchFilters.author {
            filteredModels = filteredModels.filter { $0.author.lowercased() == author.lowercased() }
        }
        
        // Filter by tags
        if !searchFilters.tags.isEmpty {
            filteredModels = filteredModels.filter { model in
                searchFilters.tags.allSatisfy { tag in
                    model.tags.contains { $0.lowercased() == tag.lowercased() }
                }
            }
        }
        
        return filteredModels
    }
    
    private func applySorting(to models: [ModelInfo]) -> [ModelInfo] {
        let sortedModels: [ModelInfo]
        
        switch searchFilters.sortBy {
        case .name:
            sortedModels = models.sorted { $0.name < $1.name }
        case .author:
            sortedModels = models.sorted { $0.author < $1.author }
        case .size:
            sortedModels = models.sorted { $0.size < $1.size }
        case .parameters:
            sortedModels = models.sorted { 
                extractParameterCount(from: $0.parameters) < extractParameterCount(from: $1.parameters)
            }
        case .dateCreated:
            sortedModels = models.sorted { 
                ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast)
            }
        case .dateUpdated:
            sortedModels = models.sorted { 
                ($0.updatedAt ?? Date.distantPast) < ($1.updatedAt ?? Date.distantPast)
            }
        case .compatibility:
            let checker = ModelCompatibilityChecker()
            sortedModels = models.sorted { model1, model2 in
                let result1 = checker.checkCompatibility(for: model1)
                let result2 = checker.checkCompatibility(for: model2)
                return result1.compatibility > result2.compatibility
            }
        }
        
        return searchFilters.sortAscending ? sortedModels : sortedModels.reversed()
    }
    
    private func extractParameterCount(from parameterString: String) -> Double {
        let cleanString = parameterString.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanString.hasSuffix("B") {
            return Double(cleanString.dropLast()) ?? 0
        } else if cleanString.hasSuffix("M") {
            return (Double(cleanString.dropLast()) ?? 0) / 1000
        } else if cleanString.hasSuffix("K") {
            return (Double(cleanString.dropLast()) ?? 0) / 1_000_000
        }
        
        return 0
    }
    
    @MainActor
    private func loadModels() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let models = try await remoteRepository.fetchAvailableModels()
            availableModels = models
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
        
        isLoading = false
    }
    
    @MainActor
    private func downloadModel(_ model: ModelInfo) async {
        do {
            try await downloadManager.downloadModel(model)
            // Refresh models to show updated status
            await loadModels()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func cancelDownload(_ modelId: String) {
        do {
            try downloadManager.cancelDownload(modelId: modelId)
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

/// Individual model card with download controls
struct ModelCard: View {
    let model: ModelInfo
    @ObservedObject var downloadManager: ModelDownloadManager
    let onDownload: (ModelInfo) -> Void
    let onCancel: (String) -> Void
    let onShowDetails: (ModelInfo) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("by \(model.author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status badge
                ModelStatusBadge(model: model, downloadManager: downloadManager)
            }
            
            // Description
            Text(model.description)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            // Model details
            HStack {
                Label(model.parameters, systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label(model.sizeString, systemImage: "externaldrive")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Tags
            if !model.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(model.tags.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            
            // Download progress or controls
            if let downloadProgress = downloadManager.getDownloadProgress(for: model.id) {
                DownloadProgressView(
                    downloadProgress: downloadProgress,
                    onCancel: { onCancel(model.id) }
                )
            } else {
                HStack {
                    if model.isLocal {
                        Button("Open") {
                            // Handle opening local model
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Delete") {
                            // Handle deleting local model
                        }
                        .buttonStyle(.bordered)
                    } else if model.canDownload {
                        Button("Download") {
                            onDownload(model)
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Details") {
                            onShowDetails(model)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
        )
    }
}

/// Status badge for model cards
struct ModelStatusBadge: View {
    let model: ModelInfo
    @ObservedObject var downloadManager: ModelDownloadManager
    
    var body: some View {
        Group {
            if model.isLocal {
                Label("Local", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if downloadManager.getDownloadProgress(for: model.id) != nil {
                Label("Downloading", systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundColor(.blue)
            } else if model.canDownload {
                Label("Available", systemImage: "cloud")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Label("Unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
}

/// Model category filter
enum ModelCategory: CaseIterable {
    case all
    case local
    case remote
    case downloading
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .local: return "Local"
        case .remote: return "Remote"
        case .downloading: return "Downloading"
        }
    }
}

// MARK: - Preview Support

#if DEBUG
struct ModelBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        ModelBrowserView()
            .frame(width: 800, height: 600)
    }
}
#endif