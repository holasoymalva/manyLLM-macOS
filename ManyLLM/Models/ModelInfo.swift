import Foundation

/// Information about a language model, including metadata and status
struct ModelInfo: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let author: String
    let description: String
    let size: Int64
    let parameters: String
    let downloadURL: URL?
    var localPath: URL?
    var isLocal: Bool
    var isLoaded: Bool
    let compatibility: ModelCompatibility
    let version: String?
    let license: String?
    let tags: [String]
    let createdAt: Date?
    var updatedAt: Date?
    
    init(
        id: String,
        name: String,
        author: String,
        description: String,
        size: Int64,
        parameters: String,
        downloadURL: URL? = nil,
        localPath: URL? = nil,
        isLocal: Bool = false,
        isLoaded: Bool = false,
        compatibility: ModelCompatibility = .unknown,
        version: String? = nil,
        license: String? = nil,
        tags: [String] = [],
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.size = size
        self.parameters = parameters
        self.downloadURL = downloadURL
        self.localPath = localPath
        self.isLocal = isLocal
        self.isLoaded = isLoaded
        self.compatibility = compatibility
        self.version = version
        self.license = license
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Human-readable size string
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    /// Display name combining name and parameters
    var displayName: String {
        return "\(name) (\(parameters))"
    }
    
    /// Whether the model can be loaded
    var canLoad: Bool {
        return isLocal && !isLoaded && compatibility != .incompatible
    }
    
    /// Whether the model can be downloaded
    var canDownload: Bool {
        return !isLocal && downloadURL != nil
    }
}