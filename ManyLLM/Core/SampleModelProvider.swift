import Foundation

/// Provides sample models for testing the download infrastructure
class SampleModelProvider {
    
    /// Sample models for testing download functionality
    static let sampleModels: [ModelInfo] = [
        // Small test models
        ModelInfo(
            id: "llama-3-8b-instruct",
            name: "Llama 3 8B Instruct",
            author: "Meta",
            description: "A powerful 8B parameter instruction-tuned model from Meta's Llama 3 family. Excellent for general conversation, question answering, and following instructions.",
            size: 4_600_000_000, // ~4.6GB
            parameters: "8B",
            downloadURL: URL(string: "https://httpbin.org/bytes/1048576"), // 1MB test file
            compatibility: .fullyCompatible,
            version: "3.0",
            license: "Custom",
            tags: ["instruct", "chat", "general", "meta", "featured"],
            createdAt: Date().addingTimeInterval(-86400 * 30) // 30 days ago
        ),
        
        ModelInfo(
            id: "codellama-7b",
            name: "CodeLlama 7B",
            author: "Meta",
            description: "A specialized code generation model based on Llama 2. Trained on code and natural language instructions for programming tasks.",
            size: 3_800_000_000, // ~3.8GB
            parameters: "7B",
            downloadURL: URL(string: "https://httpbin.org/bytes/2097152"), // 2MB test file
            compatibility: .fullyCompatible,
            version: "1.0",
            license: "Custom",
            tags: ["code", "programming", "python", "javascript", "featured"],
            createdAt: Date().addingTimeInterval(-86400 * 60) // 60 days ago
        ),
        
        ModelInfo(
            id: "mistral-7b-instruct",
            name: "Mistral 7B Instruct",
            author: "Mistral AI",
            description: "A high-quality 7B parameter model with excellent instruction following capabilities. Efficient and fast while maintaining strong performance.",
            size: 4_100_000_000, // ~4.1GB
            parameters: "7B",
            downloadURL: URL(string: "https://httpbin.org/bytes/3145728"), // 3MB test file
            compatibility: .fullyCompatible,
            version: "0.2",
            license: "Apache 2.0",
            tags: ["instruct", "efficient", "fast", "mistral", "popular"],
            createdAt: Date().addingTimeInterval(-86400 * 45) // 45 days ago
        ),
        
        ModelInfo(
            id: "phi-3-mini",
            name: "Phi-3 Mini",
            author: "Microsoft",
            description: "A compact 3.8B parameter model with strong reasoning capabilities. Optimized for efficiency while maintaining good performance on various tasks.",
            size: 2_200_000_000, // ~2.2GB
            parameters: "3.8B",
            downloadURL: URL(string: "https://httpbin.org/bytes/1572864"), // 1.5MB test file
            compatibility: .fullyCompatible,
            version: "3.0",
            license: "MIT",
            tags: ["small", "efficient", "reasoning", "microsoft", "popular"],
            createdAt: Date().addingTimeInterval(-86400 * 15) // 15 days ago
        ),
        
        ModelInfo(
            id: "gemma-2b",
            name: "Gemma 2B",
            author: "Google",
            description: "A lightweight 2B parameter model from Google's Gemma family. Great for resource-constrained environments while still providing good performance.",
            size: 1_400_000_000, // ~1.4GB
            parameters: "2B",
            downloadURL: URL(string: "https://httpbin.org/bytes/1048576"), // 1MB test file
            compatibility: .fullyCompatible,
            version: "1.1",
            license: "Gemma Terms of Use",
            tags: ["lightweight", "efficient", "google", "gemma", "small"],
            createdAt: Date().addingTimeInterval(-86400 * 20) // 20 days ago
        ),
        
        // Larger models (for testing UI with different sizes)
        ModelInfo(
            id: "llama-3-70b-instruct",
            name: "Llama 3 70B Instruct",
            author: "Meta",
            description: "The largest model in the Llama 3 family with 70B parameters. Exceptional performance on complex reasoning, coding, and creative tasks.",
            size: 40_000_000_000, // ~40GB
            parameters: "70B",
            downloadURL: URL(string: "https://httpbin.org/bytes/10485760"), // 10MB test file
            compatibility: .partiallyCompatible,
            version: "3.0",
            license: "Custom",
            tags: ["large", "instruct", "reasoning", "meta", "premium"],
            createdAt: Date().addingTimeInterval(-86400 * 25) // 25 days ago
        ),
        
        // Already "downloaded" model for testing local functionality
        ModelInfo(
            id: "local-test-model",
            name: "Local Test Model",
            author: "Test",
            description: "A test model that appears as already downloaded locally. Used for testing local model management features.",
            size: 500_000_000, // ~500MB
            parameters: "1B",
            downloadURL: nil,
            localPath: URL(fileURLWithPath: "/tmp/test_model.bin"),
            isLocal: true,
            compatibility: .fullyCompatible,
            version: "1.0",
            license: "Test",
            tags: ["test", "local", "sample"],
            createdAt: Date().addingTimeInterval(-86400 * 5) // 5 days ago
        ),
        
        // Additional models for testing different compatibility levels
        ModelInfo(
            id: "claude-3-haiku",
            name: "Claude 3 Haiku",
            author: "Anthropic",
            description: "A fast and efficient model from Anthropic's Claude 3 family. Optimized for speed while maintaining good reasoning capabilities.",
            size: 3_200_000_000, // ~3.2GB
            parameters: "8B",
            downloadURL: URL(string: "https://httpbin.org/bytes/2097152"), // 2MB test file
            compatibility: .partiallyCompatible,
            version: "3.0",
            license: "Custom",
            tags: ["fast", "efficient", "reasoning", "anthropic", "claude"],
            createdAt: Date().addingTimeInterval(-86400 * 10) // 10 days ago
        ),
        
        ModelInfo(
            id: "gpt-4-turbo",
            name: "GPT-4 Turbo",
            author: "OpenAI",
            description: "Advanced language model with improved efficiency and capabilities. Note: This is a placeholder for testing incompatible models.",
            size: 50_000_000_000, // ~50GB (hypothetical)
            parameters: "175B",
            downloadURL: URL(string: "https://httpbin.org/status/404"), // Will fail
            compatibility: .incompatible,
            version: "4.0",
            license: "Proprietary",
            tags: ["large", "advanced", "openai", "proprietary"],
            createdAt: Date().addingTimeInterval(-86400 * 40) // 40 days ago
        ),
        
        ModelInfo(
            id: "unknown-model",
            name: "Experimental Model X",
            author: "Research Lab",
            description: "An experimental model with unknown compatibility. Use for testing compatibility checking features.",
            size: 7_500_000_000, // ~7.5GB
            parameters: "12B",
            downloadURL: URL(string: "https://httpbin.org/bytes/5242880"), // 5MB test file
            compatibility: .unknown,
            version: "0.1-alpha",
            license: "Research Only",
            tags: ["experimental", "research", "unknown", "alpha"],
            createdAt: Date().addingTimeInterval(-86400 * 3) // 3 days ago
        ),
        
        ModelInfo(
            id: "multilingual-model",
            name: "Universal Language Model",
            author: "Global AI",
            description: "A multilingual model supporting over 100 languages with strong translation and cross-lingual understanding capabilities.",
            size: 15_000_000_000, // ~15GB
            parameters: "22B",
            downloadURL: URL(string: "https://httpbin.org/bytes/8388608"), // 8MB test file
            compatibility: .fullyCompatible,
            version: "2.1",
            license: "Apache 2.0",
            tags: ["multilingual", "translation", "large", "global", "featured"],
            createdAt: Date().addingTimeInterval(-86400 * 18) // 18 days ago
        )
    ]
    
