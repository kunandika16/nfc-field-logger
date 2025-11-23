#!/bin/bash

# Script to generate NFC Logger app icon
# This script creates a simple app icon that matches the internal NFC contactless icon

echo "🔧 Generating NFC Logger App Icon..."
echo ""

# Check if assets/icon directory exists
if [ ! -d "assets/icon" ]; then
    echo "📁 Creating assets/icon directory..."
    mkdir -p assets/icon
fi

echo "📝 To create the NFC app icon manually:"
echo ""
echo "1. 🎨 Create Icon (choose one method):"
echo "   Method A - Online Generator:"
echo "   • Go to https://icon.kitchen/"
echo "   • Select 'Adaptive Icon' type"
echo "   • Choose Material Icons > 'contactless' symbol"
echo "   • Set background color: #2196F3 (blue)"
echo "   • Set foreground color: #FFFFFF (white)"
echo "   • Download as 1024x1024 PNG"
echo ""
echo "   Method B - Design Tool:"
echo "   • Open Canva/Figma"
echo "   • Create 1024x1024px canvas"
echo "   • Add blue background (#2196F3)"
echo "   • Add white NFC/contactless symbol in center"
echo "   • Export as PNG"
echo ""
echo "   Method C - Screenshot Method:"
echo "   • Run the app and go to splash screen"
echo "   • Screenshot the blue NFC icon"
echo "   • Crop to square and resize to 1024x1024"
echo ""
echo "2. 💾 Save the file:"
echo "   • Save as 'nfc_icon.png' in assets/icon/ folder"
echo "   • Must be exactly 1024x1024 pixels"
echo ""
echo "3. 🔧 Update pubspec.yaml:"
echo "   • Uncomment the image_path line in flutter_launcher_icons section"
echo ""
echo "4. 🚀 Generate launcher icons:"
echo "   • Run: fvm flutter pub run flutter_launcher_icons"
echo ""
echo "📱 Current Status:"
if [ -f "assets/icon/nfc_icon.png" ]; then
    echo "   ✅ Icon file found: assets/icon/nfc_icon.png"
else
    echo "   ❌ Icon file missing: assets/icon/nfc_icon.png"
    echo "   📌 Please create the icon file first"
fi
echo ""
echo "🎯 Target: Make app launcher icon match the blue NFC contactless icon used inside the app"