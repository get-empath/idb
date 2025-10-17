#!/bin/bash

# troubleshoot_idb.sh
# Troubleshooting script for IDB packaging issues

IDB_PATH="/Users/bkessler/Apps/idb-main"
VENV_PATH="$IDB_PATH/idb-env"

echo "🔧 IDB Packaging Troubleshoot"
echo "============================="

cd "$IDB_PATH"

# Check environment
echo "📍 Environment Check:"
echo "Working directory: $PWD"
echo "Virtual env: $VENV_PATH"
echo "Python executable: $(which python)"

if [[ -d "$VENV_PATH" ]]; then
    echo "✅ Virtual environment exists"
    source "$VENV_PATH/bin/activate"
    echo "Python in venv: $(which python)"
    echo "Python version: $(python --version)"
else
    echo "❌ Virtual environment not found at $VENV_PATH"
    exit 1
fi

# Check IDB installation
echo ""
echo "📦 IDB Installation Check:"
python -c "
try:
    import idb
    print('✅ IDB module importable')
    print(f'IDB location: {idb.__file__}')
    
    # Check for your streaming touch command
    try:
        from idb.cli.commands.hid import cmd_stream_touch
        print('✅ Streaming touch command found')
    except ImportError as e:
        print(f'❌ Streaming touch command not found: {e}')
        
    # Check main.py registration
    try:
        from idb.main import main
        print('✅ Main module importable')
    except ImportError as e:
        print(f'❌ Main module issue: {e}')
        
except ImportError as e:
    print(f'❌ IDB not importable: {e}')
"

# Check your modifications
echo ""
echo "🔍 Custom Modifications Check:"

# Check hid.py file
if [[ -f "idb/cli/commands/hid.py" ]]; then
    echo "✅ hid.py exists"
    if grep -q "stream-touch\|stream_touch" "idb/cli/commands/hid.py"; then
        echo "✅ stream-touch command found in hid.py"
        echo "Stream-touch functions:"
        grep -n "def.*stream" "idb/cli/commands/hid.py" || echo "No stream functions found"
    else
        echo "❌ stream-touch command not found in hid.py"
    fi
else
    echo "❌ hid.py file missing"
fi

# Check main.py registration
if [[ -f "idb/main.py" ]]; then
    echo "✅ main.py exists"
    if grep -q "hid\|stream" "idb/main.py"; then
        echo "✅ HID/streaming references found in main.py"
    else
        echo "❌ No HID/streaming references in main.py"
    fi
else
    echo "❌ main.py file missing"
fi

# Check protobuf files
echo ""
echo "🔌 Protobuf Files Check:"
for file in "idb/grpc/idb_pb2.py" "idb/grpc/idb_grpc.py"; do
    if [[ -f "$file" ]]; then
        echo "✅ $file exists"
        if python -c "import sys; sys.path.insert(0, '.'); import ${file//\//.} " 2>/dev/null; then
            echo "✅ $file imports successfully"
        else
            echo "❌ $file has import issues"
        fi
    else
        echo "❌ $file missing"
    fi
done

# Check dependencies
echo ""
echo "📚 Dependencies Check:"
REQUIRED_PACKAGES=("grpcio" "protobuf" "click" "treelib" "psutil" "aiofiles" "aiohttp")

for package in "${REQUIRED_PACKAGES[@]}"; do
    if python -c "import $package" 2>/dev/null; then
        VERSION=$(python -c "import $package; print(getattr($package, '__version__', 'unknown'))" 2>/dev/null)
        echo "✅ $package ($VERSION)"
    else
        echo "❌ $package missing"
    fi
done

# Check PyInstaller
echo ""
echo "🔨 PyInstaller Check:"
if python -c "import PyInstaller" 2>/dev/null; then
    VERSION=$(python -c "import PyInstaller; print(PyInstaller.__version__)" 2>/dev/null)
    echo "✅ PyInstaller ($VERSION)"
else
    echo "❌ PyInstaller not installed"
    echo "Install with: pip install pyinstaller"
fi

# Test running IDB directly
echo ""
echo "🏃 Direct IDB Test:"
if python -m idb --help > /dev/null 2>&1; then
    echo "✅ IDB runs directly with python -m idb"
else
    echo "❌ IDB fails to run directly"
    echo "Testing python idb/main.py..."
    if python idb/main.py --help > /dev/null 2>&1; then
        echo "✅ IDB runs with python idb/main.py"
    else
        echo "❌ IDB fails both ways"
    fi
fi

# Check for previous build artifacts
echo ""
echo "🗑️  Build Artifacts Check:"
if [[ -d "build" ]]; then
    echo "⚠️  Previous build directory exists ($(du -sh build | cut -f1))"
fi
if [[ -d "dist" ]]; then
    echo "⚠️  Previous dist directory exists ($(du -sh dist | cut -f1))"
    if [[ -f "dist/idb-custom" ]]; then
        echo "📄 Previous binary: $(ls -lh dist/idb-custom | awk '{print $5}')"
    fi
fi

# Quick fix suggestions
echo ""
echo "🔧 Quick Fix Suggestions:"
echo "========================"

if ! python -c "from idb.cli.commands.hid import cmd_stream_touch" 2>/dev/null; then
    echo "1. ❌ Streaming touch command not properly registered"
    echo "   - Check idb/cli/commands/hid.py has your stream-touch function"
    echo "   - Check idb/main.py imports and registers the command"
fi

if [[ ! -d "idb/common/migrations" ]]; then
    echo "2. ❌ Missing migrations directory"
    echo "   - Run: mkdir -p idb/common/migrations && touch idb/common/migrations/__init__.py"
fi

if ! python -c "import PyInstaller" 2>/dev/null; then
    echo "3. ❌ PyInstaller not installed"
    echo "   - Run: pip install pyinstaller"
fi

echo ""
echo "💡 Recommended Next Steps:"
echo "1. Fix any issues shown above"
echo "2. Run: bash fix_idb_packaging.sh"
echo "3. Run: bash test_streaming_touch.sh"