    /// Create sample models with realistic download URLs for testing
    static func createTestModels() -> [ModelInfo] {
        return sampleModels.map { model in
            var testModel = model
            
            // For testing, use httpbin.org which provides reliable test endpoints
            if let originalURL = model.downloadURL {
                // Use different endpoints for different file sizes to simulate real downloads
                let testEndpoints = [
                    "https://httpbin.org/bytes/1048576",    // 1MB
                    "https://httpbin.org/bytes/2097152",    // 2MB
                    "https://httpbin.org/bytes/3145728",    // 3MB
                    "https://httpbin.org/bytes/5242880",    // 5MB
                    "https://httpbin.org/delay/2",          // 2 second delay
                    "https://httpbin.org/status/200"        // Simple success
                ]
                
                let randomEndpoint = testEndpoints.randomElement() ?? testEndpoints[0]
                testModel.downloadURL = URL(string: randomEndpoint)
            }
            
            return testModel
        }
    }
    
    /// Get models filtered by category
    static func getModels(category: ModelCategory) -> [ModelInfo] {
        let models = createTestModels()
        
        switch category {
        case .all:
            return models
        case .local:
            return models.filter { $0.isLocal }
        case .remote:
            return models.filter { !$0.isLocal }
        case .downloading:
            return [] // Would be populated by active downloads
        }
    }
    
    /// Search models by query
    static func searchModels(query: String) -> [ModelInfo] {
        let models = createTestModels()
        
        if query.isEmpty {
            return models
        }
        
        let lowercaseQuery = query.lowercased()
        return models.filter { model in
            model.name.lowercased().contains(lowercaseQuery) ||
            model.author.lowercased().contains(lowercaseQuery) ||
            model.description.lowercased().contains(lowercaseQuery) ||
            model.tags.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
}

// Note: ModelCompatibility is now defined in ModelCompatibility.swift