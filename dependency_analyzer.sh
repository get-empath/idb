#!/bin/bash

# IDB Dependency Analyzer
# Analyzes library dependencies for IDB binaries

set -e

COMPANION_PATH="build/bin/idb_companion"
PYTHON_BINARY="dist/idb-cli"  # After PyInstaller build

echo "=== IDB Dependency Analysis ==="

# Function to analyze binary dependencies
analyze_binary() {
    local binary_path=$1
    local binary_name=$(basename "$binary_path")
    
    echo ""
    echo "--- Analyzing $binary_name ---"
    
    if [[ ! -f "$binary_path" ]]; then
        echo "❌ Binary not found: $binary_path"
        return 1
    fi
    
    echo "✅ Binary exists: $binary_path"
    
    # Get file info
    echo "📄 File info:"
    file "$binary_path"
    
    # Check library dependencies
    echo ""
    echo "📚 Library dependencies:"
    otool -L "$binary_path" | while read line; do
        if [[ $line =~ ^[[:space:]]*(/.*\.dylib) ]]; then
            lib_path="${BASH_REMATCH[1]}"
            lib_name=$(basename "$lib_path")
            
            # Check if library exists
            if [[ -f "$lib_path" ]]; then
                echo "  ✅ $lib_name -> $lib_path"
            else
                echo "  ❌ $lib_name -> $lib_path (MISSING)"
            fi
        elif [[ $line =~ ^[[:space:]]*(@.*\.dylib) ]]; then
            # Framework or system library
            echo "  📱 ${BASH_REMATCH[1]} (system/framework)"
        fi
    done
    
    # Check for Swift dependencies specifically
    echo ""
    echo "🔍 Swift-specific dependencies:"
    otool -L "$binary_path" | grep -i swift || echo "  No Swift dependencies found"
    
    # Check code signing
    echo ""
    echo "🔐 Code signing status:"
    codesign -v "$binary_path" 2>&1 && echo "  ✅ Valid signature" || echo "  ⚠️  Not signed or invalid"
    
    # Check architecture
    echo ""
    echo "🏗️  Architecture:"
    lipo -archs "$binary_path" 2>/dev/null || echo "  Single architecture binary"
    
    return 0
}

# Function to create a bundle script
create_bundle_script() {
    cat > bundle_dependencies.sh << 'BUNDLE_EOF'
#!/bin/bash

# Bundle dependencies script
echo "Creating IDB bundle with dependencies..."

BUNDLE_DIR="idb-bundle"
mkdir -p "$BUNDLE_DIR/bin"
mkdir -p "$BUNDLE_DIR/lib"

# Copy binaries
echo "Copying binaries..."
cp build/bin/idb_companion "$BUNDLE_DIR/bin/"
cp dist/idb-cli "$BUNDLE_DIR/bin/"

# Function to copy library and its dependencies recursively
copy_lib_recursive() {
    local lib_path=$1
    local target_dir=$2
    local lib_name=$(basename "$lib_path")
    
    # Skip if already copied or if it's a system library
    if [[ -f "$target_dir/$lib_name" ]] || [[ "$lib_path" =~ ^/System ]] || [[ "$lib_path" =~ ^/usr/lib ]]; then
        return
    fi
    
    # Copy the library
    if [[ -f "$lib_path" ]]; then
        echo "  Copying $lib_name"
        cp "$lib_path" "$target_dir/"
        
        # Recursively copy dependencies of this library
        otool -L "$lib_path" | grep -E "^\s+/" | while read line; do
            if [[ $line =~ ^[[:space:]]*(/.*\.dylib) ]]; then
                copy_lib_recursive "${BASH_REMATCH[1]}" "$target_dir"
            fi
        done
    fi
}

# Copy companion dependencies
echo "Copying companion dependencies..."
otool -L "$BUNDLE_DIR/bin/idb_companion" | grep -E "^\s+/" | while read line; do
    if [[ $line =~ ^[[:space:]]*(/.*\.dylib) ]]; then
        copy_lib_recursive "${BASH_REMATCH[1]}" "$BUNDLE_DIR/lib"
    fi
done

# Copy Python client dependencies
echo "Copying Python client dependencies..."
if [[ -f "$BUNDLE_DIR/bin/idb-cli" ]]; then
    otool -L "$BUNDLE_DIR/bin/idb-cli" | grep -E "^\s+/" | while read line; do
        if [[ $line =~ ^[[:space:]]*(/.*\.dylib) ]]; then
            copy_lib_recursive "${BASH_REMATCH[1]}" "$BUNDLE_DIR/lib"
        fi
    done
fi

# Create wrapper scripts that set DYLD_LIBRARY_PATH
echo "Creating wrapper scripts..."

cat > "$BUNDLE_DIR/idb_companion" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_LIBRARY_PATH="$DIR/lib:$DYLD_LIBRARY_PATH"
exec "$DIR/bin/idb_companion" "$@"
WRAPPER_EOF

cat > "$BUNDLE_DIR/idb" << 'WRAPPER_EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_LIBRARY_PATH="$DIR/lib:$DYLD_LIBRARY_PATH"
exec "$DIR/bin/idb-cli" "$@"
WRAPPER_EOF

chmod +x "$BUNDLE_DIR/idb_companion"
chmod +x "$BUNDLE_DIR/idb"

echo "✅ Bundle created in $BUNDLE_DIR/"
echo "📝 Test with: ./$BUNDLE_DIR/idb list-targets"

BUNDLE_EOF

    chmod +x bundle_dependencies.sh
    echo "📦 Created bundle_dependencies.sh script"
}

# Function to check system compatibility
check_system_compatibility() {
    echo ""
    echo "=== System Compatibility Check ==="
    
    echo "📱 macOS version:"
    sw_vers
    
    echo ""
    echo "🔧 Xcode version:"
    xcode-select --print-path
    xcrun --show-sdk-version 2>/dev/null || echo "  SDK version not available"
    
    echo ""
    echo "🐍 Python environment:"
    python3 --version
    pip3 --version
    
    echo ""
    echo "📚 Key libraries:"
    echo "  OpenSSL:"
    brew list openssl@3 2>/dev/null | head -3 || echo "    Not installed via Homebrew"
    
    echo "  Swift libraries:"
    find /usr/lib/swift -name "*Concurrency*" 2>/dev/null | head -3 || echo "    Swift Concurrency libraries not found in /usr/lib/swift"
}

# Main execution
echo "Starting dependency analysis..."

# Check if companion exists
if [[ -f "$COMPANION_PATH" ]]; then
    analyze_binary "$COMPANION_PATH"
else
    echo "❌ Companion not found. Build it first with: ./build.sh framework build"
fi

# Check if Python binary exists
if [[ -f "$PYTHON_BINARY" ]]; then
    analyze_binary "$PYTHON_BINARY"
else
    echo "❌ Python binary not found. Build it first with PyInstaller"
    echo "💡 Run: pyinstaller --onefile --name idb-cli idb/cli/main.py"
fi

# System compatibility check
check_system_compatibility

# Create bundling script
create_bundle_script

echo ""
echo "=== Summary ==="
echo "✅ Analysis complete"
echo "📦 Run ./bundle_dependencies.sh to create a self-contained bundle"
echo "🧪 Test the bundle on a clean system without development tools"