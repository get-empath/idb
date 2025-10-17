#!/bin/bash
# idb_diagnostic.sh - Check what IDB assets we have available

echo "🔍 IDB Build Diagnostic Report"
echo "=============================="
echo ""

BUILD_DIR="/Users/bkessler/Apps/idb-main"
cd "$BUILD_DIR"

echo "📁 Directory structure:"
ls -la

echo ""
echo "🎯 Looking for existing IDB binaries..."

# Check for existing bundle
if [[ -d "idb-bundle" ]]; then
    echo "✅ Found existing idb-bundle directory"
    echo "Contents:"
    find idb-bundle -type f -perm +111 | head -10
    
    echo ""
    echo "Testing existing binaries:"
    
    if [[ -f "idb-bundle/darwin-arm64/idb_companion" ]]; then
        echo -n "Companion test: "
        if idb-bundle/darwin-arm64/idb_companion --help >/dev/null 2>&1; then
            echo "✅ Working"
        else
            echo "❌ Failed"
        fi
        
        echo -n "Companion signature: "
        if codesign -dv idb-bundle/darwin-arm64/idb_companion 2>&1 | grep -q "Developer ID"; then
            echo "✅ Signed"
        else
            echo "❌ Not signed"
        fi
    fi
    
    if [[ -f "idb-bundle/darwin-arm64/idb" ]]; then
        echo -n "Client test: "
        if idb-bundle/darwin-arm64/idb --help >/dev/null 2>&1; then
            echo "✅ Working"
        else
            echo "❌ Failed"
        fi
        
        echo -n "Client signature: "
        if codesign -dv idb-bundle/darwin-arm64/idb 2>&1 | grep -q "Developer ID"; then
            echo "✅ Signed"
        else
            echo "❌ Not signed"
        fi
    fi
else
    echo "❌ No existing idb-bundle found"
fi

echo ""
echo "🔨 Build environment check:"

# Check Xcode
echo -n "Xcode: "
if xcode-select -p >/dev/null 2>&1; then
    echo "✅ $(xcode-select -p)"
else
    echo "❌ Not found"
fi

# Check Python
echo -n "Python 3.13: "
if python3.13 --version >/dev/null 2>&1; then
    echo "✅ $(python3.13 --version)"
else
    echo "❌ Not found"
fi

# Check certificates
echo -n "Code signing certificates: "
CERT_COUNT=$(security find-identity -v -p codesigning | grep -c "Developer ID")
echo "$CERT_COUNT found"

if [[ $CERT_COUNT -gt 0 ]]; then
    security find-identity -v -p codesigning | grep "Developer ID"
fi

echo ""
echo "📦 Project files:"

# Check for Xcode project
if [[ -f "idb_companion.xcodeproj/project.pbxproj" ]]; then
    echo "✅ Xcode project found"
else
    echo "❌ Xcode project missing"
fi

# Check for Python setup
if [[ -f "setup.py" ]]; then
    echo "✅ Python setup.py found"
else
    echo "❌ Python setup.py missing"
fi

echo ""
echo "🧹 Previous build artifacts:"

if [[ -d "build" ]]; then
    echo "📁 build/ directory exists ($(du -sh build 2>/dev/null | cut -f1))"
    if [[ -f "build/Build/Products/Release/idb_companion" ]]; then
        echo "✅ Previous companion binary found"
    fi
fi

if [[ -d "DerivedData" ]]; then
    echo "📁 DerivedData/ exists ($(du -sh DerivedData 2>/dev/null | cut -f1))"
fi

if [[ -d ".build" ]]; then
    echo "📁 .build/ exists ($(du -sh .build 2>/dev/null | cut -f1))"
fi

echo ""
echo "🎯 Recommended action:"

if [[ -f "idb-bundle/darwin-arm64/idb_companion" ]] && [[ -f "idb-bundle/darwin-arm64/idb" ]]; then
    echo "✅ You have working IDB binaries!"
    echo "   → Run the robust build script to re-sign them properly"
    echo "   → Command: ./robust_idb_build.sh"
else
    echo "❌ Missing working IDB binaries"
    echo "   → Need to build IDB from scratch or find working binaries"
    echo "   → Try: ./robust_idb_build.sh (will attempt multiple strategies)"
fi

echo ""
echo "📋 Next steps:"
echo "1. Save the robust build script as 'robust_idb_build.sh'"
echo "2. chmod +x robust_idb_build.sh"
echo "3. ./robust_idb_build.sh"
echo ""
echo "The robust script will try multiple build strategies and use existing"
echo "binaries if the Swift compilation fails."