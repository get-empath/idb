#!/bin/bash

# Create Portable IDB Package Script
# This creates a self-contained IDB package that can be moved to other machines

set -e

# Configuration
SOURCE_DIR="/Users/bkessler/Apps/idb-main"
PACKAGE_DIR="/Users/bkessler/Desktop/idb-custom-portable"
VENV_NAME="idb-portable-env"

echo "🚀 Creating portable IDB package..."

# Step 1: Create package directory
echo "📁 Creating package directory..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Step 2: Create a fresh virtual environment
echo "🐍 Creating fresh virtual environment..."
cd "$PACKAGE_DIR"
python3 -m venv "$VENV_NAME"
source "$VENV_NAME/bin/activate"

# Step 3: Install your custom IDB
echo "📦 Installing custom IDB..."
export FB_IDB_VERSION="1.0.4"
pip install "$SOURCE_DIR"

# Step 4: Create launcher scripts
echo "🔧 Creating launcher scripts..."

# Create main launcher script
cat > "$PACKAGE_DIR/idb" << 'EOF'
#!/bin/bash
# Portable IDB Launcher
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/idb-portable-env/bin/activate"
exec python -m idb.cli.main "$@"
EOF

chmod +x "$PACKAGE_DIR/idb"

# Create streaming touch launcher
cat > "$PACKAGE_DIR/idb-stream-touch" << 'EOF'
#!/bin/bash
# Portable IDB Streaming Touch Launcher
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
source "$SCRIPT_DIR/idb-portable-env/bin/activate"
exec python -m idb.cli.main ui stream-touch "$@"
EOF

chmod +x "$PACKAGE_DIR/idb-stream-touch"

# Step 5: Create README
cat > "$PACKAGE_DIR/README.md" << EOF
# Custom IDB with Streaming Touch Support

This is a portable package of your custom IDB with streaming touch functionality.

## Usage

### Basic IDB commands:
\`\`\`bash
./idb --help
./idb list-targets
\`\`\`

### Streaming Touch (your custom feature):
\`\`\`bash
./idb ui stream-touch --udid YOUR_SIMULATOR_UDID
\`\`\`

Then send JSON commands via stdin:
\`\`\`json
{"type": "touch_start", "x": 200, "y": 300}
{"type": "touch_move", "x": 210, "y": 310}
{"type": "touch_end", "x": 220, "y": 320}
\`\`\`

### Quick streaming touch launcher:
\`\`\`bash
./idb-stream-touch --udid YOUR_SIMULATOR_UDID
\`\`\`

## Test Simulator UDID
Your test iPhone 16 Plus: 8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000

## Requirements
- macOS (for simulator support)
- Python 3.7+ (already included in virtual environment)

Built from: $SOURCE_DIR
Version: 1.0.3-portable
EOF

# Step 6: Test the package
echo "🧪 Testing portable package..."
deactivate 2>/dev/null || true  # Exit any current venv
"$PACKAGE_DIR/idb" --help > /dev/null && echo "✅ Basic IDB test passed"
"$PACKAGE_DIR/idb" ui stream-touch --help > /dev/null && echo "✅ Streaming touch test passed"

# Step 7: Create archive
echo "📦 Creating archive..."
cd "$(dirname "$PACKAGE_DIR")"
tar -czf "idb-custom-portable.tar.gz" "$(basename "$PACKAGE_DIR")"

echo ""
echo "🎉 Portable IDB package created successfully!"
echo ""
echo "📍 Package location: $PACKAGE_DIR"
echo "📍 Archive location: $(dirname "$PACKAGE_DIR")/idb-custom-portable.tar.gz"
echo ""
echo "To use on another machine:"
echo "1. Copy the archive to the target machine"
echo "2. Extract: tar -xzf idb-custom-portable.tar.gz"
echo "3. Run: ./idb-custom-portable/idb --help"
echo ""
echo "Test your streaming touch:"
echo "./idb-custom-portable/idb ui stream-touch --udid 8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000"