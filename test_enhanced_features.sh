#!/bin/bash

BUNDLE_DIR="idb-bundle"
UDID="8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000"  # Replace with your device UDID

echo "🧪 Testing enhanced IDB features..."

# Test enhanced video streaming
echo "Testing enhanced video streaming..."
timeout 5s "$BUNDLE_DIR/darwin-arm64/idb" video-stream \
    --fps 30 \
    --format h264 \
    --keyframe-interval 30 \
    --profile baseline \
    --max-bitrate 4000 \
    --buffer-size 2000 \
    --preset streaming \
    --udid $UDID \
    test_output.h264 && \
    echo "  ✅ Enhanced video streaming works" || \
    echo "  ❌ Enhanced video streaming failed"

# Test touch streaming
echo "Testing touch streaming..."
echo '{"type": "touch_start", "x": 100, "y": 200}' | \
    "$BUNDLE_DIR/darwin-arm64/idb" ui stream-touch --udid $UDID && \
    echo "  ✅ Touch streaming works" || \
    echo "  ❌ Touch streaming failed"

echo "🎉 Enhanced features test complete!"
