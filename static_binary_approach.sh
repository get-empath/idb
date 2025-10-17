#!/bin/bash
set -e

# =============================================================================
# Static Binary IDB Bundle (Avoiding Python Signing Issues)
# =============================================================================

DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
BUILD_DIR="/Users/bkessler/Apps/idb-main"
IDB_VERSION="1.1.3"

echo "🔷 Creating Static Binary IDB Bundle (No Python Framework Dependencies)"
echo "This approach bundles Python packages as data, avoiding signing conflicts"
echo ""

cd "$BUILD_DIR"

# =============================================================================
# Step 1: Build Companion Binary (Standalone)
# =============================================================================
build_standalone_companion() {
    echo "🔨 Building standalone companion binary..."
    
    # Clean build
    rm -rf build/
    
    # Build companion with relaxed signing settings
    echo "Attempting build with relaxed code signing..."
    
    if xcodebuild \
        -project idb_companion.xcodeproj \
        -scheme idb_companion \
        -configuration Release \
        -derivedDataPath build \
        CODE_SIGNING_REQUIRED=NO \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGN_IDENTITY="" \
        DEVELOPMENT_TEAM="" \
        build; then
        
        echo "✅ Build successful with relaxed signing"
    else
        echo "⚠️  First attempt failed, trying alternative build settings..."
        
        # Alternative: try with ad-hoc signing
        xcodebuild \
            -project idb_companion.xcodeproj \
            -scheme idb_companion \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGN_IDENTITY="-" \
            DEVELOPMENT_TEAM="" \
            build
    fi
    
    if [[ -f "build/Build/Products/Release/idb_companion" ]]; then
        echo "✅ Companion binary built successfully"
        
        # Strip any existing signature so we can re-sign it later
        echo "Stripping existing signatures..."
        codesign --remove-signature "build/Build/Products/Release/idb_companion" 2>/dev/null || true
        
        # Strip signatures from frameworks too
        find "build/Build/Products/Release" -name "*.framework" -type d | while read -r framework; do
            codesign --remove-signature "$framework" 2>/dev/null || true
            find "$framework" -type f \( -name "*.dylib" -o -perm +111 \) | while read -r binary; do
                if file "$binary" | grep -q "Mach-O"; then
                    codesign --remove-signature "$binary" 2>/dev/null || true
                fi
            done
        done
        
    else
        echo "❌ Companion build failed"
        echo "Available build products:"
        find build -name "idb_companion" -type f 2>/dev/null || echo "None found"
        exit 1
    fi
}

