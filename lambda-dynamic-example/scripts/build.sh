#!/bin/bash
# ============================================
# Dynamic Lambda Build Script (Node.js)
# ============================================
# Automatically discovers and builds all Lambda functions
# in the functions/ directory.
#
# Usage:
#   ./scripts/build.sh [VERSION]
#
# This script:
# 1. Finds all folders in functions/ with a config.json
# 2. Builds a ZIP package for each one
# 3. Includes shared/ code in each package
# ============================================

set -e

VERSION=${1:-$(git rev-parse --short HEAD 2>/dev/null || echo "local")}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build"
FUNCTIONS_DIR="$PROJECT_DIR/functions"
SHARED_DIR="$PROJECT_DIR/shared"

echo "============================================"
echo "Lambda Build Script (Node.js)"
echo "Version: $VERSION"
echo "============================================"

# Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Find all function directories (those with config.json)
FUNCTIONS=$(find "$FUNCTIONS_DIR" -maxdepth 2 -name "config.json" -exec dirname {} \;)

if [ -z "$FUNCTIONS" ]; then
    echo "No functions found in $FUNCTIONS_DIR"
    exit 1
fi

FUNCTION_COUNT=$(echo "$FUNCTIONS" | wc -l | tr -d ' ')
echo "Found $FUNCTION_COUNT function(s) to build"
echo ""

BUILT=0
for FUNC_DIR in $FUNCTIONS; do
    FUNC_NAME=$(basename "$FUNC_DIR")
    echo "Building: $FUNC_NAME"
    
    FUNC_BUILD_DIR="$BUILD_DIR/$FUNC_NAME"
    mkdir -p "$FUNC_BUILD_DIR"
    
    # Copy function code (JS files)
    cp "$FUNC_DIR"/*.js "$FUNC_BUILD_DIR/" 2>/dev/null || true
    
    # Copy shared code
    if [ -d "$SHARED_DIR" ]; then
        cp -r "$SHARED_DIR" "$FUNC_BUILD_DIR/"
    fi
    
    # Install function dependencies if any
    if [ -f "$FUNC_DIR/package.json" ]; then
        cp "$FUNC_DIR/package.json" "$FUNC_BUILD_DIR/"
        HAS_DEPS=$(node -e "const p = require('$FUNC_BUILD_DIR/package.json'); console.log(Object.keys(p.dependencies || {}).length > 0)" 2>/dev/null || echo "false")
        if [ "$HAS_DEPS" = "true" ]; then
            (cd "$FUNC_BUILD_DIR" && npm install --omit=dev --quiet 2>/dev/null)
        fi
        rm -f "$FUNC_BUILD_DIR/package-lock.json"
    fi
    
    # Create ZIP
    ZIP_NAME="${FUNC_NAME}-lambda-${VERSION}.zip"
    (cd "$FUNC_BUILD_DIR" && zip -rq "../../$ZIP_NAME" .)
    
    SIZE=$(ls -lh "$PROJECT_DIR/$ZIP_NAME" | awk '{print $5}')
    echo "  ✓ Created: $ZIP_NAME ($SIZE)"
    
    BUILT=$((BUILT + 1))
done

echo ""
echo "============================================"
echo "Build complete: $BUILT packages created"
echo "============================================"
ls -lh "$PROJECT_DIR"/*-lambda-*.zip 2>/dev/null || true
