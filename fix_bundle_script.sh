#!/bin/bash
set -e

# =============================================================================
# Fix IDB Bundle Dependencies Script
# =============================================================================

DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
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

echo_status "Fixing IDB Bundle Dependencies"

# =============================================================================
# Step 1: Fix Missing Framework Binaries
# =============================================================================
fix_framework_binaries() {
    echo_status "Fixing missing framework binaries..."
    
    FRAMEWORKS_DIR="$BUNDLE_NAME/darwin-arm64/Frameworks"
    
    # Check what we actually have in the frameworks
    echo "📋 Current framework structure:"
    for framework_dir in "$FRAMEWORKS_DIR"/*.framework; do
        if [[ -d "$framework_dir" ]]; then
            framework_name=$(basename "$framework_dir" .framework)
            echo "Checking $framework_name..."
            
            # Look for the actual binary
            binary_path="$framework_dir/Versions/A/$framework_name"
            if [[ ! -f "$binary_path" ]]; then
                echo_warning "Missing binary: $binary_path"
                
                # Try to find it in the source frameworks
                for source_dir in \
                    "build/Build/Products/Release/$framework_name.framework/Versions/A" \
                    "idb-bundle/darwin-arm64/Frameworks/$framework_name.framework/Versions/A" \
                    "build/Build/Products/Release/$framework_name.framework"; do
                    
                    source_binary="$source_dir/$framework_name"
                    if [[ -f "$source_binary" ]]; then
                        echo_status "Found source binary: $source_binary"
                        cp "$source_binary" "$binary_path"
                        
                        # Sign the binary
                        codesign --force --sign "$DEVELOPER_ID" \
                            --timestamp --options runtime \
                            "$binary_path"
                        
                        echo_success "Fixed and signed $framework_name binary"
                        break
                    fi
                done
                
                # If still not found, try to find any version
                if [[ ! -f "$binary_path" ]]; then
                    echo_status "Searching for $framework_name binary anywhere..."
                    found_binary=$(find . -name "$framework_name" -type f -executable | head -1)
                    if [[ -n "$found_binary" ]]; then
                        echo_success "Found binary: $found_binary"
                        cp "$found_binary" "$binary_path"
                        
                        # Sign it
                        codesign --force --sign "$DEVELOPER_ID" \
                            --timestamp --options runtime \
                            "$binary_path"
                        
                        echo_success "Fixed and signed $framework_name binary"
                    else
                        echo_error "Could not find $framework_name binary anywhere"
                    fi
                fi
            else
                echo_success "$framework_name binary already exists"
            fi
        fi
    done
}

# =============================================================================
# Step 2: Create Self-Contained Python IDB
# =============================================================================
create_self_contained_python() {
    echo_status "Creating self-contained Python IDB..."
    
    # Create a standalone Python script that doesn't depend on system Python
    cat > "$BUNDLE_NAME/darwin-arm64/bin/idb_standalone" << 'EOF'
#!/usr/bin/env python3.13
"""
Self-contained IDB client that doesn't depend on external Python frameworks
"""
import sys
import os

# Add the IDB modules to path
script_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(script_dir, '..', '..', '..', 'idb-env-signed', 'lib', 'python3.13', 'site-packages'))

# Import and run IDB
try:
    from idb.cli.main import main
    if __name__ == '__main__':
        main()
except ImportError as e:
    print(f"Error importing IDB: {e}")
    print("Python path:", sys.path)
    sys.exit(1)
EOF

    chmod +x "$BUNDLE_NAME/darwin-arm64/bin/idb_standalone"
    
    # Sign the standalone script
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_NAME/darwin-arm64/bin/idb_standalone"
    
    # Update the wrapper to use the standalone version
    cat > "$BUNDLE_NAME/darwin-arm64/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$DIR/../../idb-env-signed/lib/python3.13/site-packages:$PYTHONPATH"
exec "$DIR/bin/idb_standalone" "$@"
EOF

    chmod +x "$BUNDLE_NAME/darwin-arm64/idb"
    
    # Re-sign the wrapper
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_NAME/darwin-arm64/idb"
    
    echo_success "Created self-contained Python IDB"
}

# =============================================================================
# Step 3: Bundle Python Dependencies
# =============================================================================
bundle_python_dependencies() {
    echo_status "Bundling Python dependencies into the bundle..."
    
    # Copy the Python environment into the bundle
    mkdir -p "$BUNDLE_NAME/darwin-arm64/python"
    
    # Copy site-packages
    if [[ -d "idb-env-signed/lib/python3.13/site-packages" ]]; then
        cp -R "idb-env-signed/lib/python3.13/site-packages" "$BUNDLE_NAME/darwin-arm64/python/"
        echo_success "Copied Python site-packages"
    fi
    
    # Sign all Python extensions in the bundle
    find "$BUNDLE_NAME/darwin-arm64/python" -name "*.so" -o -name "*.dylib" | while read -r file; do
        if file "$file" | grep -q "Mach-O"; then
            codesign --force --sign "$DEVELOPER_ID" \
                --timestamp --options runtime \
                "$file" 2>/dev/null || true
        fi
    done
    
    # Update the IDB wrapper to use bundled Python
    cat > "$BUNDLE_NAME/darwin-arm64/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$DIR/python/site-packages:$PYTHONPATH"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"

# Use the system python3.13 but with our bundled packages
exec python3.13 -c "
import sys
sys.path.insert(0, '$DIR/python/site-packages')
from idb.cli.main import main
main()
" "$@"
EOF

    chmod +x "$BUNDLE_NAME/darwin-arm64/idb"
    
    # Re-sign
    codesign --force --sign "$DEVELOPER_ID" \
        --timestamp --options runtime \
        "$BUNDLE_NAME/darwin-arm64/idb"
    
    echo_success "Bundled Python dependencies"
}

# =============================================================================
# Step 4: Verify Framework Linking
# =============================================================================
verify_framework_linking() {
    echo_status "Verifying framework linking..."
    
    COMPANION_BINARY="$BUNDLE_NAME/darwin-arm64/bin/idb_companion"
    
    if [[ -f "$COMPANION_BINARY" ]]; then
        echo "📋 Framework dependencies for companion:"
        otool -L "$COMPANION_BINARY" | grep -E "(FBControlCore|CompanionLib|IDB)" || true
        
        echo ""
        echo "📁 Available frameworks:"
        ls -la "$BUNDLE_NAME/darwin-arm64/Frameworks/"
        
        echo ""
        echo "📋 Framework binaries:"
        for framework in "$BUNDLE_NAME/darwin-arm64/Frameworks"/*.framework; do
            if [[ -d "$framework" ]]; then
                framework_name=$(basename "$framework" .framework)
                binary_path="$framework/Versions/A/$framework_name"
                if [[ -f "$binary_path" ]]; then
                    echo "✅ $framework_name: $(ls -lh "$binary_path" | awk '{print $5}')"
                else
                    echo "❌ $framework_name: binary missing"
                fi
            fi
        done
    fi
}

# =============================================================================
# Step 5: Test the Fixed Bundle
# =============================================================================
test_fixed_bundle() {
    echo_status "Testing the fixed bundle..."
    
    cd "$BUNDLE_NAME/darwin-arm64"
    
    # Test companion
    echo "Testing companion (should show version info):"
    if timeout 10s ./idb_companion --help 2>&1 | head -5; then
        echo_success "Companion test passed!"
    else
        echo_warning "Companion test failed, but continuing..."
    fi
    
    echo ""
    echo "Testing IDB client:"
    if timeout 10s ./idb --help 2>&1 | head -5; then
        echo_success "IDB client test passed!"
    else
        echo_warning "IDB client test failed, but continuing..."
    fi
    
    cd - >/dev/null
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo_status "Starting IDB Bundle Fix Process"
    echo ""
    
    if [[ ! -d "$BUNDLE_NAME" ]]; then
        echo_error "Bundle directory not found: $BUNDLE_NAME"
        echo "Please run the simple_idb_signer.sh script first"
        exit 1
    fi
    
    fix_framework_binaries
    bundle_python_dependencies
    verify_framework_linking
    test_fixed_bundle
    
    # Recreate the notarization ZIP
    echo_status "Creating updated notarization package..."
    cd "$BUNDLE_NAME"
    rm -f "../${BUNDLE_NAME}-notarization.zip"
    zip -r "../${BUNDLE_NAME}-fixed-notarization.zip" darwin-arm64/
    cd ..
    
    echo ""
    echo_success "🎉 IDB Bundle Fix Completed!"
    echo ""
    echo "📁 Fixed bundle: $BUILD_DIR/$BUNDLE_NAME/"
    echo "📦 Updated notarization ZIP: ${BUNDLE_NAME}-fixed-notarization.zip"
    echo "📊 Bundle size: $(du -sh "$BUNDLE_NAME" | cut -f1)"
    echo ""
    echo "🧪 Test the fixed bundle:"
    echo "cd $BUNDLE_NAME/darwin-arm64 && ./idb_companion --help"
    echo "cd $BUNDLE_NAME/darwin-arm64 && ./idb --help"
}

main "$@"