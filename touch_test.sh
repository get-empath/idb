#!/bin/bash

# Touch streaming test script
UDID="8B531A08-7FE9-4DDE-AE2D-ED01E2AEF000"

echo "Testing enhanced IDB touch streaming capabilities..."

# Test 1: Basic tap
echo "Test 1: Basic tap at center of screen"
idb ui tap 200 400 --udid $UDID
sleep 1

# Test 2: Swipe gesture
echo "Test 2: Swipe from left to right"
idb ui swipe 100 300 400 300 --duration 1.0 --udid $UDID
sleep 1

# Test 3: JSON touch streaming - single tap
echo "Test 3: JSON touch streaming - single tap"
cat << EOF | idb ui stream-touch --udid $UDID
{"type": "touch_start", "x": 150, "y": 250}
{"type": "touch_end", "x": 150, "y": 250}
EOF
sleep 1

# Test 4: JSON touch streaming - drag gesture
echo "Test 4: JSON touch streaming - drag gesture"
cat << EOF | idb ui stream-touch --udid $UDID
{"type": "touch_start", "x": 100, "y": 200}
{"type": "touch_move", "x": 120, "y": 220}
{"type": "touch_move", "x": 140, "y": 240}
{"type": "touch_move", "x": 160, "y": 260}
{"type": "touch_move", "x": 180, "y": 280}
{"type": "touch_move", "x": 200, "y": 300}
{"type": "touch_end", "x": 200, "y": 300}
EOF
sleep 1

# Test 5: Multi-finger gesture simulation
echo "Test 5: Multi-finger pinch simulation"
cat << EOF | idb ui stream-touch --udid $UDID
{"type": "touch_start", "x": 150, "y": 200}
{"type": "touch_start", "x": 250, "y": 300}
{"type": "touch_move", "x": 175, "y": 225}
{"type": "touch_move", "x": 225, "y": 275}
{"type": "touch_move", "x": 200, "y": 250}
{"type": "touch_move", "x": 200, "y": 250}
{"type": "touch_end", "x": 200, "y": 250}
{"type": "touch_end", "x": 200, "y": 250}
EOF

echo "Touch streaming tests completed!"

# Test 6: Combined with video streaming
echo "Test 6: Testing touch events during enhanced video streaming"

# Start video streaming in background
idb video-stream \
  --fps 30 \
  --format h264 \
  --keyframe-interval 30 \
  --profile baseline \
  --max-bitrate 4000 \
  --buffer-size 2000 \
  --preset streaming \
  --udid $UDID \
  test_streaming_with_touches.h264 &

VIDEO_PID=$!
echo "Started video streaming (PID: $VIDEO_PID)"

# Wait for stream to start
sleep 3

# Send touch events while streaming
echo "Sending touch events during video streaming..."
cat << EOF | idb ui stream-touch --udid $UDID
{"type": "touch_start", "x": 100, "y": 100}
{"type": "touch_move", "x": 300, "y": 100}
{"type": "touch_move", "x": 300, "y": 400}
{"type": "touch_move", "x": 100, "y": 400}
{"type": "touch_move", "x": 100, "y": 100}
{"type": "touch_end", "x": 100, "y": 100}
EOF

# Let it record for a few more seconds
sleep 5

# Stop video streaming
kill $VIDEO_PID
echo "Stopped video streaming"

echo "All tests completed! Check test_streaming_with_touches.h264 for recorded video."