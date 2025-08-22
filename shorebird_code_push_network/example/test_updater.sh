#!/bin/bash

echo "🔧 Testing Shorebird Network Updater..."
echo "====================================="

# Clean previous runs
echo "🧹 Cleaning previous build..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run on Android emulator
echo "🤖 Running on Android emulator..."
flutter run -d emulator-64 --verbose | tee android_test.log

echo "✅ Test completed! Check android_test.log for details."