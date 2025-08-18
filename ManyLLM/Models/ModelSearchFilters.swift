import Foundation

/// Filters for model search and discovery
struct ModelSearchFilters {
    var compatibility: ModelCompatibility?
    var minParameters: Double?
    var maxParameters: Double?
    var minSize: Int64?
    var maxSize: Int64?
    var author: String?
    var tags: [String] = []
    var license: String?
    var sortBy: ModelSortOption = .name
    var sortAscending: Bool = true
    
    init() {}
    
    /// Create filters for compatible models only
    static func compatibleOnly() -> ModelSearchFilters {
        var filters = ModelSearchFilters()
        filters.compatibility = .fullyCompatible
        return filters
    }
    
    /// Create filters for small models (under 10B parameters)
    static func smallModels() -> ModelSearchFilters {
        var filters = ModelSearchFilters()
        filters.maxParameters = 10.0
        return filters
    }
    
    /// Create filters for large models (over 30B parameters)
    static func largeModels() -> ModelSearchFilters {
        var filters = ModelSearchFilters()
        filters.minParameters = 30.0
        return filters
    }
    
    /// Create filters for models by specific author
    static func byAuthor(_ author: String) -> ModelSearchFilters {
        var filters = ModelSearchFilters()
        filters.author = author
        return filters
    }
    
    /// Create filters for models with specific tags
    static func withTags(_ tags: [String]) -> ModelSearchFilters {
        var filters = ModelSearchFilters()
        filters.tags = tags
        return filters
    }
}

/// Options for sorting model search results
enum ModelSortOption: String, CaseIterable {
    case name = "name"
    case author = "author"
    case size = "size"
    case parameters = "parameters"
    case dateCreated = "date_created"
    case dateUpdated = "date_updated"
    case compatibility = "compatibility"
    
    var displayName: String {
        switch self {
        case .name: return "Name"
        case .author: return "Author"
        case .size: return "Size"
        case .parameters: return "Parameters"
        case .dateCreated: return "Date Created"
        case .dateUpdated: return "Date Updated"
        case .compatibility: return "Compatibility"
        }
    }
}

/// Extended model categories for better organization
enum ModelCategory: String, CaseIterable {
    case all = "all"
    case local = "local"
    case remote = "remote"
    case downloading = "downloading"
    case compatible = "compatible"
    case featured = "featured"
    
    var displayName: String {
        switch self {
        case .all: return "All Models"
        case .local: return "Local Models"
        case .remote: return "Remote Models"
        case .downloading: return "Downloading"
        case .compatible: return "Compatible"
        case .featured: return "Featured"
        }
    }
    
    var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .local: return "internaldrive"
        case .remote: return "cloud"
        case .downloading: return "arrow.down.circle"
        case .compatible: return "checkmark.shield"
        case .featured: return "star"
        }
    }
}