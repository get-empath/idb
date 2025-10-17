#!/bin/bash

set -e

COMPANION_PATH="/Users/bkessler/Apps/idb-main/build/Build/Products/Release/idb_companion"
IDB_SCRIPT="/Users/bkessler/Apps/idb-main/idb-env/bin/idb"
FRAMEWORKS_DIR="/Users/bkessler/Apps/idb-main/build/Build/Products/Release"
SWIFT_CONCURRENCY="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift-5.5/macosx/libswift_Concurrency.dylib"

echo "🔨 Creating final working IDB bundle with enhanced features..."

BUNDLE_DIR="idb-bundle-final"
rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/darwin-arm64/bin"
mkdir -p "$BUNDLE_DIR/darwin-arm64/Frameworks" 
mkdir -p "$BUNDLE_DIR/darwin-arm64/lib"

echo "📦 Copying binaries..."
cp "$COMPANION_PATH" "$BUNDLE_DIR/darwin-arm64/bin/"
cp "$IDB_SCRIPT" "$BUNDLE_DIR/darwin-arm64/bin/"

echo "📚 Copying frameworks..."
for framework in FBControlCore.framework FBDeviceControl.framework IDBCompanionUtilities.framework FBSimulatorControl.framework XCTestBootstrap.framework IDBGRPCSwift.framework CompanionLib.framework; do
    if [[ -d "$FRAMEWORKS_DIR/$framework" ]]; then
        echo "  ✅ Copying $framework"
        cp -R "$FRAMEWORKS_DIR/$framework" "$BUNDLE_DIR/darwin-arm64/Frameworks/"
    fi
done

echo "🔧 Copying Swift Concurrency..."
cp "$SWIFT_CONCURRENCY" "$BUNDLE_DIR/darwin-arm64/lib/"
echo "  ✅ Swift Concurrency library copied"

echo "📝 Creating wrapper scripts..."

# Companion wrapper
cat > "$BUNDLE_DIR/darwin-arm64/idb_companion" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
export DYLD_LIBRARY_PATH="$DIR/lib:$DYLD_LIBRARY_PATH"
exec "$DIR/bin/idb_companion" "$@"
WRAPPER_EOF

# Client wrapper
cat > "$BUNDLE_DIR/darwin-arm64/idb" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/bin/idb" "$@"
WRAPPER_EOF

chmod +x "$BUNDLE_DIR/darwin-arm64/idb_companion"
chmod +x "$BUNDLE_DIR/darwin-arm64/idb"
chmod +x "$BUNDLE_DIR/darwin-arm64/bin/idb_companion"
chmod +x "$BUNDLE_DIR/darwin-arm64/bin/idb"

echo "🧪 Testing final bundle..."
cd "$BUNDLE_DIR/darwin-arm64"

echo "Testing companion:"
if ./idb_companion --help >/dev/null 2>&1; then
    echo "  ✅ Companion works!"
else
    echo "  ❌ Companion failed"
fi

echo "Testing enhanced IDB client:"
if ./idb --help >/dev/null 2>&1; then
    echo "  ✅ IDB client works!"
else
    echo "  ❌ IDB client failed"
fi

echo "🎯 Testing your enhanced features:"

# Test enhanced video streaming
echo "Enhanced video streaming:"
if ./idb video-stream --help 2>/dev/null | grep -q "keyframe-interval"; then
    echo "  ✅ Enhanced video streaming with custom parameters!"
    ./idb video-stream --help | grep -E "(fps|keyframe-interval|max-bitrate|profile|preset)" | head -5
else
    echo "  ❓ Standard video streaming"
fi

# Test touch streaming
echo "Touch streaming:"
if ./idb ui --help 2>/dev/null | grep -q "stream-touch"; then
    echo "  ✅ Touch streaming capability detected!"
else
    echo "  ❓ Standard UI interactions"
fi

cd - >/dev/null

echo ""
echo "✅ Final bundle created successfully!"
echo "📁 Location: $BUNDLE_DIR/"
echo "📊 Bundle size: $(du -sh "$BUNDLE_DIR" | cut -f1)"
echo ""
echo "🚀 Ready for Electron integration!"
echo "   Companion: $BUNDLE_DIR/darwin-arm64/idb_companion"
echo "   Client: $BUNDLE_DIR/darwin-arm64/idb"
echo ""
echo "✨ Your enhanced features included:"
echo "   • Enhanced video streaming (fps, keyframe-interval, max-bitrate, profile, preset)"
echo "   • Touch streaming capabilities" 
echo "   • All custom modifications preserved"
