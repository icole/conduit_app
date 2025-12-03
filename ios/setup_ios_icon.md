# iOS App Icon Setup

## Current Status
Your Android app uses a black crow/raven icon. For iOS, we need a 1024x1024 pixel version.

## Option 1: Quick Setup (Lower Quality)
Run the provided script if you have ImageMagick:
```bash
brew install imagemagick  # If not installed
./ios/create_app_icon.sh
```

## Option 2: Manual High-Quality Icon (Recommended)

### Create Your Icon
1. **Design Requirements:**
   - Size: 1024x1024 pixels
   - Format: PNG
   - No transparency (iOS will add rounded corners automatically)
   - No alpha channel for App Store submission

2. **Design Tips:**
   - Keep the design simple and recognizable at small sizes
   - Avoid text if possible
   - Use bold shapes that work at all scales
   - Consider adding a background color (the Android version has transparency)

### Install Your Icon
Once you have your 1024x1024 PNG file:

1. Name it `AppIcon.png`
2. Copy it to: `ios/Conduit/Conduit/Assets.xcassets/AppIcon.appiconset/`
3. The Contents.json is already configured

## Option 3: Use an Icon Generator Service

### Online Tools:
- **App Icon Generator**: https://www.appicon.co/
- **Icon Kitchen**: https://icon.kitchen/
- **MakeAppIcon**: https://makeappicon.com/

Upload your high-res crow image and these tools will generate all required sizes.

## Option 4: Create in Design Software

### Recommended Approach:
1. Create a new 1024x1024 canvas
2. Add a background color (e.g., white, light blue, or gradient)
3. Place the crow silhouette centered
4. Export as PNG

### Color Suggestions for Background:
- **Sky Blue**: #87CEEB (matches a crow in flight theme)
- **Sunset Orange**: #FF6B35 (dramatic contrast)
- **Clean White**: #FFFFFF (simple and clean)
- **Dark Gray**: #2C3E50 (sophisticated)

## Temporary Solution
For immediate testing, I'll copy the Android icon (it will be pixelated but functional):