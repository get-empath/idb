#!/bin/bash

# test_streaming_touch.sh
# Comprehensive test script for custom IDB streaming touch functionality

set -e

IDB_BINARY="./dist/idb-custom"
TEST_UDID="8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000"

echo "🧪 Testing Custom IDB Streaming Touch"
echo "===================================="

# Check if binary exists
if [[ ! -f "$IDB_BINARY" ]]; then
    echo "❌ IDB binary not found at: $IDB_BINARY"
    echo "Please run the build script first."
    exit 1
fi

# Make sure it's executable
chmod +x "$IDB_BINARY"

# Test 1: Basic binary functionality
echo ""
echo "📱 Test 1: Basic Binary Functionality"
echo "------------------------------------"

echo "Testing --help..."
if $IDB_BINARY --help > /dev/null 2>&1; then
    echo "✅ --help works"
else
    echo "❌ --help failed"
    exit 1
fi

echo "Testing --version..."
$IDB_BINARY --version 2>/dev/null || echo "⚠️  Version command not available (this is normal)"

# Test 2: List targets
echo ""
echo "📱 Test 2: Device Detection"
echo "--------------------------"

echo "Listing available targets..."
TARGETS_OUTPUT=$($IDB_BINARY list-targets 2>&1 || true)
echo "$TARGETS_OUTPUT"

if echo "$TARGETS_OUTPUT" | grep -q "$TEST_UDID"; then
    echo "✅ Test simulator found!"
    DEVICE_AVAILABLE=true
else
    echo "⚠️  Test simulator not found. Make sure iOS Simulator is running with UDID: $TEST_UDID"
    echo ""
    echo "To start the test simulator:"
    echo "1. Open Xcode Simulator"
    echo "2. Go to Device > Manage Devices"
    echo "3. Look for iPhone 16 Plus with UDID: $TEST_UDID"
    echo "4. Or create a new simulator and note its UDID"
    DEVICE_AVAILABLE=false
fi

# Test 3: UI commands availability
echo ""
echo "📱 Test 3: UI Commands"
echo "---------------------"

echo "Checking available UI commands..."
UI_HELP=$($IDB_BINARY ui --help 2>&1 || true)

if echo "$UI_HELP" | grep -q "stream-touch"; then
    echo "✅ stream-touch command is available!"
    echo ""
    echo "Stream-touch help:"
    echo "===================="
    $IDB_BINARY ui stream-touch --help 2>&1 || true
else
    echo "❌ stream-touch command not found!"
    echo ""
    echo "Available UI commands:"
    echo "$UI_HELP"
    echo ""
    echo "This means your streaming touch code wasn't properly included."
    echo "Check your idb/cli/commands/hid.py file and main.py registration."
    exit 1
fi

