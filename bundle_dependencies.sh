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

