#!/bin/bash
set -e

# =============================================================================
# Simple IDB Re-signing Script - Works with existing binaries
# =============================================================================

DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
TEAM_ID="BF2USJSWSF"
BUILD_DIR="/Users/bkessler/Apps/idb-main"
BUNDLE_NAME="idb-bundle-signed"

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

echo_status "Simple IDB Re-signing Process"
echo "Looking for existing IDB components..."

# =============================================================================
# Step 1: Find existing IDB components
# =============================================================================
find_idb_components() {
    echo_status "Scanning for IDB components..."
    
    # Look for companion binary
    COMPANION_BINARY=""
    for path in \
        "build/Build/Products/Release/idb_companion" \
        "idb-bundle/darwin-arm64/bin/idb_companion" \
        "idb-bundle/darwin-arm64/idb_companion" \
        "build/idb_companion" \
        "idb_companion"; do
        
        if [[ -f "$path" ]]; then
            echo_success "Found companion binary: $path"
            COMPANION_BINARY="$path"
            break
        fi
    done
    
    # Look for IDB client
    IDB_CLIENT=""
    for path in \
        "idb-env/bin/idb" \
        "idb-bundle/darwin-arm64/bin/idb" \
        "idb-bundle/darwin-arm64/idb" \
        "build/idb" \
        "idb"; do
        
        if [[ -f "$path" ]]; then
            echo_success "Found IDB client: $path"
            IDB_CLIENT="$path"
            break
        fi
    done
    
    # Look for frameworks
    FRAMEWORKS_DIR=""
    for path in \
        "build/Build/Products/Release" \
        "idb-bundle/darwin-arm64/Frameworks" \
        "build/Frameworks" \
        "Frameworks"; do
        
        if [[ -d "$path" ]] && [[ -n "$(find "$path" -name "*.framework" 2>/dev/null)" ]]; then
            echo_success "Found frameworks directory: $path"
            FRAMEWORKS_DIR="$path"
            break
        fi
    done
    
    echo ""
    echo "📋 Component summary:"
    echo "Companion: ${COMPANION_BINARY:-❌ Not found}"
    echo "Client: ${IDB_CLIENT:-❌ Not found}"
    echo "Frameworks: ${FRAMEWORKS_DIR:-❌ Not found}"
}

# =============================================================================
# Step 2: Create Python environment with IDB
# =============================================================================
create_fresh_python_idb() {
    echo_status "Creating fresh Python IDB installation..."
    
    # Remove old environment
    rm -rf idb-env-signed
    
    # Create new environment
    python3.13 -m venv idb-env-signed
    source idb-env-signed/bin/activate
    
    # Install IDB
    export FB_IDB_VERSION="1.1.3"
    pip install --upgrade pip setuptools wheel
    pip install -e .
    
    # Update IDB_CLIENT to point to new installation
    IDB_CLIENT="idb-env-signed/bin/idb"
    echo_success "Fresh Python IDB created: $IDB_CLIENT"
}

# =============================================================================
# Step 3: Build minimal companion if needed
# =============================================================================
build_minimal_companion() {
    if [[ -z "$COMPANION_BINARY" ]]; then
        echo_status "No companion found, attempting minimal build..."
        
        # Try a simple build without strict signing requirements
        if xcodebuild \
            -project idb_companion.xcodeproj \
            -scheme idb_companion \
            -configuration Release \
            -derivedDataPath build \
            CODE_SIGNING_REQUIRED=NO \
            CODE_SIGN_IDENTITY="" \
            build 2>/dev/null; then
            
            COMPANION_BINARY="build/Build/Products/Release/idb_companion"
            echo_success "Minimal companion built: $COMPANION_BINARY"
        else
            echo_error "Could not build companion binary"
            return 1
        fi
    fi
}