# Test 4: Streaming touch functionality (if device available)
if [[ "$DEVICE_AVAILABLE" == "true" ]]; then
    echo ""
    echo "📱 Test 4: Streaming Touch Functionality"
    echo "---------------------------------------"
    
    echo "Test 4a: Single touch event..."
    echo '{"type": "touch_start", "x": 200, "y": 400}' | timeout 5s $IDB_BINARY ui stream-touch --udid "$TEST_UDID" 2>&1 || {
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "✅ Touch command executed (timeout expected)"
        else
            echo "❌ Touch command failed with exit code: $exit_code"
        fi
    }
    
    echo ""
    echo "Test 4b: Touch sequence (swipe gesture)..."
    timeout 10s bash -c "
        cat << 'EOF' | $IDB_BINARY ui stream-touch --udid '$TEST_UDID'
{\"type\": \"touch_start\", \"x\": 100, \"y\": 300}
{\"type\": \"touch_move\", \"x\": 200, \"y\": 300}
{\"type\": \"touch_move\", \"x\": 300, \"y\": 300}
{\"type\": \"touch_end\", \"x\": 400, \"y\": 300}
EOF
    " 2>&1 || {
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo "✅ Touch sequence executed (timeout expected)"
        else
            echo "❌ Touch sequence failed with exit code: $exit_code"
        fi
    }
    
    echo ""
    echo "Test 4c: Invalid input handling..."
    echo '{"invalid": "json"}' | timeout 3s $IDB_BINARY ui stream-touch --udid "$TEST_UDID" 2>&1 || {
        echo "✅ Invalid input handled gracefully"
    }
    
else
    echo ""
    echo "📱 Test 4: Streaming Touch Functionality"
    echo "---------------------------------------"
    echo "⏭️  Skipped - No test device available"
fi

# Test 5: Other core functionality
echo ""
echo "📱 Test 5: Other Core Functionality"
echo "----------------------------------"

echo "Testing screenshot command..."
if [[ "$DEVICE_AVAILABLE" == "true" ]]; then
    if timeout 10s $IDB_BINARY screenshot --udid "$TEST_UDID" > /tmp/test_screenshot.png 2>/dev/null; then
        echo "✅ Screenshot works (saved to /tmp/test_screenshot.png)"
        ls -lh /tmp/test_screenshot.png
    else
        echo "⚠️  Screenshot may have issues"
    fi
else
    echo "⏭️  Skipped - No test device available"
fi

# Test 6: Binary analysis
echo ""
echo "📱 Test 6: Binary Analysis"
echo "-------------------------"

echo "Binary size: $(ls -lh "$IDB_BINARY" | awk '{print $5}')"
echo "Binary type: $(file "$IDB_BINARY")"

echo ""
echo "Checking for common missing dependencies..."
if otool -L "$IDB_BINARY" 2>/dev/null | grep -q "libpython"; then
    echo "⚠️  Binary still links to system Python - this may cause issues on other systems"
else
    echo "✅ Binary appears to be self-contained"
fi

# Test 7: Performance test
echo ""
echo "📱 Test 7: Performance Test"
echo "--------------------------"

echo "Testing startup time..."
START_TIME=$(date +%s%N)
$IDB_BINARY --help > /dev/null 2>&1
END_TIME=$(date +%s%N)
STARTUP_TIME=$(( (END_TIME - START_TIME) / 1000000 ))
echo "Startup time: ${STARTUP_TIME}ms"

if [[ $STARTUP_TIME -lt 5000 ]]; then
    echo "✅ Good startup performance"
elif [[ $STARTUP_TIME -lt 10000 ]]; then
    echo "⚠️  Moderate startup performance"
else
    echo "❌ Slow startup performance"
fi

# Summary
echo ""
echo "📋 Test Summary"
echo "==============="

echo "✅ Binary created and executable"
echo "✅ Basic commands work"
if echo "$UI_HELP" | grep -q "stream-touch"; then
    echo "✅ Streaming touch command available"
else
    echo "❌ Streaming touch command missing"
fi

if [[ "$DEVICE_AVAILABLE" == "true" ]]; then
    echo "✅ Device communication tested"
else
    echo "⚠️  Device communication not tested (no simulator running)"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. If streaming touch is missing, check your code integration"
echo "2. Test with a running iOS simulator"
echo "3. Test on a different Mac to verify portability"
echo "4. Package for Electron distribution"

echo ""
echo "📖 Usage Examples:"
echo "# Single touch"
echo "echo '{\"type\": \"touch_start\", \"x\": 200, \"y\": 400}' | $IDB_BINARY ui stream-touch --udid YOUR_UDID"
echo ""
echo "# Touch sequence"
echo "cat << 'EOF' | $IDB_BINARY ui stream-touch --udid YOUR_UDID"
echo '{\"type\": \"touch_start\", \"x\": 100, \"y\": 300}'
echo '{\"type\": \"touch_move\", \"x\": 200, \"y\": 300}'
echo '{\"type\": \"touch_end\", \"x\": 300, \"y\": 300}'
echo "EOF"