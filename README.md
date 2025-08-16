# ManyLLM Desktop App

A native macOS desktop application for running and managing large language models locally with complete privacy.

## Project Structure

This project follows a modular architecture with the following structure:

```
ManyLLM/
├── ManyLLMApp.swift          # Main app entry point
├── ContentView.swift         # Main window structure
├── Core/                     # Core application logic
├── UI/                       # SwiftUI views and components
├── Models/                   # Data models and structures
├── Services/                 # Model management and inference
├── Storage/                  # Data persistence layer
├── API/                      # Optional REST API server
└── Assets.xcassets/          # App icons and resources
```

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Apple Silicon Mac (recommended for MLX support)

## Building

1. Open `ManyLLM.xcodeproj` in Xcode
2. Select the ManyLLM scheme
3. Build and run (⌘R)

## Features (Planned)

- Local LLM inference with MLX and llama.cpp
- Model discovery and download from Hugging Face
- Document upload and RAG processing
- Workspace organization
- Privacy-focused local processing
- Optional API server for developer integration

## Bundle Identifier

`com.manyllm.desktop`