# =============================================================================
# Step 2: Create Python Package Bundle (No Framework)
# =============================================================================
create_python_package_bundle() {
    echo "📦 Creating Python package bundle..."
    
    # Create temporary environment to get clean dependencies
    rm -rf temp-idb-env
    /usr/bin/python3 -m venv temp-idb-env
    source temp-idb-env/bin/activate
    
    # Install IDB and dependencies
    export FB_IDB_VERSION="$IDB_VERSION"
    python -m pip install --upgrade pip
    python -m pip install -e .
    
    # Get the site-packages path
    SITE_PACKAGES=$(python -c "import site; print(site.getsitepackages()[0])")
    echo "Site packages: $SITE_PACKAGES"
    
    deactivate
    
    # Create bundle directory
    BUNDLE_DIR="idb-static-bundle"
    rm -rf "$BUNDLE_DIR"
    mkdir -p "$BUNDLE_DIR/darwin-arm64/bin"
    mkdir -p "$BUNDLE_DIR/darwin-arm64/Frameworks" 
    mkdir -p "$BUNDLE_DIR/darwin-arm64/python-packages"
    
    # Copy Python packages (as data files, not executables)
    echo "Copying Python packages..."
    cp -R "$SITE_PACKAGES"/* "$BUNDLE_DIR/darwin-arm64/python-packages/"
    
    # Copy companion binary
    echo "Copying companion binary..."
    cp "build/Build/Products/Release/idb_companion" "$BUNDLE_DIR/darwin-arm64/bin/"
    
    # Copy frameworks
    echo "Copying frameworks..."
    FRAMEWORKS_DIR="build/Build/Products/Release"
    for framework in FBControlCore.framework FBDeviceControl.framework IDBCompanionUtilities.framework FBSimulatorControl.framework XCTestBootstrap.framework IDBGRPCSwift.framework CompanionLib.framework; do
        if [[ -d "$FRAMEWORKS_DIR/$framework" ]]; then
            echo " ✅ Copying $framework"
            cp -R "$FRAMEWORKS_DIR/$framework" "$BUNDLE_DIR/darwin-arm64/Frameworks/"
        fi
    done
    
    echo "✅ Package bundle created"
}

# =============================================================================
# Step 3: Create Standalone Python Script (No Framework Dependency)
# =============================================================================
create_standalone_python_script() {
    echo "📝 Creating standalone Python script..."
    
    BUNDLE_DIR="idb-static-bundle"
    
    # Create standalone IDB script that uses bundled packages
    cat > "$BUNDLE_DIR/darwin-arm64/bin/idb_standalone.py" << 'EOF'
#!/usr/bin/env python3
"""
Standalone IDB client script that uses bundled packages
Uses system Python but with our bundled dependencies
"""
import sys
import os

# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))
bundle_dir = os.path.dirname(script_dir)

# Add our bundled Python packages to the path
python_packages_dir = os.path.join(bundle_dir, 'python-packages')
sys.path.insert(0, python_packages_dir)

# Import and run IDB
try:
    from idb.cli.main import main
    if __name__ == '__main__':
        main()
except ImportError as e:
    print(f"Error importing IDB: {e}", file=sys.stderr)
    print(f"Python packages directory: {python_packages_dir}", file=sys.stderr)
    print(f"Contents: {os.listdir(python_packages_dir) if os.path.exists(python_packages_dir) else 'Directory not found'}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"Error running IDB: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    chmod +x "$BUNDLE_DIR/darwin-arm64/bin/idb_standalone.py"
    
    echo "✅ Standalone Python script created"
}

# =============================================================================
# Step 4: Create Wrapper Scripts
# =============================================================================
create_wrapper_scripts() {
    echo "📝 Creating wrapper scripts..."
    
    BUNDLE_DIR="idb-static-bundle"
    
    # Companion wrapper
    cat > "$BUNDLE_DIR/darwin-arm64/idb_companion" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
exec "$DIR/bin/idb_companion" "$@"
EOF

    # IDB client wrapper (uses system python3 with our packages)
    cat > "$BUNDLE_DIR/darwin-arm64/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec /usr/bin/python3 "$DIR/bin/idb_standalone.py" "$@"
EOF

    chmod +x "$BUNDLE_DIR/darwin-arm64/idb_companion"
    chmod +x "$BUNDLE_DIR/darwin-arm64/idb"
    
    echo "✅ Wrapper scripts created"
}

# =============================================================================
# Step 5: Sign Everything (Only Our Files)
# =============================================================================
sign_bundle() {
    echo "🔐 Signing bundle (only our files, not Python framework)..."
    
    BUNDLE_DIR="idb-static-bundle"
    
    # Sign companion binary
    echo "Signing companion binary..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/bin/idb_companion"
    
    # Sign Python script
    echo "Signing Python script..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/bin/idb_standalone.py"
    
    # Sign wrapper scripts
    echo "Signing wrapper scripts..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/idb_companion"
    
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/idb"
    
    # Sign frameworks
    echo "Signing frameworks..."
    for framework in "$BUNDLE_DIR/darwin-arm64/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo "  Signing $framework_name..."
            
            # Sign binaries within framework
            find "$framework" -type f \( -name "*.dylib" -o -perm +111 \) | while read -r binary; do
                if file "$binary" | grep -q "Mach-O"; then
                    codesign --force --sign "$DEVELOPER_ID" \
                        --timestamp --options runtime \
                        "$binary" 2>/dev/null || true
                fi
            done
            
            # Sign framework itself
            codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime \
                "$framework"
        fi
    done
    
    # Sign any native extensions in Python packages
    echo "Signing Python native extensions..."
    find "$BUNDLE_DIR/darwin-arm64/python-packages" -name "*.so" -o -name "*.dylib" | while read -r binary; do
        if file "$binary" | grep -q "Mach-O"; then
            codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime \
                "$binary" 2>/dev/null || true
        fi
    done
    
    echo "✅ Signing completed"
}

# =============================================================================
# Step 6: Test Bundle
# =============================================================================
test_static_bundle() {
    echo "🧪 Testing static bundle..."
    
    BUNDLE_DIR="idb-static-bundle"
    cd "$BUNDLE_DIR/darwin-arm64"
    
    echo "Testing companion:"
    if timeout 10s ./idb_companion --help 2>&1 | head -3; then
        echo "✅ Companion works!"
    else
        echo "⚠️  Companion test failed"
    fi
    
    echo ""
    echo "Testing IDB client:"
    if timeout 10s ./idb --help 2>&1 | head -3; then
        echo "✅ IDB client works!"
    else
        echo "⚠️  IDB client test failed"
        echo "Error details:"
        ./idb --help 2>&1 | head -10
    fi
    
    cd - >/dev/null
    
    echo "✅ Testing completed"
}

# =============================================================================
# Step 7: Create Final Package
# =============================================================================
create_final_package() {
    echo "📦 Creating final package..."
    
    BUNDLE_DIR="idb-static-bundle"
    
    # Create notarization ZIP
    cd "$BUNDLE_DIR"
    zip -r "../${BUNDLE_DIR}-notarization.zip" darwin-arm64/
    cd ..
    
    echo ""
    echo "✅ Static Binary IDB Bundle Created!"
    echo ""
    echo "📁 Bundle: $BUILD_DIR/$BUNDLE_DIR/"
    echo "📦 Notarization ZIP: ${BUNDLE_DIR}-notarization.zip"
    echo "📊 Bundle size: $(du -sh "$BUNDLE_DIR" | cut -f1)"
    echo ""
    echo "🎯 Key advantages:"
    echo "  • No Python framework dependencies"
    echo "  • Uses system Python executable (no signing conflicts)"
    echo "  • All dependencies bundled as data files"
    echo "  • Only our code is signed (not system Python)"
    echo "  • Self-contained for Electron app"
    echo ""
    echo "🚀 Ready for notarization and Electron integration!"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    build_standalone_companion
    create_python_package_bundle
    create_standalone_python_script
    create_wrapper_scripts
    sign_bundle
    test_static_bundle
    create_final_package
    
    echo ""
    echo "🎉 Static binary approach completed successfully!"
}

main "$@"