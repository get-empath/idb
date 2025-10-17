#!/bin/bash
# find_certificates.sh - Detect and configure the correct Developer ID certificate

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo_status() {
    echo -e "${BLUE}🔷 $1${NC}"
}

echo_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

echo_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo_error() {
    echo -e "${RED}❌ $1${NC}"
}

echo_status "Scanning for Developer ID certificates..."

# Get all code signing identities
IDENTITIES=$(security find-identity -v -p codesigning)

echo "$IDENTITIES"
echo ""

# Extract Developer ID Application certificates
DEV_ID_CERTS=$(echo "$IDENTITIES" | grep "Developer ID Application" || true)

if [[ -z "$DEV_ID_CERTS" ]]; then
    echo_error "No Developer ID Application certificates found!"
    echo ""
    echo "Available certificates:"
    echo "$IDENTITIES"
    echo ""
    echo "You need to:"
    echo "1. Download your Developer ID Application certificate from Apple Developer Portal"
    echo "2. Double-click to install it in Keychain"
    echo "3. Run this script again"
    exit 1
fi

echo_success "Found Developer ID Application certificate(s):"
echo "$DEV_ID_CERTS"
echo ""

# Extract the certificate name for your team
YOUR_CERT=$(echo "$DEV_ID_CERTS" | grep "BF2USJSWSF" | head -1)

if [[ -z "$YOUR_CERT" ]]; then
    echo_error "No certificate found for team BF2USJSWSF"
    echo "Available Developer ID certificates:"
    echo "$DEV_ID_CERTS"
    exit 1
fi

# Extract just the certificate name (between quotes)
CERT_NAME=$(echo "$YOUR_CERT" | sed 's/.*"\(.*\)".*/\1/')

echo_success "Using certificate: $CERT_NAME"

# Create the corrected build script
cat > build_signed_idb_corrected.sh << EOF
#!/bin/bash
set -e

# =============================================================================
# IDB Code Signing Build Script for macOS Notarization (CORRECTED)
# =============================================================================

# Configuration (CORRECTED CERTIFICATE NAME)
DEVELOPER_ID="$CERT_NAME"
TEAM_ID="BF2USJSWSF"
IDB_VERSION="1.1.3"
BUILD_DIR="/Users/bkessler/Apps/idb-main"
BUNDLE_NAME="idb-bundle-signed"
TIMESTAMP_URL="http://timestamp.apple.com/ts01"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_status() {
    echo -e "\${BLUE}🔷 \$1\${NC}"
}

echo_success() {
    echo -e "\${GREEN}✅ \$1\${NC}"
}

echo_warning() {
    echo -e "\${YELLOW}⚠️  \$1\${NC}"
}

echo_error() {
    echo -e "\${RED}❌ \$1\${NC}"
}

# =============================================================================
# Step 1: Environment Setup and Verification
# =============================================================================
setup_environment() {
    echo_status "Setting up build environment..."
    
    cd "\$BUILD_DIR"
    export FB_IDB_VERSION="\$IDB_VERSION"
    
    # Verify Developer ID certificate
    if ! security find-identity -v -p codesigning | grep -q "\$DEVELOPER_ID"; then
        echo_error "Developer ID certificate not found: \$DEVELOPER_ID"
        echo "Available certificates:"
        security find-identity -v -p codesigning
        exit 1
    fi
    echo_success "Developer ID certificate verified"
    
    # Clean previous builds
    rm -rf "\$BUNDLE_NAME"
    rm -rf build/
    rm -rf dist/
    rm -rf *.egg-info/
    
    echo_success "Environment setup complete"
}

# =============================================================================
# Step 2: Build IDB Companion with Code Signing
# =============================================================================
build_companion() {
    echo_status "Building IDB Companion with code signing..."
    
    # Build companion using xcodebuild with signing
    xcodebuild \\
        -project idb_companion.xcodeproj \\
        -scheme idb_companion \\
        -configuration Release \\
        -derivedDataPath build \\
        CODE_SIGN_IDENTITY="\$DEVELOPER_ID" \\
        DEVELOPMENT_TEAM="\$TEAM_ID" \\
        CODE_SIGN_STYLE=Manual \\
        OTHER_CODE_SIGN_FLAGS="--timestamp --options=runtime" \\
        build
    
    # Verify companion binary is signed
    COMPANION_PATH="build/Build/Products/Release/idb_companion"
    if codesign -dv --verbose=4 "\$COMPANION_PATH" 2>&1 | grep -q "\$DEVELOPER_ID"; then
        echo_success "Companion binary signed successfully"
    else
        echo_error "Companion binary signing failed"
        exit 1
    fi
}

