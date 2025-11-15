#!/bin/bash

# Clean and build
echo "🧹 Cleaning..."
cd android && ./gradlew clean > /dev/null 2>&1 && cd ..
fvm flutter clean > /dev/null 2>&1

echo "📦 Getting dependencies..."
fvm flutter pub get > /dev/null 2>&1

echo "🔨 Building APK..."
fvm flutter build apk --debug

echo "📱 Installing to device..."
adb install -t -r build/app/outputs/flutter-apk/app-debug.apk

echo "✅ Done! App installed successfully."
echo ""
echo "To run with hot reload, use:"
echo "  fvm flutter attach"
