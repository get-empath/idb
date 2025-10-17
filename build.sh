#!/bin/bash
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -e
set -o pipefail

if hash xcpretty 2>/dev/null; then
  HAS_XCPRETTY=true
fi

BUILD_DIRECTORY=build

# Code signing configuration
DEVELOPER_ID="Developer ID Application: Benjamin Gabriel Kessler (BF2USJSWSF)"
TEAM_ID="BF2USJSWSF"

function invoke_xcodebuild() {
  local arguments=("$@")
  if [[ -n $HAS_XCPRETTY ]]; then
    NSUnbufferedIO=YES xcodebuild "${arguments[@]}" | xcpretty -c
  else
    xcodebuild "${arguments[@]}"
  fi
}

function sign_framework() {
  local framework_path=$1
  if [ -d "$framework_path" ]; then
    echo "🔐 Signing framework: $framework_path"
    codesign --force --sign "$DEVELOPER_ID" --timestamp --deep "$framework_path" || {
      echo "⚠️  Failed to sign $framework_path"
      return 1
    }
    echo "✅ Successfully signed: $framework_path"
  else
    echo "❌ Framework not found: $framework_path"
  fi
}

function framework_build() {
  local name=$1
  local output_directory=$2

  invoke_xcodebuild \
    -project FBSimulatorControl.xcodeproj \
    -scheme $name \
    -sdk macosx \
    -derivedDataPath $BUILD_DIRECTORY \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build

  # Sign the built framework
  local artifact="$BUILD_DIRECTORY/Build/Products/Debug/$name.framework"
  sign_framework "$artifact"

  if [[ -n $output_directory ]]; then
    framework_install $name $output_directory
  fi
}

function framework_install() {
  local name=$1
  local output_directory=$2
  local artifact="$BUILD_DIRECTORY/Build/Products/Debug/$name.framework"
  local output_directory_framework="$output_directory/Frameworks"

  echo "Copying Build output of $artifact to $output_directory_framework"
  mkdir -p "$output_directory_framework"
  cp -R $artifact "$output_directory_framework/"
  
  # Sign the copied framework as well
  sign_framework "$output_directory_framework/$name.framework"
}

function framework_test() {
  local name=$1
  invoke_xcodebuild \
    -project FBSimulatorControl.xcodeproj \
    -scheme $name \
    -sdk macosx \
    -derivedDataPath $BUILD_DIRECTORY \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    test
}

function core_framework_build() {
  framework_build FBControlCore $1
}

function core_framework_test() {
  framework_test FBControlCore
}

function xctest_framework_build() {
  framework_build XCTestBootstrap $1
}

function xctest_framework_test() {
  framework_test XCTestBootstrap
}

function simulator_framework_build() {
  framework_build FBSimulatorControl $1
}

function simulator_framework_test() {
  framework_test FBSimulatorControl
}

function device_framework_build() {
  framework_build FBDeviceControl $1
}

function device_framework_test() {
  framework_test FBDeviceControl
}

function all_frameworks_build() {
  local output_directory=$1
  echo "🔨 Building all frameworks with code signing..."
  core_framework_build $output_directory
  xctest_framework_build $output_directory
  simulator_framework_build $output_directory
  device_framework_build $output_directory
  
  if [[ -n $output_directory ]]; then
    echo "🔍 Verifying all framework signatures in output directory..."
    verify_signatures "$output_directory/Frameworks"
  fi
}

function all_frameworks_test() {
  core_framework_test
  xctest_framework_test
  simulator_framework_test
  device_framework_test
}

