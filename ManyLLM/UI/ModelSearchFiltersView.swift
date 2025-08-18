import SwiftUI

/// Advanced search filters view for model discovery
struct ModelSearchFiltersView: View {
    @Binding var filters: ModelSearchFilters
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempFilters: ModelSearchFilters
    @State private var authorText = ""
    @State private var tagsText = ""
    @State private var licenseText = ""
    
    init(filters: Binding<ModelSearchFilters>) {
        self._filters = filters
        self._tempFilters = State(initialValue: filters.wrappedValue)
        self._authorText = State(initialValue: filters.wrappedValue.author ?? "")
        self._tagsText = State(initialValue: filters.wrappedValue.tags.joined(separator: ", "))
        self._licenseText = State(initialValue: filters.wrappedValue.license ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Compatibility section
                Section("Compatibility") {
                    Picker("Compatibility Level", selection: $tempFilters.compatibility) {
                        Text("Any").tag(ModelCompatibility?.none)
                        ForEach(ModelCompatibility.allCases, id: \.self) { compatibility in
                            Text(compatibility.displayName).tag(ModelCompatibility?.some(compatibility))
                        }
                    }
                }
                
                // Parameter size section
                Section("Model Size") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Parameter Count (Billions)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Min:")
                            TextField("0", value: $tempFilters.minParameters, format: .number)
                                .textFieldStyle(.roundedBorder)
                            
                            Text("Max:")
                            TextField("∞", value: $tempFilters.maxParameters, format: .number)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Quick parameter presets
                        HStack {
                            Button("Small (<10B)") {
                                tempFilters.minParameters = nil
                                tempFilters.maxParameters = 10.0
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Medium (10-30B)") {
                                tempFilters.minParameters = 10.0
                                tempFilters.maxParameters = 30.0
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Large (>30B)") {
                                tempFilters.minParameters = 30.0
                                tempFilters.maxParameters = nil
                            }
                            .buttonStyle(.bordered)
                        }
                        .font(.caption)
                    }
                }
                
                // File size section
                Section("File Size") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Model File Size")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Min:")
                            TextField("0 GB", value: Binding(
                                get: { tempFilters.minSize.map { Double($0) / 1_000_000_000 } },
                                set: { tempFilters.minSize = $0.map { Int64($0 * 1_000_000_000) } }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            Text("GB")
                            
                            Text("Max:")
                            TextField("∞ GB", value: Binding(
                                get: { tempFilters.maxSize.map { Double($0) / 1_000_000_000 } },
                                set: { tempFilters.maxSize = $0.map { Int64($0 * 1_000_000_000) } }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            Text("GB")
                        }
                    }
                }
                
                // Author section
                Section("Author") {
                    TextField("Filter by author", text: $authorText)
                        .textFieldStyle(.roundedBorder)
                    
                    // Popular authors
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(popularAuthors, id: \.self) { author in
                                Button(author) {
                                    authorText = author
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Tags section
                Section("Tags") {
                    TextField("Enter tags separated by commas", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                    
                    // Popular tags
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 80))
                    ], spacing: 8) {
                        ForEach(popularTags, id: \.self) { tag in
                            Button(tag) {
                                addTag(tag)
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }
                
                // License section
                Section("License") {
                    TextField("Filter by license", text: $licenseText)
                        .textFieldStyle(.roundedBorder)
                    
                    // Common licenses
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(commonLicenses, id: \.self) { license in
                                Button(license) {
                                    licenseText = license
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                // Sorting section
                Section("Sorting") {
                    Picker("Sort by", selection: $tempFilters.sortBy) {
                        ForEach(ModelSortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    
                    Toggle("Ascending Order", isOn: $tempFilters.sortAscending)
                }
                
                // Reset section
                Section {
                    Button("Reset All Filters") {
                        resetFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Search Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFilters()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    private var popularAuthors: [String] {
        ["Meta", "Microsoft", "Google", "Mistral AI", "Anthropic", "OpenAI"]
    }
    
    private var popularTags: [String] {
        ["instruct", "chat", "code", "reasoning", "efficient", "small", "large", "multilingual"]
    }
    
    private var commonLicenses: [String] {
        ["Apache 2.0", "MIT", "Custom", "CC BY-NC", "Llama 2"]
    }
    
    private func addTag(_ tag: String) {
        let currentTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        if !currentTags.contains(tag) {
            if tagsText.isEmpty {
                tagsText = tag
            } else {
                tagsText += ", \(tag)"
            }
        }
    }
    
    private func applyFilters() {
        // Update text-based filters
        tempFilters.author = authorText.isEmpty ? nil : authorText
        tempFilters.license = licenseText.isEmpty ? nil : licenseText
        tempFilters.tags = tagsText.isEmpty ? [] : tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        filters = tempFilters
    }
    
    private func resetFilters() {
        tempFilters = ModelSearchFilters()
        authorText = ""
        tagsText = ""
        licenseText = ""
    }
}

// MARK: - Preview Support

#if DEBUG
struct ModelSearchFiltersView_Previews: PreviewProvider {
    static var previews: some View {
        ModelSearchFiltersView(filters: .constant(ModelSearchFilters()))
    }
}
#endif