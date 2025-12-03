#!/bin/bash

# Script to create iOS app icon from Android source
# Requires ImageMagick: brew install imagemagick

echo "Creating iOS App Icon..."

# Create a temporary directory for processing
TEMP_DIR=$(mktemp -d)
OUTPUT_DIR="ios/Conduit/Conduit/Assets.xcassets/AppIcon.appiconset"

# Source image (using the largest Android icon)
SOURCE_IMAGE="android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png"

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "ImageMagick is required but not installed."
    echo "Install with: brew install imagemagick"
    exit 1
fi

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "Source image not found: $SOURCE_IMAGE"
    echo "Using alternative source..."
    SOURCE_IMAGE="android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"
fi

# Create a high-quality 1024x1024 icon for iOS
echo "Generating 1024x1024 iOS app icon..."

# Method 1: Upscale with smoothing for better quality
convert "$SOURCE_IMAGE" \
    -resize 1024x1024 \
    -background white \
    -gravity center \
    -extent 1024x1024 \
    -quality 100 \
    "$OUTPUT_DIR/AppIcon.png"

# Update Contents.json to reference the new icon
cat > "$OUTPUT_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo "iOS App Icon created successfully!"
echo ""
echo "The icon has been created at:"
echo "  $OUTPUT_DIR/AppIcon.png"
echo ""
echo "Note: For best quality, consider providing a 1024x1024 source image."
echo "The current icon was upscaled from ${SOURCE_IMAGE}"
echo ""
echo "To use a custom high-res icon:"
echo "  1. Create/obtain a 1024x1024 PNG image"
echo "  2. Name it AppIcon.png"
echo "  3. Copy it to: $OUTPUT_DIR/AppIcon.png"

# Clean up
rm -rf "$TEMP_DIR"