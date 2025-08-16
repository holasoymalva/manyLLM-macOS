#!/bin/bash

# ManyLLM App Runner Script
echo "🚀 Building and running ManyLLM..."

# Build the app
echo "📦 Building..."
xcodebuild build -scheme ManyLLM -destination 'platform=macOS' -quiet

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find and launch the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "ManyLLM.app" -type d 2>/dev/null | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "🎯 Launching ManyLLM app..."
        open "$APP_PATH"
        echo "✨ ManyLLM is now running!"
    else
        echo "❌ Could not find built app"
    fi
else
    echo "❌ Build failed"
    exit 1
fi