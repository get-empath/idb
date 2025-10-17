#!/bin/bash
set -e

# =============================================================================
# Debug and Fix Framework Signing Issues
# =============================================================================

DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
BUILD_DIR="/Users/bkessler/Apps/idb-main"
FINAL_BUNDLE="idb-properly-signed"

echo "🔍 Debug and Fix Framework Signing Issues"
echo ""

cd "$BUILD_DIR"

# =============================================================================
# Step 1: Debug Current Framework State
# =============================================================================
debug_frameworks() {
    echo "🔍 Debugging current framework state..."
    
    for framework in "$FINAL_BUNDLE/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo ""
            echo "=== $framework_name ==="
            
            echo "Framework structure:"
            ls -la "$framework/" 2>/dev/null || echo "  No direct contents"
            
            if [[ -d "$framework/Versions" ]]; then
                echo "Versions directory:"
                ls -la "$framework/Versions/" 2>/dev/null
                
                if [[ -d "$framework/Versions/A" ]]; then
                    echo "Version A contents:"
                    ls -la "$framework/Versions/A/" 2>/dev/null | head -10
                fi
            fi
            
            # Check for main binary
            MAIN_BINARY="$framework/Versions/A/$framework_name"
            if [[ -f "$MAIN_BINARY" ]]; then
                echo "Main binary: EXISTS"
                echo "Binary info: $(file "$MAIN_BINARY")"
                echo "Current signature:"
                codesign -dv "$MAIN_BINARY" 2>&1 | head -3 || echo "  No valid signature"
            else
                echo "Main binary: MISSING at $MAIN_BINARY"
                # Look for it elsewhere
                find "$framework" -name "$framework_name" -type f | head -3
            fi
            
            echo "Framework signature:"
            codesign -dv "$framework" 2>&1 | head -3 || echo "  No valid signature"
        fi
    done
}

# =============================================================================
# Step 2: Fix Framework Symlinks
# =============================================================================
fix_framework_symlinks() {
    echo ""
    echo "🔗 Fixing framework symlinks..."
    
    for framework in "$FINAL_BUNDLE/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo "  Fixing $framework_name..."
            
            cd "$framework"
            
            # Ensure Versions/Current points to A
            if [[ -d "Versions/A" ]]; then
                rm -f "Versions/Current"
                ln -sf A "Versions/Current"
                echo "    ✅ Fixed Versions/Current -> A"
            fi
            
            # Create top-level symlinks
            rm -f "$framework_name" Headers Resources Modules
            
            if [[ -f "Versions/A/$framework_name" ]]; then
                ln -sf "Versions/Current/$framework_name" "$framework_name"
                echo "    ✅ Created $framework_name symlink"
            fi
            
            if [[ -d "Versions/A/Headers" ]]; then
                ln -sf "Versions/Current/Headers" Headers
                echo "    ✅ Created Headers symlink"
            fi
            
            if [[ -d "Versions/A/Resources" ]]; then
                ln -sf "Versions/Current/Resources" Resources
                echo "    ✅ Created Resources symlink"
            fi
            
            if [[ -d "Versions/A/Modules" ]]; then
                ln -sf "Versions/Current/Modules" Modules
                echo "    ✅ Created Modules symlink"
            fi
            
            cd - >/dev/null
        fi
    done
    
    echo "✅ Framework symlinks fixed"
}

