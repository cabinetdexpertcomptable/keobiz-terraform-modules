#!/bin/bash
# ============================================
# Upload Lambda packages to S3
# ============================================
# Usage:
#   ./scripts/upload.sh [VERSION] [S3_BUCKET] [S3_PREFIX]
#   ./scripts/upload.sh abc1234 keobiz-lambda-packages my-project
# ============================================

set -e

VERSION=${1:-$(git rev-parse --short HEAD 2>/dev/null || echo "local")}
S3_BUCKET=${2:-keobiz-lambda-packages}
S3_PREFIX=${3:-dynamic-project}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "Uploading Lambda packages to S3"
echo "Bucket: s3://$S3_BUCKET/$S3_PREFIX/"
echo "Version: $VERSION"
echo "============================================"

# Find all ZIP files with the version
ZIPS=$(find "$PROJECT_DIR" -maxdepth 1 -name "*-lambda-${VERSION}.zip" -type f)

if [ -z "$ZIPS" ]; then
    echo "No packages found for version $VERSION"
    echo "Run ./scripts/build.sh first"
    exit 1
fi

# Upload each ZIP
for ZIP in $ZIPS; do
    FILENAME=$(basename "$ZIP")
    echo "Uploading: $FILENAME"
    aws s3 cp "$ZIP" "s3://$S3_BUCKET/$S3_PREFIX/$FILENAME"
done

echo ""
echo "============================================"
echo "Upload complete"
echo "============================================"

