#!/bin/bash

# Create IDB Bundle for Electron Distribution
set -e

COMPANION_PATH="/Users/bkessler/Apps/idb-main/build/Build/Products/Release/idb_companion"
CLIENT_PATH="/Users/bkessler/Apps/idb-main/dist/idb-cli"
FRAMEWORKS_DIR="/Users/bkessler/Apps/idb-main/build/Build/Products/Release"

echo "🔨 Creating IDB bundle for Electron distribution..."

# Create bundle structure
BUNDLE_DIR="idb-bundle"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/darwin-arm64/bin"
mkdir -p "$BUNDLE_DIR/darwin-arm64/Frameworks"
mkdir -p "$BUNDLE_DIR/darwin-arm64/lib"

echo "📦 Copying binaries..."

# Copy main binaries
cp "$COMPANION_PATH" "$BUNDLE_DIR/darwin-arm64/bin/"
cp "$CLIENT_PATH" "$BUNDLE_DIR/darwin-arm64/bin/"

echo "📚 Copying frameworks..."

# Copy all required frameworks
FRAMEWORKS=(
    "FBControlCore.framework"
    "FBDeviceControl.framework" 
    "IDBCompanionUtilities.framework"
    "FBSimulatorControl.framework"
    "XCTestBootstrap.framework"
    "IDBGRPCSwift.framework"
    "CompanionLib.framework"
)

for framework in "${FRAMEWORKS[@]}"; do
    if [[ -d "$FRAMEWORKS_DIR/$framework" ]]; then
        echo "  ✅ Copying $framework"
        cp -R "$FRAMEWORKS_DIR/$framework" "$BUNDLE_DIR/darwin-arm64/Frameworks/"
    else
        echo "  ❌ Warning: $framework not found"
    fi
done

echo "🔍 Finding Swift Concurrency library..."

# Find and copy Swift Concurrency library
CONCURRENCY_LIB=""
SEARCH_PATHS=(
    "/usr/lib/swift/libswift_Concurrency.dylib"
    "/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/macosx/libswift_Concurrency.dylib"
    "$FRAMEWORKS_DIR/PackageFrameworks/libswift_Concurrency.dylib"
)

for path in "${SEARCH_PATHS[@]}"; do
    if [[ -f "$path" ]]; then
        CONCURRENCY_LIB="$path"
        echo "  ✅ Found Swift Concurrency at: $path"
        cp "$path" "$BUNDLE_DIR/darwin-arm64/lib/"
        break
    fi
done

if [[ -z "$CONCURRENCY_LIB" ]]; then
    echo "  ⚠️  Swift Concurrency library not found - companion may not work on systems without Xcode"
fi

echo "📝 Creating wrapper scripts..."

# Create companion wrapper that sets up library paths
cat > "$BUNDLE_DIR/darwin-arm64/idb_companion" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
export DYLD_LIBRARY_PATH="$DIR/lib:$DYLD_LIBRARY_PATH"
exec "$DIR/bin/idb_companion" "$@"
EOF

# Create client wrapper
cat > "$BUNDLE_DIR/darwin-arm64/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/bin/idb-cli" "$@"
EOF

chmod +x "$BUNDLE_DIR/darwin-arm64/idb_companion"
chmod +x "$BUNDLE_DIR/darwin-arm64/idb"

echo "🧪 Testing the bundle..."

# Test the companion
echo "Testing companion..."
"$BUNDLE_DIR/darwin-arm64/idb_companion" --help > /dev/null 2>&1 && \
    echo "  ✅ Companion works" || \
    echo "  ❌ Companion failed"

# Test the client  
echo "Testing client..."
"$BUNDLE_DIR/darwin-arm64/idb" --help > /dev/null 2>&1 && \
    echo "  ✅ Client works" || \
    echo "  ❌ Client failed"

echo "📊 Bundle analysis:"
echo "Bundle size: $(du -sh "$BUNDLE_DIR" | cut -f1)"
echo "Companion size: $(ls -lh "$BUNDLE_DIR/darwin-arm64/bin/idb_companion" | awk '{print $5}')"
echo "Client size: $(ls -lh "$BUNDLE_DIR/darwin-arm64/bin/idb-cli" | awk '{print $5}')"
echo "Frameworks count: $(ls "$BUNDLE_DIR/darwin-arm64/Frameworks" | wc -l)"

echo ""
echo "✅ Bundle created successfully!"
echo "📁 Location: $BUNDLE_DIR/"
echo ""
echo "🚀 For Electron integration:"
echo "   1. Copy $BUNDLE_DIR to your Electron app's resources/"
echo "   2. Use the wrapper scripts to call IDB from your app"
echo "   3. Your enhanced video streaming and touch features are included!"

# Create a test script for your enhanced features
cat > "test_enhanced_features.sh" << 'EOF'
#!/bin/bash

BUNDLE_DIR="idb-bundle"
UDID="8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000"  # Replace with your device UDID

echo "🧪 Testing enhanced IDB features..."

# Test enhanced video streaming
echo "Testing enhanced video streaming..."
timeout 5s "$BUNDLE_DIR/darwin-arm64/idb" video-stream \
    --fps 30 \
    --format h264 \
    --keyframe-interval 30 \
    --profile baseline \
    --max-bitrate 4000 \
    --buffer-size 2000 \
    --preset streaming \
    --udid $UDID \
    test_output.h264 && \
    echo "  ✅ Enhanced video streaming works" || \
    echo "  ❌ Enhanced video streaming failed"

# Test touch streaming
echo "Testing touch streaming..."
echo '{"type": "touch_start", "x": 100, "y": 200}' | \
    "$BUNDLE_DIR/darwin-arm64/idb" ui stream-touch --udid $UDID && \
    echo "  ✅ Touch streaming works" || \
    echo "  ❌ Touch streaming failed"

echo "🎉 Enhanced features test complete!"
EOF

chmod +x test_enhanced_features.sh
echo "📋 Created test_enhanced_features.sh to verify your customizations work"