#!/bin/bash

# Script to quickly switch between Debug and Release configurations

if [ "$1" == "device" ]; then
    echo "Switching to Release configuration for device..."
    xcodebuild -scheme Conduit -configuration Release
    echo "✅ Ready for device deployment (Release mode)"
elif [ "$1" == "simulator" ]; then
    echo "Switching to Debug configuration for simulator..."
    xcodebuild -scheme Conduit -configuration Debug
    echo "✅ Ready for simulator testing (Debug mode)"
else
    echo "Usage: ./switch_config.sh [device|simulator]"
    echo "  device    - Use Release configuration"
    echo "  simulator - Use Debug configuration"
fi