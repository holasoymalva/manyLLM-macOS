import XCTest
@testable import ManyLLM

final class ModelInfoTests: XCTestCase {
    
    func testModelInfoInitialization() {
        let model = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1024 * 1024 * 1024, // 1GB
            parameters: "7B"
        )
        
        XCTAssertEqual(model.id, "test-model")
        XCTAssertEqual(model.name, "Test Model")
        XCTAssertEqual(model.author, "Test Author")
        XCTAssertEqual(model.description, "A test model")
        XCTAssertEqual(model.size, 1024 * 1024 * 1024)
        XCTAssertEqual(model.parameters, "7B")
        XCTAssertFalse(model.isLocal)
        XCTAssertFalse(model.isLoaded)
        XCTAssertEqual(model.compatibility, .unknown)
    }
    
    func testModelInfoSerialization() throws {
        let originalModel = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            downloadURL: URL(string: "https://example.com/model.bin"),
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible,
            version: "1.0",
            license: "MIT",
            tags: ["test", "example"]
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(originalModel)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedModel = try decoder.decode(ModelInfo.self, from: data)
        
        XCTAssertEqual(originalModel, decodedModel)
    }
    
    func testModelInfoDisplayProperties() {
        let model = ModelInfo(
            id: "test-model",
            name: "Llama 3",
            author: "Meta",
            description: "A test model",
            size: 4 * 1024 * 1024 * 1024, // 4GB
            parameters: "8B"
        )
        
        XCTAssertEqual(model.displayName, "Llama 3 (8B)")
        XCTAssertTrue(model.sizeString.contains("4"))
        XCTAssertTrue(model.sizeString.contains("GB"))
    }
    
    func testModelInfoCapabilities() {
        var model = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            downloadURL: URL(string: "https://example.com/model.bin"),
            isLocal: false,
            compatibility: .fullyCompatible
        )
        
        // Test download capability
        XCTAssertTrue(model.canDownload)
        XCTAssertFalse(model.canLoad)
        
        // Test load capability
        model = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            isLocal: true,
            isLoaded: false,
            compatibility: .fullyCompatible
        )
        
        XCTAssertFalse(model.canDownload)
        XCTAssertTrue(model.canLoad)
        
        // Test incompatible model
        model = ModelInfo(
            id: "test-model",
            name: "Test Model",
            author: "Test Author",
            description: "A test model",
            size: 1024 * 1024 * 1024,
            parameters: "7B",
            isLocal: true,
            isLoaded: false,
            compatibility: .incompatible
        )
        
        XCTAssertFalse(model.canLoad)
    }
}