# =============================================================================
# Step 3: Build and Sign Frameworks
# =============================================================================
sign_frameworks() {
    echo_status "Signing all frameworks..."
    
    FRAMEWORKS_DIR="build/Build/Products/Release"
    
    for framework in FBControlCore.framework FBDeviceControl.framework \\
                    IDBCompanionUtilities.framework FBSimulatorControl.framework \\
                    XCTestBootstrap.framework IDBGRPCSwift.framework \\
                    CompanionLib.framework; do
        
        if [[ -d "\$FRAMEWORKS_DIR/\$framework" ]]; then
            echo_status "Signing \$framework..."
            
            # Sign all binaries within the framework
            find "\$FRAMEWORKS_DIR/\$framework" -type f \\( -name "*.dylib" -o -perm +111 \\) | while read -r binary; do
                if file "\$binary" | grep -q "Mach-O"; then
                    codesign --force --sign "\$DEVELOPER_ID" \\
                        --timestamp \\
                        --options runtime \\
                        "\$binary"
                fi
            done
            
            # Sign the framework itself
            codesign --force --sign "\$DEVELOPER_ID" \\
                --timestamp \\
                --options runtime \\
                "\$FRAMEWORKS_DIR/\$framework"
            
            echo_success "\$framework signed"
        fi
    done
}

# =============================================================================
# Step 4: Create Python Virtual Environment with Signing
# =============================================================================
create_python_environment() {
    echo_status "Creating Python virtual environment..."
    
    # Create clean virtual environment
    rm -rf idb-env-signed
    python3.13 -m venv idb-env-signed
    source idb-env-signed/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip setuptools wheel
    
    # Install IDB with all dependencies
    pip install -e .
    
    echo_success "Python environment created"
}

# =============================================================================
# Step 5: Sign Python Binaries and Extensions
# =============================================================================
sign_python_components() {
    echo_status "Signing Python components..."
    
    source idb-env-signed/bin/activate
    PYTHON_ENV="idb-env-signed"
    
    # Find and sign all Python extensions (.so files)
    echo_status "Signing Python extensions (.so files)..."
    find "\$PYTHON_ENV" -name "*.so" | while read -r so_file; do
        if file "\$so_file" | grep -q "Mach-O"; then
            echo "  Signing: \$(basename "\$so_file")"
            codesign --force --sign "\$DEVELOPER_ID" \\
                --timestamp \\
                --options runtime \\
                "\$so_file"
        fi
    done
    
    # Find and sign all dylib files
    echo_status "Signing dynamic libraries (.dylib files)..."
    find "\$PYTHON_ENV" -name "*.dylib" | while read -r dylib_file; do
        echo "  Signing: \$(basename "\$dylib_file")"
        codesign --force --sign "\$DEVELOPER_ID" \\
            --timestamp \\
            --options runtime \\
            "\$dylib_file"
    done
    
    # Sign Python executable
    echo_status "Signing Python executable..."
    PYTHON_BIN="\$PYTHON_ENV/bin/python3.13"
    if [[ -f "\$PYTHON_BIN" ]]; then
        codesign --force --sign "\$DEVELOPER_ID" \\
            --timestamp \\
            --options runtime \\
            "\$PYTHON_BIN"
        echo_success "Python executable signed"
    fi
    
    # Sign IDB script
    echo_status "Signing IDB script..."
    IDB_SCRIPT="\$PYTHON_ENV/bin/idb"
    if [[ -f "\$IDB_SCRIPT" ]]; then
        # Make sure it's executable
        chmod +x "\$IDB_SCRIPT"
        # Sign it
        codesign --force --sign "\$DEVELOPER_ID" \\
            --timestamp \\
            --options runtime \\
            "\$IDB_SCRIPT"
        echo_success "IDB script signed"
    fi
    
    echo_success "All Python components signed"
}

# =============================================================================
# Step 6: Create Signed Bundle
# =============================================================================
create_signed_bundle() {
    echo_status "Creating signed bundle..."
    
    mkdir -p "\$BUNDLE_NAME/darwin-arm64/bin"
    mkdir -p "\$BUNDLE_NAME/darwin-arm64/Frameworks"
    mkdir -p "\$BUNDLE_NAME/darwin-arm64/lib"
    
    # Copy signed companion
    cp "build/Build/Products/Release/idb_companion" "\$BUNDLE_NAME/darwin-arm64/bin/"
    
    # Copy signed IDB client
    cp "idb-env-signed/bin/idb" "\$BUNDLE_NAME/darwin-arm64/bin/"
    
    # Copy signed frameworks
    FRAMEWORKS_DIR="build/Build/Products/Release"
    for framework in FBControlCore.framework FBDeviceControl.framework \\
                    IDBCompanionUtilities.framework FBSimulatorControl.framework \\
                    XCTestBootstrap.framework IDBGRPCSwift.framework \\
                    CompanionLib.framework; do
        if [[ -d "\$FRAMEWORKS_DIR/\$framework" ]]; then
            cp -R "\$FRAMEWORKS_DIR/\$framework" "\$BUNDLE_NAME/darwin-arm64/Frameworks/"
        fi
    done
    
    # Create wrapper scripts
    create_wrapper_scripts
    
    echo_success "Signed bundle created"
}

