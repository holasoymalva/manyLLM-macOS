#!/bin/bash

# Check if rsvg-convert is available
if ! command -v rsvg-convert &> /dev/null; then
    echo "rsvg-convert not found. Installing via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "Homebrew not found. Please install Homebrew first or install rsvg-convert manually."
        exit 1
    fi
    brew install librsvg
fi

# Create the icon directory if it doesn't exist
ICON_DIR="ManyLLM/Assets.xcassets/AppIcon.appiconset"

# Generate all required icon sizes
echo "Generating app icons..."

# 16x16
rsvg-convert -w 16 -h 16 manyllm_icon.svg -o "$ICON_DIR/icon_16x16.png"
rsvg-convert -w 32 -h 32 manyllm_icon.svg -o "$ICON_DIR/icon_16x16@2x.png"

# 32x32
rsvg-convert -w 32 -h 32 manyllm_icon.svg -o "$ICON_DIR/icon_32x32.png"
rsvg-convert -w 64 -h 64 manyllm_icon.svg -o "$ICON_DIR/icon_32x32@2x.png"

# 128x128
rsvg-convert -w 128 -h 128 manyllm_icon.svg -o "$ICON_DIR/icon_128x128.png"
rsvg-convert -w 256 -h 256 manyllm_icon.svg -o "$ICON_DIR/icon_128x128@2x.png"

# 256x256
rsvg-convert -w 256 -h 256 manyllm_icon.svg -o "$ICON_DIR/icon_256x256.png"
rsvg-convert -w 512 -h 512 manyllm_icon.svg -o "$ICON_DIR/icon_256x256@2x.png"

# 512x512
rsvg-convert -w 512 -h 512 manyllm_icon.svg -o "$ICON_DIR/icon_512x512.png"
rsvg-convert -w 1024 -h 1024 manyllm_icon.svg -o "$ICON_DIR/icon_512x512@2x.png"

echo "App icons generated successfully!"
echo "You may need to clean and rebuild your Xcode project for the new icons to take effect."