# =============================================================================
# Step 3: Sign Frameworks One by One with Debugging
# =============================================================================
sign_frameworks_with_debug() {
    echo ""
    echo "🔐 Signing frameworks one by one with debugging..."
    
    for framework in "$FINAL_BUNDLE/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo ""
            echo "=== Signing $framework_name ==="
            
            # First, sign the main binary
            MAIN_BINARY="$framework/Versions/A/$framework_name"
            if [[ -f "$MAIN_BINARY" ]]; then
                echo "  Step 1: Signing main binary..."
                echo "  Command: codesign --force --sign \"$DEVELOPER_ID\" --timestamp --options runtime --identifier \"com.facebook.idb.$framework_name\" \"$MAIN_BINARY\""
                
                if codesign --force --sign "$DEVELOPER_ID" \
                    --timestamp \
                    --options runtime \
                    --identifier "com.facebook.idb.$framework_name" \
                    "$MAIN_BINARY"; then
                    echo "    ✅ Main binary signed successfully"
                    
                    # Verify binary signature
                    if codesign -dv "$MAIN_BINARY" 2>&1 | grep -q "$DEVELOPER_ID"; then
                        echo "    ✅ Binary signature verified"
                    else
                        echo "    ❌ Binary signature verification failed"
                    fi
                else
                    echo "    ❌ Main binary signing failed"
                    continue
                fi
            else
                echo "    ❌ Main binary not found: $MAIN_BINARY"
                continue
            fi
            
            # Sign any dylibs in the framework
            find "$framework" -name "*.dylib" | while read -r dylib; do
                echo "  Signing dylib: $(basename "$dylib")"
                codesign --force --sign "$DEVELOPER_ID" \
                    --timestamp \
                    --options runtime \
                    "$dylib" || echo "    ⚠️  Dylib signing failed"
            done
            
            # Now sign the framework itself
            echo "  Step 2: Signing framework bundle..."
            echo "  Command: codesign --force --sign \"$DEVELOPER_ID\" --timestamp --options runtime --identifier \"com.facebook.idb.framework.$framework_name\" \"$framework\""
            
            if codesign --force --sign "$DEVELOPER_ID" \
                --timestamp \
                --options runtime \
                --identifier "com.facebook.idb.framework.$framework_name" \
                "$framework"; then
                echo "    ✅ Framework signed successfully"
                
                # Verify framework signature
                if codesign -dv "$framework" 2>&1 | grep -q "$DEVELOPER_ID"; then
                    echo "    ✅ Framework signature verified"
                else
                    echo "    ❌ Framework signature verification failed"
                    echo "    Debug info:"
                    codesign -dv "$framework" 2>&1 | head -5
                fi
            else
                echo "    ❌ Framework signing failed"
                echo "    Debug info:"
                codesign -dv "$framework" 2>&1 | head -5 || echo "    No signature info available"
            fi
        fi
    done
}

# =============================================================================
# Step 4: Final Verification and Package Creation
# =============================================================================
final_verification_and_package() {
    echo ""
    echo "🔍 Final verification..."
    
    local all_good=true
    
    echo ""
    echo "Framework signatures:"
    for framework in "$FINAL_BUNDLE/Frameworks"/*.framework; do
        if [[ -d "$framework" ]]; then
            framework_name=$(basename "$framework" .framework)
            echo -n "  $framework_name: "
            if codesign -dv "$framework" 2>&1 | grep -q "$DEVELOPER_ID"; then
                echo "✅ SIGNED"
            else
                echo "❌ NOT SIGNED"
                all_good=false
            fi
        fi
    done
    
    echo ""
    echo "Main binaries:"
    for binary in "$FINAL_BUNDLE/idb_companion" "$FINAL_BUNDLE/idb" "$FINAL_BUNDLE/bin/idb_companion" "$FINAL_BUNDLE/bin/idb_embedded"; do
        if [[ -f "$binary" ]]; then
            echo -n "  $(basename "$binary"): "
            if codesign -dv "$binary" 2>&1 | grep -q "$DEVELOPER_ID"; then
                echo "✅ SIGNED"
            else
                echo "❌ NOT SIGNED"
                all_good=false
            fi
        fi
    done
    
    if [[ "$all_good" == true ]]; then
        echo ""
        echo "✅ All components properly signed!"
        
        # Create final package
        echo "📦 Creating final notarization package..."
        cd "$FINAL_BUNDLE"
        zip -r "../${FINAL_BUNDLE}-fixed-notarization.zip" . -x "*.DS_Store"
        cd ..
        
        echo "✅ Package created: ${FINAL_BUNDLE}-fixed-notarization.zip"
        echo "📊 Package size: $(du -sh "${FINAL_BUNDLE}-fixed-notarization.zip" | cut -f1)"
        
        echo ""
        echo "🚀 Ready for notarization:"
        echo "   xcrun notarytool submit ${FINAL_BUNDLE}-fixed-notarization.zip \\"
        echo "       --keychain-profile \"AC_PASSWORD\" \\"
        echo "       --wait"
        
        return 0
    else
        echo ""
        echo "❌ Some components still not properly signed"
        return 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    debug_frameworks
    fix_framework_symlinks
    sign_frameworks_with_debug
    final_verification_and_package
}

main "$@"