# =============================================================================
# Step 4: Sign everything
# =============================================================================
sign_binary() {
    local binary="$1"
    local name="$2"
    
    if [[ -f "$binary" ]]; then
        echo_status "Signing $name..."
        
        # Make sure it's executable
        chmod +x "$binary"
        
        # Sign it
        if codesign --force --sign "$DEVELOPER_ID" \
            --timestamp \
            --options runtime \
            "$binary" 2>/dev/null; then
            echo_success "$name signed successfully"
            return 0
        else
            echo_warning "$name signing failed"
            return 1
        fi
    else
        echo_error "$name binary not found: $binary"
        return 1
    fi
}

sign_all_components() {
    echo_status "Signing all components..."
    
    local signed_count=0
    local total_count=0
    
    # Sign companion
    if [[ -n "$COMPANION_BINARY" ]]; then
        total_count=$((total_count + 1))
        if sign_binary "$COMPANION_BINARY" "Companion"; then
            signed_count=$((signed_count + 1))
        fi
    fi
    
    # Sign IDB client
    if [[ -n "$IDB_CLIENT" ]]; then
        total_count=$((total_count + 1))
        if sign_binary "$IDB_CLIENT" "IDB Client"; then
            signed_count=$((signed_count + 1))
        fi
    fi
    
    # Sign Python components in the environment
    if [[ -d "idb-env-signed" ]]; then
        echo_status "Signing Python components..."
        
        # Sign .so files
        find idb-env-signed -name "*.so" -type f | while read -r so_file; do
            if file "$so_file" | grep -q "Mach-O"; then
                total_count=$((total_count + 1))
                if codesign --force --sign "$DEVELOPER_ID" \
                    --timestamp --options runtime "$so_file" 2>/dev/null; then
                    signed_count=$((signed_count + 1))
                    echo "  ✅ $(basename "$so_file")"
                else
                    echo "  ⚠️  $(basename "$so_file")"
                fi
            fi
        done
        
        # Sign .dylib files
        find idb-env-signed -name "*.dylib" -type f | while read -r dylib_file; do
            total_count=$((total_count + 1))
            if codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime "$dylib_file" 2>/dev/null; then
                signed_count=$((signed_count + 1))
                echo "  ✅ $(basename "$dylib_file")"
            else
                echo "  ⚠️  $(basename "$dylib_file")"
            fi
        done
        
        # Sign Python executable
        if [[ -f "idb-env-signed/bin/python3.13" ]]; then
            total_count=$((total_count + 1))
            if sign_binary "idb-env-signed/bin/python3.13" "Python executable"; then
                signed_count=$((signed_count + 1))
            fi
        fi
    fi
    
    # Sign frameworks
    if [[ -n "$FRAMEWORKS_DIR" ]]; then
        echo_status "Signing frameworks..."
        
        find "$FRAMEWORKS_DIR" -name "*.framework" -type d | while read -r framework; do
            framework_name=$(basename "$framework")
            echo_status "Processing $framework_name..."
            
            # Sign all binaries in framework
            find "$framework" -type f \( -name "*.dylib" -o -perm +111 \) | while read -r binary; do
                if file "$binary" | grep -q "Mach-O"; then
                    if codesign --force --sign "$DEVELOPER_ID" \
                        --timestamp --options runtime "$binary" 2>/dev/null; then
                        echo "    ✅ $(basename "$binary")"
                    else
                        echo "    ⚠️  $(basename "$binary")"
                    fi
                fi
            done
            
            # Sign the framework itself
            if codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime "$framework" 2>/dev/null; then
                echo "  ✅ $framework_name framework"
            else
                echo "  ⚠️  $framework_name framework"
            fi
        done
    fi
    
    echo_success "Component signing completed"
}

