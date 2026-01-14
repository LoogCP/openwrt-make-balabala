#!/bin/bash

set -e

BUILD_STATUS_DIR="$1"
COMMIT_LOG_DIR="$2"
PACKAGE_NAME="$3"
LAST_COMMIT="$4"
BUILD_STATUS="$5"

echo "Updating status for $PACKAGE_NAME..."

# 更新提交记录（仅当构建成功时）
if [ "$BUILD_STATUS" = "success" ]; then
    echo "$LAST_COMMIT" > "$COMMIT_LOG_DIR/$PACKAGE_NAME.commit"
    echo "Updated commit record for $PACKAGE_NAME"
fi

# 汇总构建状态
TOTAL_BUILDS=$(find "$BUILD_STATUS_DIR" -name "*.status" | wc -l)
SUCCESS_BUILDS=$(grep -l "status=success" "$BUILD_STATUS_DIR"/*.status 2>/dev/null | wc -l)
FAILED_BUILDS=$(grep -l "status=failure" "$BUILD_STATUS_DIR"/*.status 2>/dev/null | wc -l)
SKIPPED_BUILDS=$(grep -l "status=skipped" "$BUILD_STATUS_DIR"/*.status 2>/dev/null | wc -l)
ERROR_BUILDS=$(grep -l "status=error" "$BUILD_STATUS_DIR"/*.status 2>/dev/null | wc -l)

# 生成汇总报告
SUMMARY_FILE="$BUILD_STATUS_DIR/summary.txt"
echo "# Build Summary" > "$SUMMARY_FILE"
echo "Generated: $(date)" >> "$SUMMARY_FILE"
echo "Total packages: $TOTAL_BUILDS" >> "$SUMMARY_FILE"
echo "Successful: $SUCCESS_BUILDS" >> "$SUMMARY_FILE"
echo "Failed: $FAILED_BUILDS" >> "$SUMMARY_FILE"
echo "Skipped: $SKIPPED_BUILDS" >> "$SUMMARY_FILE"
echo "Errors: $ERROR_BUILDS" >> "$SUMMARY_FILE"
echo "" >> "$SUMMARY_FILE"
echo "## Detailed Status" >> "$SUMMARY_FILE"

# 添加每个包的详细状态
for status_file in "$BUILD_STATUS_DIR"/*.status; do
    if [ -f "$status_file" ]; then
        PACKAGE=$(basename "$status_file" .status)
        STATUS=$(grep "^status=" "$status_file" | cut -d= -f2)
        DURATION=$(grep "^duration=" "$status_file" | cut -d= -f2 || echo "N/A")
        
        case $STATUS in
            "success")
                STATUS_EMOJI="✅"
                ;;
            "failure")
                STATUS_EMOJI="❌"
                ;;
            "skipped")
                STATUS_EMOJI="⏭️"
                ;;
            "error")
                STATUS_EMOJI="⚠️"
                ;;
            *)
                STATUS_EMOJI="❓"
                ;;
        esac
        
        echo "$STATUS_EMOJI $PACKAGE - $STATUS (${DURATION}s)" >> "$SUMMARY_FILE"
    fi
done

echo "Status update complete"