# =============================================================================
# Step 7: Create Wrapper Scripts
# =============================================================================
create_wrapper_scripts() {
    echo_status "Creating wrapper scripts..."
    
    # Companion wrapper
    cat > "\$BUNDLE_NAME/darwin-arm64/idb_companion" << 'WRAPPER_EOF'
#!/bin/bash
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="\$DIR/Frameworks:\$DYLD_FRAMEWORK_PATH"
exec "\$DIR/bin/idb_companion" "\$@"
WRAPPER_EOF

    # Client wrapper
    cat > "\$BUNDLE_NAME/darwin-arm64/idb" << 'WRAPPER_EOF'
#!/bin/bash
DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$DIR/bin/idb" "\$@"
WRAPPER_EOF

    # Make wrappers executable
    chmod +x "\$BUNDLE_NAME/darwin-arm64/idb_companion"
    chmod +x "\$BUNDLE_NAME/darwin-arm64/idb"
    
    # Sign the wrapper scripts
    codesign --force --sign "\$DEVELOPER_ID" \\
        --timestamp \\
        --options runtime \\
        "\$BUNDLE_NAME/darwin-arm64/idb_companion"
    
    codesign --force --sign "\$DEVELOPER_ID" \\
        --timestamp \\
        --options runtime \\
        "\$BUNDLE_NAME/darwin-arm64/idb"
    
    echo_success "Wrapper scripts created and signed"
}

# =============================================================================
# Step 8: Verification
# =============================================================================
verify_signatures() {
    echo_status "Verifying all signatures..."
    
    local failed=0
    
    # Check all binaries in the bundle
    find "\$BUNDLE_NAME" -type f \\( -perm +111 -o -name "*.dylib" -o -name "*.so" \\) | while read -r file; do
        if file "\$file" | grep -q "Mach-O"; then
            if codesign -dv --verbose=4 "\$file" 2>&1 | grep -q "\$DEVELOPER_ID"; then
                echo "✅ \$(basename "\$file")"
            else
                echo "❌ \$(basename "\$file") - NOT SIGNED"
                failed=\$((failed + 1))
            fi
        fi
    done
    
    # Test functionality
    echo_status "Testing bundle functionality..."
    cd "\$BUNDLE_NAME/darwin-arm64"
    
    if ./idb_companion --help >/dev/null 2>&1; then
        echo_success "Companion functionality verified"
    else
        echo_error "Companion functionality test failed"
        failed=\$((failed + 1))
    fi
    
    if ./idb --help >/dev/null 2>&1; then
        echo_success "IDB client functionality verified"
    else
        echo_error "IDB client functionality test failed"
        failed=\$((failed + 1))
    fi
    
    cd - >/dev/null
    
    if [[ \$failed -eq 0 ]]; then
        echo_success "All signatures verified successfully!"
        return 0
    else
        echo_error "\$failed signature verification failures"
        return 1
    fi
}

# =============================================================================
# Step 9: Create Notarization Package
# =============================================================================
create_notarization_package() {
    echo_status "Creating notarization package..."
    
    # Create a ZIP for notarization
    cd "\$BUNDLE_NAME"
    zip -r "../\${BUNDLE_NAME}-notarization.zip" darwin-arm64/
    cd ..
    
    echo_success "Notarization package created: \${BUNDLE_NAME}-notarization.zip"
    echo_warning "To notarize, run:"
    echo "xcrun notarytool submit \${BUNDLE_NAME}-notarization.zip --keychain-profile \"AC_PASSWORD\" --wait"
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo_status "Starting IDB Code Signing Build Process"
    echo "Developer ID: \$DEVELOPER_ID"
    echo "Team ID: \$TEAM_ID"
    echo "IDB Version: \$IDB_VERSION"
    echo ""
    
    setup_environment
    build_companion
    sign_frameworks
    create_python_environment
    sign_python_components
    create_signed_bundle
    
    if verify_signatures; then
        create_notarization_package
        
        echo ""
        echo_success "🎉 IDB bundle with code signing completed successfully!"
        echo ""
        echo "📁 Bundle location: \$BUILD_DIR/\$BUNDLE_NAME/"
        echo "📊 Bundle size: \$(du -sh "\$BUNDLE_NAME" | cut -f1)"
        echo ""
        echo "🚀 Ready for Electron integration!"
        echo "   Companion: \$BUNDLE_NAME/darwin-arm64/idb_companion"
        echo "   Client: \$BUNDLE_NAME/darwin-arm64/idb"
        echo ""
        echo "📦 Notarization package: \${BUNDLE_NAME}-notarization.zip"
        echo ""
        echo "Next steps:"
        echo "1. Submit for notarization using the ZIP file"
        echo "2. After notarization approval, staple the ticket"
        echo "3. Integrate into your Electron app"
        
    else
        echo_error "Build completed with signature verification failures"
        exit 1
    fi
}

# Run main function
main "\$@"
EOF

chmod +x build_signed_idb_corrected.sh

echo ""
echo_success "✅ Created corrected build script: build_signed_idb_corrected.sh"
echo ""
echo "📋 Summary:"
echo "  Certificate: $CERT_NAME"
echo "  Team ID: BF2USJSWSF"
echo ""
echo "🚀 Next steps:"
echo "1. cd /Users/bkessler/Apps/idb-main"
echo "2. ./build_signed_idb_corrected.sh"
echo ""
echo "The script will automatically use the correct certificate name."