# =============================================================================
# Step 5: Create final bundle
# =============================================================================
create_final_bundle() {
    echo_status "Creating final signed bundle..."
    
    rm -rf "$BUNDLE_NAME"
    mkdir -p "$BUNDLE_NAME/darwin-arm64/bin"
    mkdir -p "$BUNDLE_NAME/darwin-arm64/Frameworks"
    
    # Copy companion
    if [[ -n "$COMPANION_BINARY" ]] && [[ -f "$COMPANION_BINARY" ]]; then
        cp "$COMPANION_BINARY" "$BUNDLE_NAME/darwin-arm64/bin/"
        echo_success "Copied companion binary"
    fi
    
    # Copy IDB client
    if [[ -n "$IDB_CLIENT" ]] && [[ -f "$IDB_CLIENT" ]]; then
        cp "$IDB_CLIENT" "$BUNDLE_NAME/darwin-arm64/bin/"
        echo_success "Copied IDB client"
    fi
    
    # Copy frameworks
    if [[ -n "$FRAMEWORKS_DIR" ]]; then
        find "$FRAMEWORKS_DIR" -name "*.framework" -type d | while read -r framework; do
            cp -R "$framework" "$BUNDLE_NAME/darwin-arm64/Frameworks/"
            echo "  Copied $(basename "$framework")"
        done
        echo_success "Copied frameworks"
    fi
    
    # Create wrapper scripts
    cat > "$BUNDLE_NAME/darwin-arm64/idb_companion" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
exec "$DIR/bin/idb_companion" "$@"
EOF

    cat > "$BUNDLE_NAME/darwin-arm64/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/bin/idb" "$@"
EOF

    chmod +x "$BUNDLE_NAME/darwin-arm64/idb_companion"
    chmod +x "$BUNDLE_NAME/darwin-arm64/idb"
    
    # Sign wrapper scripts
    sign_binary "$BUNDLE_NAME/darwin-arm64/idb_companion" "Companion wrapper"
    sign_binary "$BUNDLE_NAME/darwin-arm64/idb" "IDB wrapper"
    
    echo_success "Final bundle created"
}

# =============================================================================
# Step 6: Test the bundle
# =============================================================================
test_bundle() {
    echo_status "Testing the signed bundle..."
    
    cd "$BUNDLE_NAME/darwin-arm64"
    
    # Test companion
    if [[ -f "idb_companion" ]]; then
        echo -n "Testing companion: "
        if timeout 5s ./idb_companion --help >/dev/null 2>&1; then
            echo_success "Working!"
        else
            echo_warning "Test failed (but binary exists)"
        fi
        
        # Check signature
        if codesign -dv --verbose=4 "idb_companion" 2>&1 | grep -q "$DEVELOPER_ID"; then
            echo_success "Companion signature verified"
        else
            echo_warning "Companion signature issue"
        fi
    fi
    
    # Test client
    if [[ -f "idb" ]]; then
        echo -n "Testing IDB client: "
        if timeout 5s ./idb --help >/dev/null 2>&1; then
            echo_success "Working!"
        else
            echo_warning "Test failed (but binary exists)"
        fi
        
        # Check signature
        if codesign -dv --verbose=4 "idb" 2>&1 | grep -q "$DEVELOPER_ID"; then
            echo_success "IDB client signature verified"
        else
            echo_warning "IDB client signature issue"
        fi
    fi
    
    cd - >/dev/null
}

# =============================================================================
# Main execution
# =============================================================================
main() {
    echo_status "Starting Simple IDB Re-signing Process"
    echo ""
    
    find_idb_components
    
    # Create fresh Python IDB installation
    create_fresh_python_idb
    
    # Try to build companion if we don't have one
    if [[ -z "$COMPANION_BINARY" ]]; then
        build_minimal_companion
    fi
    
    # Sign everything
    sign_all_components
    
    # Create final bundle
    create_final_bundle
    
    # Test the bundle
    test_bundle
    
    # Create notarization package
    cd "$BUNDLE_NAME"
    zip -r "../${BUNDLE_NAME}-notarization.zip" darwin-arm64/
    cd ..
    
    echo ""
    echo_success "🎉 Simple IDB re-signing completed!"
    echo ""
    echo "📁 Bundle: $BUILD_DIR/$BUNDLE_NAME/"
    echo "📦 Notarization ZIP: ${BUNDLE_NAME}-notarization.zip"
    echo "📊 Bundle size: $(du -sh "$BUNDLE_NAME" | cut -f1)"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Test: cd $BUNDLE_NAME/darwin-arm64 && ./idb --help"
    echo "2. Submit for notarization: xcrun notarytool submit ${BUNDLE_NAME}-notarization.zip"
    echo "3. Integrate into your Electron app"
}

main "$@"