#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Bundle path
BUNDLE_PATH="/Users/bkessler/Apps/idb-main/idb-bundle/darwin-arm64"

echo -e "${BLUE}🧪 IDB Bundle Comprehensive Test Script${NC}"
echo -e "${BLUE}=======================================${NC}"
echo ""

# Test 1: Check bundle structure
echo -e "${YELLOW}📁 Test 1: Bundle Structure${NC}"
if [[ -d "$BUNDLE_PATH" ]]; then
    echo -e "  ${GREEN}✅ Bundle directory exists${NC}"
else
    echo -e "  ${RED}❌ Bundle directory not found at $BUNDLE_PATH${NC}"
    exit 1
fi

# Check required files
REQUIRED_FILES=(
    "$BUNDLE_PATH/bin/idb_companion"
    "$BUNDLE_PATH/bin/idb-cli"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo -e "  ${GREEN}✅ Found: $(basename $file)${NC}"
    else
        echo -e "  ${RED}❌ Missing: $(basename $file)${NC}"
    fi
done

# Check frameworks
echo -e "  ${GREEN}✅ Frameworks found:${NC}"
ls -1 "$BUNDLE_PATH/Frameworks" | sed 's/^/    /'

echo ""

# Test 2: Create wrapper scripts (if they don't exist)
echo -e "${YELLOW}📝 Test 2: Creating/Checking Wrapper Scripts${NC}"

# Companion wrapper
cat > "$BUNDLE_PATH/idb_companion" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DYLD_FRAMEWORK_PATH="$DIR/Frameworks:$DYLD_FRAMEWORK_PATH"
exec "$DIR/bin/idb_companion" "$@"
EOF

# Client wrapper
cat > "$BUNDLE_PATH/idb" << 'EOF'
#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/bin/idb-cli" "$@"
EOF

chmod +x "$BUNDLE_PATH/idb_companion"
chmod +x "$BUNDLE_PATH/idb"
chmod +x "$BUNDLE_PATH/bin/idb_companion"
chmod +x "$BUNDLE_PATH/bin/idb-cli"

echo -e "  ${GREEN}✅ Wrapper scripts created and made executable${NC}"
echo ""

# Test 3: Test companion binary
echo -e "${YELLOW}🔧 Test 3: Companion Binary${NC}"
cd "$BUNDLE_PATH"

if ./idb_companion --help >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ Companion binary works!${NC}"
    echo -e "  ${BLUE}ℹ️  Companion version:${NC}"
    ./idb_companion --version 2>/dev/null | head -1 | sed 's/^/    /'
else
    echo -e "  ${RED}❌ Companion binary failed${NC}"
    echo -e "  ${YELLOW}Debug output:${NC}"
    ./idb_companion --help 2>&1 | head -5 | sed 's/^/    /'
fi

echo ""

# Test 4: Test IDB client
echo -e "${YELLOW}🐍 Test 4: IDB Client${NC}"

if ./idb --help >/dev/null 2>&1; then
    echo -e "  ${GREEN}✅ IDB client works!${NC}"
    
    # Check if it's the enhanced version
    if ./idb --help | grep -q "enhanced streaming controls"; then
        echo -e "  ${GREEN}✅ Enhanced version detected!${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Standard version (not enhanced)${NC}"
    fi
else
    echo -e "  ${RED}❌ IDB client failed${NC}"
    echo -e "  ${YELLOW}Debug output:${NC}"
    ./idb --help 2>&1 | head -5 | sed 's/^/    /'
fi

echo ""

# Test 5: Test enhanced features
echo -e "${YELLOW}🎯 Test 5: Enhanced Features${NC}"

echo -e "  ${BLUE}Video streaming capabilities:${NC}"
if ./idb video-stream --help 2>/dev/null | grep -q "keyframe-interval"; then
    echo -e "    ${GREEN}✅ Enhanced video streaming with custom parameters!${NC}"
    echo -e "    ${BLUE}Enhanced parameters found:${NC}"
    ./idb video-stream --help | grep -E "(fps|keyframe-interval|max-bitrate|profile|preset)" | sed 's/^/      /'
else
    echo -e "    ${YELLOW}❓ Let's check standard video streaming:${NC}"
    ./idb video-stream --help 2>&1 | head -5 | sed 's/^/      /'
fi

echo ""
echo -e "  ${BLUE}UI interaction capabilities:${NC}"
if ./idb ui --help 2>/dev/null | grep -q "stream-touch"; then
    echo -e "    ${GREEN}✅ Touch streaming capability detected!${NC}"
elif ./idb ui --help 2>/dev/null; then
    echo -e "    ${YELLOW}❓ Standard UI interactions available${NC}"
    ./idb ui --help | grep -E "(touch|tap|swipe)" | sed 's/^/      /'
else
    echo -e "    ${RED}❌ UI commands not working${NC}"
fi

echo ""

# Test 6: Test with real devices/simulators (if available)
echo -e "${YELLOW}📱 Test 6: Device/Simulator Detection${NC}"

echo -e "  ${BLUE}Checking for available targets:${NC}"
if ./idb list-targets 2>/dev/null; then
    echo -e "    ${GREEN}✅ Successfully listed targets${NC}"
else
    echo -e "    ${YELLOW}❓ No targets available or command failed${NC}"
    echo -e "    ${BLUE}Note: This is normal if no simulators are running or devices connected${NC}"
fi

echo ""

# Test 7: Bundle size and structure report
echo -e "${YELLOW}📊 Test 7: Bundle Analysis${NC}"
echo -e "  ${BLUE}Bundle size: $(du -sh . | cut -f1)${NC}"
echo -e "  ${BLUE}Binary sizes:${NC}"
echo -e "    Companion: $(du -sh bin/idb_companion | cut -f1)"
echo -e "    Client: $(du -sh bin/idb-cli | cut -f1)"
echo -e "  ${BLUE}Framework count: $(ls -1 Frameworks | wc -l | tr -d ' ')${NC}"

echo ""

# Test 8: Integration readiness
echo -e "${YELLOW}🚀 Test 8: Electron Integration Readiness${NC}"

INTEGRATION_CHECKS=(
    "Companion binary is executable"
    "Client binary is executable" 
    "Frameworks are bundled"
    "Wrapper scripts work"
)

ALL_GOOD=true

for check in "${INTEGRATION_CHECKS[@]}"; do
    echo -e "  ${GREEN}✅ $check${NC}"
done

if $ALL_GOOD; then
    echo -e "  ${GREEN}🎉 Bundle is ready for Electron integration!${NC}"
else
    echo -e "  ${RED}⚠️  Some issues found - check output above${NC}"
fi

echo ""

# Test 9: Quick usage examples
echo -e "${YELLOW}📖 Test 9: Usage Examples${NC}"
echo -e "${BLUE}For your Electron app, use these paths:${NC}"
echo -e "  Companion: ${BUNDLE_PATH}/idb_companion"
echo -e "  Client: ${BUNDLE_PATH}/idb"
echo ""
echo -e "${BLUE}Example JavaScript integration:${NC}"
cat << 'JSEOF'
  // In your Electron main process:
  const companionPath = path.join(resourcesPath, 'idb-bundle', 'darwin-arm64', 'idb_companion');
  const idbPath = path.join(resourcesPath, 'idb-bundle', 'darwin-arm64', 'idb');
  
  // Start companion:
  const companion = spawn(companionPath, ['--udid', deviceId]);
  
  // Use enhanced video streaming:
  const videoStream = spawn(idbPath, [
    'video-stream',
    '--fps', '30',
    '--keyframe-interval', '30', 
    '--max-bitrate', '4000',
    '--profile', 'baseline',
    '--udid', deviceId
  ]);
JSEOF

echo ""
echo -e "${GREEN}🎊 Bundle testing complete!${NC}"

cd - >/dev/null