function verify_signatures() {
  local frameworks_dir=$1
  local unsigned_count=0
  
  if [ -d "$frameworks_dir" ]; then
    echo "🔍 Verifying signatures in $frameworks_dir..."
    
    find "$frameworks_dir" -name "*.framework" | while read framework; do
      if codesign --verify --verbose "$framework" 2>/dev/null; then
        echo "  ✅ $framework"
      else
        echo "  ❌ $framework (signature verification failed)"
        ((unsigned_count++))
      fi
    done
    
    # Also check for any .dylib files
    find "$frameworks_dir" -name "*.dylib" | while read dylib; do
      if codesign --verify --verbose "$dylib" 2>/dev/null; then
        echo "  ✅ $dylib"
      else
        echo "  ❌ $dylib (signature verification failed)"
        ((unsigned_count++))
      fi
    done
    
    if [ $unsigned_count -eq 0 ]; then
      echo "🎉 All frameworks are properly signed!"
    else
      echo "⚠️  Found $unsigned_count unsigned components"
    fi
  fi
}

function strip_framework() {
  local FRAMEWORK_PATH="$BUILD_DIRECTORY/Build/Products/Debug/$1"
  if [ -d "$FRAMEWORK_PATH" ]; then
    echo "Stripping Framework $FRAMEWORK_PATH"
    rm -r "$FRAMEWORK_PATH"
  fi
}

function cli_build() {
  local name=$1
  local output_directory=$2
  local script_directory=$1/Scripts

  invoke_xcodebuild \
    -workspace $name/$name.xcworkspace \
    -scheme $name \
    -sdk macosx \
    -derivedDataPath $BUILD_DIRECTORY \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    build

  strip_framework "FBSimulatorControlKit.framework/Versions/Current/Frameworks/FBSimulatorControl.framework"
  strip_framework "FBSimulatorControlKit.framework/Versions/Current/Frameworks/FBDeviceControl.framework"
  strip_framework "FBSimulatorControl.framework/Versions/Current/Frameworks/XCTestBootstrap.framework"
  strip_framework "FBSimulatorControl.framework/Versions/Current/Frameworks/FBControlCore.framework"
  strip_framework "FBDeviceControl.framework/Versions/Current/Frameworks/XCTestBootstrap.framework"
  strip_framework "FBDeviceControl.framework/Versions/Current/Frameworks/FBControlCore.framework"
  strip_framework "XCTestBootstrap.framework/Versions/Current/Frameworks/FBControlCore.framework"

  # Sign the main CLI binary
  local cli_binary="$BUILD_DIRECTORY/Build/Products/Debug/$name"
  if [ -f "$cli_binary" ]; then
    echo "🔐 Signing CLI binary: $cli_binary"
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$cli_binary" || {
      echo "⚠️  Failed to sign CLI binary $cli_binary"
    }
  fi

  if [[ -n $output_directory ]]; then
    cli_install $output_directory $script_directory
  fi
}

