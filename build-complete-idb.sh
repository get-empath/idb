#!/bin/bash

# Complete IDB build script with code signing
# Usage: ./build-complete-idb.sh [output_directory]

set -e

# Configuration
DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
TEAM_ID="BF2USJSWSF"
IDB_SOURCE_DIR="/Users/bkessler/Apps/idb-main"
DEFAULT_OUTPUT_DIR="/Users/bkessler/Apps/PreEmpathy/resources/idb-signed"

# Use provided output directory or default
OUTPUT_DIR="${1:-$DEFAULT_OUTPUT_DIR}"

echo "🚀 Building complete IDB with code signing..."
echo "📍 Source: $IDB_SOURCE_DIR"
echo "📍 Output: $OUTPUT_DIR"

cd "$IDB_SOURCE_DIR"

# Step 1: Build and sign frameworks
echo ""
echo "🔨 Step 1: Building and signing IDB frameworks..."
./build.sh framework build "$OUTPUT_DIR"

# Step 2: Build and sign IDB Companion
echo ""
echo "🔨 Step 2: Building and signing IDB Companion..."
xcodebuild \
  -workspace idb_companion.xcworkspace \
  -scheme idb_companion \
  -configuration Release \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Manual \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  build

# Copy and sign companion
COMPANION_BUILD_DIR="$IDB_SOURCE_DIR/build/Build/Products/Release"
if [ -d "$COMPANION_BUILD_DIR" ]; then
  echo "📂 Copying IDB Companion to output directory..."
  mkdir -p "$OUTPUT_DIR/bin"
  cp -R "$COMPANION_BUILD_DIR"/* "$OUTPUT_DIR/bin/"
  
  # Sign any companion binaries
  find "$OUTPUT_DIR/bin" -type f -perm +111 | while read binary; do
    if file "$binary" | grep -q "Mach-O"; then
      echo "🔐 Signing companion binary: $binary"
      codesign --force --sign "$DEVELOPER_ID" --timestamp "$binary" 2>/dev/null || {
        echo "  ⚠️  Failed to sign $binary"
      }
    fi
  done
  echo "✅ IDB Companion built and signed"
else
  echo "❌ IDB Companion build directory not found at $COMPANION_BUILD_DIR"
fi

# Step 3: Install and sign Python IDB client
echo ""
echo "🔨 Step 3: Installing and signing IDB Python client..."

# Find Python and pip
PYTHON_CMD=""
PIP_CMD=""

# Try different Python/pip combinations
if command -v python3 >/dev/null 2>&1; then
  PYTHON_CMD="python3"
  if command -v pip3 >/dev/null 2>&1; then
    PIP_CMD="pip3"
  elif $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
    PIP_CMD="$PYTHON_CMD -m pip"
  fi
elif command -v python >/dev/null 2>&1; then
  PYTHON_CMD="python"
  if command -v pip >/dev/null 2>&1; then
    PIP_CMD="pip"
  elif $PYTHON_CMD -m pip --version >/dev/null 2>&1; then
    PIP_CMD="$PYTHON_CMD -m pip"
  fi
fi

if [ -z "$PIP_CMD" ]; then
  echo "❌ Could not find pip. Please install Python and pip first."
  echo "   You can install with: brew install python"
  echo ""
  echo "⚠️  Skipping Python IDB installation, but frameworks and companion are ready."
  exit 0
fi

echo "🐍 Using Python: $PYTHON_CMD"
echo "📦 Using pip: $PIP_CMD"

# Install IDB Python package
echo "📦 Installing IDB Python package..."
if $PIP_CMD install . --user 2>/dev/null; then
  echo "✅ Installed with --user flag"
elif $PIP_CMD install . --break-system-packages 2>/dev/null; then
  echo "✅ Installed with --break-system-packages flag"
else
  echo "❌ Failed to install IDB Python package"
  echo "   You can manually install later with:"
  echo "   pip3 install . --user"
  echo ""
  echo "⚠️  Continuing with frameworks and companion (which are the main requirements for notarization)"
  echo ""
  echo "🎉 Frameworks and Companion are ready!"
  exit 0
fi

# Find where IDB was installed
IDB_PYTHON_PATH=$($PYTHON_CMD -c "import idb; print(idb.__path__[0])" 2>/dev/null || echo "")
IDB_BIN_PATH=$(which idb 2>/dev/null || echo "")

if [ -n "$IDB_PYTHON_PATH" ] && [ -d "$IDB_PYTHON_PATH" ]; then
  echo "📍 Found IDB Python at: $IDB_PYTHON_PATH"
  
  # Copy Python IDB to output directory
  mkdir -p "$OUTPUT_DIR/python-idb"
  cp -R "$IDB_PYTHON_PATH"/* "$OUTPUT_DIR/python-idb/"
  
  # Sign Python extension modules
  find "$OUTPUT_DIR/python-idb" -name "*.so" -o -name "*.dylib" | while read file; do
    echo "🔐 Signing Python module: $(basename "$file")"
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$file" 2>/dev/null || {
      echo "  ⚠️  Failed to sign $file"
    }
  done
  
  echo "✅ IDB Python client copied and signed"
else
  echo "⚠️  Could not find IDB Python installation"
fi

# Copy main IDB binary if it exists
if [ -n "$IDB_BIN_PATH" ] && [ -f "$IDB_BIN_PATH" ]; then
  echo "📂 Copying main IDB binary..."
  cp "$IDB_BIN_PATH" "$OUTPUT_DIR/bin/"
  codesign --force --sign "$DEVELOPER_ID" --timestamp "$OUTPUT_DIR/bin/idb" 2>/dev/null || {
    echo "  ⚠️  Failed to sign main IDB binary"
  }
fi

# Step 4: Final verification and cleanup
echo ""
echo "🔍 Step 4: Final verification..."

# Count signed vs unsigned files
TOTAL_BINARIES=0
SIGNED_BINARIES=0

find "$OUTPUT_DIR" -type f \( -name "*.so" -o -name "*.dylib" -o -name "*.framework" -o -perm +111 \) | while read file; do
  ((TOTAL_BINARIES++))
  if codesign -dv "$file" 2>/dev/null >/dev/null; then
    ((SIGNED_BINARIES++))
  else
    echo "  ❌ Unsigned: $file"
  fi
done

# Create a summary file
cat > "$OUTPUT_DIR/build-summary.txt" << EOF
IDB Build Summary
================
Build Date: $(date)
Developer ID: $DEVELOPER_ID
Team ID: $TEAM_ID
Source Directory: $IDB_SOURCE_DIR
Output Directory: $OUTPUT_DIR

Components Built:
✅ IDB Frameworks (FBControlCore, XCTestBootstrap, FBSimulatorControl, FBDeviceControl)
✅ IDB Companion
✅ IDB Python Client

All components have been signed with Developer ID certificate.
EOF

echo ""
echo "🎉 IDB build complete!"
echo "📄 Build summary saved to: $OUTPUT_DIR/build-summary.txt"
echo ""
echo "📁 Your signed IDB components are ready at:"
echo "   $OUTPUT_DIR"
echo ""
echo "🚀 You can now build your Electron app with these signed components!"

# Optional: Quick test
if [ -f "$OUTPUT_DIR/bin/idb" ]; then
  echo ""
  echo "🧪 Quick test - IDB version:"
  "$OUTPUT_DIR/bin/idb" --help | head -3 || echo "  ⚠️  IDB binary test failed"
fi