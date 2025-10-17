#!/bin/bash
set -e

# =============================================================================
# Complete IDB Rebuild and Sign Script (Following Your Proven Method)
# =============================================================================

DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
BUILD_DIR="/Users/bkessler/Apps/idb-main"
IDB_VERSION="1.1.3"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_status() { echo -e "${BLUE}🔷 $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

cd "$BUILD_DIR"

echo_status "Complete IDB Rebuild and Sign Process (Your Proven Method)"
echo "Following your original successful approach..."
echo ""

# =============================================================================
# Step 1: Environment Setup (Your Method)
# =============================================================================
setup_environment() {
    echo_status "Setting up environment (your original method)..."
    
    # Set the required environment variable
    export FB_IDB_VERSION="$IDB_VERSION"
    
    # Clean previous builds
    rm -rf build/
    rm -rf idb-env/
    rm -rf idb-bundle/
    rm -rf idb-bundle-final/
    rm -rf idb-bundle-signed-working/
    
    echo_success "Environment setup complete"
}

# =============================================================================
# Step 2: Install IDB with pip (Your Method)
# =============================================================================
install_idb() {
    echo_status "Installing IDB with pip (your original method)..."
    
    # Install with pip3.13 (which we know works)
    python3.13 -m pip install -e .
    
    # Test it works by checking if we can import it
    if python3.13 -c "import idb.cli.main; print('IDB import successful')"; then
        echo_success "IDB installation successful"
    else
        echo_error "IDB installation failed"
        exit 1
    fi
}

# =============================================================================
# Step 3: Build Companion and Frameworks (Your Method)
# =============================================================================
build_companion_frameworks() {
    echo_status "Building companion and frameworks..."
    
    # Build using xcodebuild (similar to your working build)
    echo "Building IDB companion and frameworks..."
    
    # Try the build without strict signing first (to get working binaries)
    if xcodebuild \
        -project idb_companion.xcodeproj \
        -scheme idb_companion \
        -configuration Release \
        -derivedDataPath build \
        build; then
        
        echo_success "Build completed successfully"
    else
        echo_error "Build failed - trying alternative approach..."
        
        # If build fails, try with relaxed settings
        xcodebuild \
            -project idb_companion.xcodeproj \
            -scheme idb_companion \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            build
        
        echo_warning "Built with relaxed code signing - will sign later"
    fi
    
    # Verify we have the companion binary
    COMPANION_PATH="build/Build/Products/Release/idb_companion"
    if [[ -f "$COMPANION_PATH" ]]; then
        echo_success "Companion binary found: $COMPANION_PATH"
    else
        echo_error "Companion binary not found after build"
        exit 1
    fi
    
    # Verify we have frameworks
    FRAMEWORKS_DIR="build/Build/Products/Release"
    framework_count=$(find "$FRAMEWORKS_DIR" -name "*.framework" | wc -l)
    if [[ $framework_count -gt 0 ]]; then
        echo_success "Found $framework_count frameworks"
    else
        echo_error "No frameworks found after build"
        exit 1
    fi
}

# =============================================================================
# Step 4: Create Python Environment (Your Method)
# =============================================================================
create_python_env() {
    echo_status "Creating Python environment (your original method)..."
    
    # Create virtual environment
    python3.13 -m venv idb-env
    source idb-env/bin/activate
    
    # Upgrade pip in the virtual environment
    python -m pip install --upgrade pip
    
    # Install IDB in the environment
    export FB_IDB_VERSION="$IDB_VERSION"
    python -m pip install -e .
    
    # Verify IDB script exists
    IDB_SCRIPT="idb-env/bin/idb"
    if [[ -f "$IDB_SCRIPT" ]]; then
        echo_success "IDB script created: $IDB_SCRIPT"
    else
        echo_error "IDB script not found"
        exit 1
    fi
    
    deactivate
}

# =============================================================================
# Step 5: Create Bundle with Signing (Your Method + Signing)
# =============================================================================
create_signed_bundle() {
    echo_status "Creating final working bundle with code signing..."
    
    # Set paths (your exact paths)
    COMPANION_PATH="build/Build/Products/Release/idb_companion"
    IDB_SCRIPT="idb-env/bin/idb"
    FRAMEWORKS_DIR="build/Build/Products/Release"
    
    BUNDLE_DIR="idb-bundle-signed-final"
    rm -rf "$BUNDLE_DIR"
    mkdir -p "$BUNDLE_DIR/darwin-arm64/bin"
    mkdir -p "$BUNDLE_DIR/darwin-arm64/Frameworks"
    
    echo "📦 Copying binaries..."
    cp "$COMPANION_PATH" "$BUNDLE_DIR/darwin-arm64/bin/"
    cp "$IDB_SCRIPT" "$BUNDLE_DIR/darwin-arm64/bin/"
    
    echo "📚 Copying frameworks..."
    for framework in FBControlCore.framework FBDeviceControl.framework IDBCompanionUtilities.framework FBSimulatorControl.framework XCTestBootstrap.framework IDBGRPCSwift.framework CompanionLib.framework; do
        if [[ -d "$FRAMEWORKS_DIR/$framework" ]]; then
            echo " ✅ Copying $framework"
            cp -R "$FRAMEWORKS_DIR/$framework" "$BUNDLE_DIR/darwin-arm64/Frameworks/"
        fi
    done
    
    echo "🔐 Signing all binaries..."
    
    # Sign the companion binary
    echo "Signing companion..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/bin/idb_companion"
    
    # Sign the IDB client
    echo "Signing IDB client..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/bin/idb"
    
    # Sign all framework binaries
    echo "Signing frameworks..."
    for framework in "$BUNDLE_DIR/darwin-arm64/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo "  Signing $framework_name..."
            
            # Sign all binaries within the framework
            find "$framework" -type f \( -name "*.dylib" -o -perm +111 \) | while read -r binary; do
                if file "$binary" | grep -q "Mach-O"; then
                    codesign --force --sign "$DEVELOPER_ID" \
                        --timestamp --options runtime \
                        "$binary" 2>/dev/null || true
                fi
            done
            
            # Sign the framework itself
            codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime \
                "$framework"
        fi
    done
    
    echo "📝 Creating wrapper scripts (your exact working versions)..."
    
    # Companion wrapper (your exact working version)
    cat > "$BUNDLE_DIR/darwin-arm64/idb_companion" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
exec "$DIR/bin/idb_companion" "$@"
WRAPPER_EOF

    # Client wrapper (your exact working version)
    cat > "$BUNDLE_DIR/darwin-arm64/idb" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/bin/idb" "$@"
WRAPPER_EOF

    chmod +x "$BUNDLE_DIR/darwin-arm64/idb_companion"
    chmod +x "$BUNDLE_DIR/darwin-arm64/idb"
    
    # Sign the wrapper scripts
    echo "Signing wrapper scripts..."
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/idb_companion"
    
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_DIR/darwin-arm64/idb"
    
    echo_success "Bundle created with signing"
}

# =============================================================================
# Step 6: Test Bundle (Your Method)
# =============================================================================
test_bundle() {
    echo_status "Testing final bundle..."
    
    BUNDLE_DIR="idb-bundle-signed-final"
    cd "$BUNDLE_DIR/darwin-arm64"
    
    echo "Testing companion:"
    if ./idb_companion --help >/dev/null 2>&1; then
        echo_success "Companion works!"
    else
        echo_warning "Companion test failed"
        # Show the error for debugging
        ./idb_companion --help 2>&1 | head -5
    fi
    
    echo "Testing IDB client:"
    if ./idb --help >/dev/null 2>&1; then
        echo_success "IDB client works!"
    else
        echo_warning "IDB client test failed"
        # Show the error for debugging
        ./idb --help 2>&1 | head -5
    fi
    
    # Test enhanced features (if they exist)
    echo "Testing enhanced video streaming:"
    if ./idb video-stream --help 2>/dev/null | grep -q "keyframe-interval"; then
        echo_success "Enhanced video streaming with custom parameters!"
        ./idb video-stream --help | grep -E "(fps|keyframe-interval|max-bitrate|profile|preset)" | head -5
    else
        echo " ❓ Standard video streaming"
    fi
    
    cd - >/dev/null
}

# =============================================================================
# Step 7: Create Notarization Package
# =============================================================================
create_notarization_package() {
    echo_status "Creating notarization package..."
    
    BUNDLE_DIR="idb-bundle-signed-final"
    cd "$BUNDLE_DIR"
    zip -r "../${BUNDLE_DIR}-notarization.zip" darwin-arm64/
    cd ..
    
    echo_success "Notarization package created: ${BUNDLE_DIR}-notarization.zip"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo_status "Starting Complete IDB Rebuild and Sign Process"
    echo "Using your proven working method + code signing"
    echo ""
    
    setup_environment
    install_idb
    build_companion_frameworks
    create_python_env
    create_signed_bundle
    test_bundle
    create_notarization_package
    
    echo ""
    echo_success "🎉 Complete rebuild and signing completed!"
    echo ""
    echo "📁 Signed bundle: $BUILD_DIR/idb-bundle-signed-final/"
    echo "📦 Notarization ZIP: idb-bundle-signed-final-notarization.zip"
    echo "📊 Bundle size: $(du -sh idb-bundle-signed-final | cut -f1)"
    echo ""
    echo "🚀 Ready for notarization and Electron integration!"
    echo ""
    echo "Next steps:"
    echo "1. Test: cd idb-bundle-signed-final/darwin-arm64 && ./idb --help"
    echo "2. Submit for notarization: xcrun notarytool submit idb-bundle-signed-final-notarization.zip"
    echo "3. Integrate into your Electron app"
}

main "$@"