function cli_install() {
  local output_directory=$1
  local script_directory=$2
  local cli_artifact="$BUILD_DIRECTORY/Build/Products/Debug/!(*.framework)"
  local framework_artifact="$BUILD_DIRECTORY/Build/Products/Debug/*.framework"
  local output_directory_cli="$output_directory/bin"
  local output_directory_framework="$output_directory/Frameworks"

  mkdir -p "$output_directory_cli"
  mkdir -p "$output_directory_framework"

  shopt -s extglob

  echo "Copying Build output from $cli_artifact to $output_directory_cli"
  cp -R $cli_artifact "$output_directory_cli"

  echo "Copying Build output from $framework_artifact to $output_directory_framework"
  cp -R $framework_artifact "$output_directory_framework"

  if [[ -d $script_directory ]]; then
    echo "Copying Scripts from $script_directory to $output_directory_cli"
    cp -R "$2"/* "$output_directory_cli"
  fi

  shopt -u extglob
  
  # Sign all binaries and frameworks in the output directory
  echo "🔐 Signing installed components..."
  
  # Sign CLI binaries
  find "$output_directory_cli" -type f -perm +111 | while read binary; do
    if file "$binary" | grep -q "Mach-O"; then
      echo "  Signing binary: $binary"
      codesign --force --sign "$DEVELOPER_ID" --timestamp "$binary" 2>/dev/null || {
        echo "    ⚠️  Failed to sign $binary"
      }
    fi
  done
  
  # Sign frameworks
  find "$output_directory_framework" -name "*.framework" | while read framework; do
    sign_framework "$framework"
  done
  
  # Sign any loose .dylib files
  find "$output_directory_framework" -name "*.dylib" | while read dylib; do
    echo "  Signing dylib: $dylib"
    codesign --force --sign "$DEVELOPER_ID" --timestamp "$dylib" 2>/dev/null || {
      echo "    ⚠️  Failed to sign $dylib"
    }
  done
}

function cli_framework_test() {
  NAME=$1
  invoke_xcodebuild \
    -workspace $NAME/$NAME.xcworkspace \
    -scheme $NAME \
    -sdk macosx \
    -derivedDataPath $BUILD_DIRECTORY \
    CODE_SIGN_IDENTITY="$DEVELOPER_ID" \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    OTHER_CODE_SIGN_FLAGS="--timestamp" \
    test
}

function cli_e2e_test() {
  NAME=$1
  pushd $NAME/cli-tests
  py=$(which python3.6 || which python3 || which python)
  $py ./tests.py
  popd
}

function print_usage() {
cat <<EOF
./build.sh usage:
  /build.sh <target> <command> [<arg>]*

Supported Commands:
  help
    Print usage.
  framework build <output-directory>
    Build the FBSimulatorControl.framework with code signing. Optionally copies the Framework to <output-directory>
  framework test
    Build then Test the FBSimulatorControl.framework.
  fbxctest test
    Builds the FBXCTestKit.framework and runs the tests.
  verify <directory>
    Verify code signatures in the specified directory.

Environment Variables:
  DEVELOPER_ID - Override the default Developer ID certificate
  TEAM_ID - Override the default Team ID
EOF
}

# Allow overriding the signing identity via environment variables
if [[ -n $DEVELOPER_ID_OVERRIDE ]]; then
  DEVELOPER_ID="$DEVELOPER_ID_OVERRIDE"
  echo "Using custom Developer ID: $DEVELOPER_ID"
fi

if [[ -n $TEAM_ID_OVERRIDE ]]; then
  TEAM_ID="$TEAM_ID_OVERRIDE"
  echo "Using custom Team ID: $TEAM_ID"
fi

if [[ -n $TARGET ]]; then
  echo "using target $TARGET"
elif [[ -n $1 ]]; then
  TARGET=$1
  echo "using target $TARGET"
else
  echo "No target argument or $TARGET provided"
  print_usage
  exit 1
fi

if [[ -n $COMMAND ]]; then
  echo "using command $COMMAND"
elif [[ -n $2 ]]; then
  COMMAND=$2
  echo "using command $COMMAND"
else
  echo "No command argument or $COMMAND provided"
  print_usage
  exit 1
fi

if [[ -n $OUTPUT_DIRECTORY ]]; then
  echo "using output directory $OUTPUT_DIRECTORY"
elif [[ -n $3 ]]; then
  echo "using output directory $3"
  OUTPUT_DIRECTORY=$3
else
  echo "No output directory specified"
fi

case $TARGET in
  help)
    print_usage;;
  framework)
    case $COMMAND in
      build)
        all_frameworks_build $OUTPUT_DIRECTORY;;
      test)
        all_frameworks_test;;
      *)
        echo "Unknown Command $2"
        exit 1;;
    esac;;
  fbxctest)
    case $COMMAND in
      build)
        cli_build fbxctest $OUTPUT_DIRECTORY;;
      test)
        cli_framework_test fbxctest;;
      *)
        echo "Unknown Command $COMMAND"
        exit 1;;
    esac;;
  verify)
    if [[ -n $OUTPUT_DIRECTORY ]]; then
      verify_signatures "$OUTPUT_DIRECTORY"
    else
      echo "Please specify a directory to verify"
      exit 1
    fi;;
  *)
    echo "Unknown Command $TARGET"
    exit 1;;
esac

# vim: set tabstop=2 shiftwidth=2 filetype=sh: