#!/bin/bash

# Build and run ManyLLM app
echo "Building ManyLLM..."
xcodebuild -project ManyLLM.xcodeproj -scheme ManyLLM -configuration Debug -derivedDataPath ./build clean build

if [ $? -eq 0 ]; then
    echo "Build successful! Launching app..."
    open ./build/Build/Products/Debug/ManyLLM.app
else
    echo "Build failed!"
    exit 1
fi