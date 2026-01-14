#!/bin/bash

set -e

TELEGRAM_BOT_TOKEN="$1"
TELEGRAM_CHAT_ID="$2"
BUILD_STATUS_DIR="$3"
GITHUB_REPOSITORY="$4"
GITHUB_RUN_ID="$5"
WORKFLOW_STATUS="$6"

echo "Sending Telegram notification..."

# 读取汇总信息
SUMMARY_FILE="$BUILD_STATUS_DIR/summary.txt"
if [ ! -f "$SUMMARY_FILE" ]; then
    echo "ERROR: Summary file not found"
    exit 1
fi

# 读取详细状态
STATUS_DETAILS=$(tail -n +8 "$SUMMARY_FILE" | sed ':a;N;$!ba;s/\n/%0A/g' | sed 's/✅/✅/g;s/❌/❌/g;s/⏭️/⏭️/g;s/⚠️/⚠️/g;s/❓/❓/g')

# 读取统计数据
TOTAL_BUILDS=$(grep "Total packages:" "$SUMMARY_FILE" | cut -d: -f2 | tr -d ' ')
SUCCESS_BUILDS=$(grep "Successful:" "$SUMMARY_FILE" | cut -d: -f2 | tr -d ' ')
FAILED_BUILDS=$(grep "Failed:" "$SUMMARY_FILE" | cut -d: -f2 | tr -d ' ')
SKIPPED_BUILDS=$(grep "Skipped:" "$SUMMARY_FILE" | cut -d: -f2 | tr -d ' ')

# 确定整体状态表情
if [ "$WORKFLOW_STATUS" = "success" ]; then
    if [ "$FAILED_BUILDS" -eq 0 ]; then
        WORKFLOW_EMOJI="🎉"
        WORKFLOW_STATUS_TEXT="成功"
    else
        WORKFLOW_EMOJI="⚠️"
        WORKFLOW_STATUS_TEXT="部分成功"
    fi
else
    WORKFLOW_EMOJI="💥"
    WORKFLOW_STATUS_TEXT="失败"
fi

# 构建消息
MESSAGE="<b>ImmortalWRT 编译完成 $WORKFLOW_EMOJI</b>%0A%0A"
MESSAGE+="<b>仓库:</b> $GITHUB_REPOSITORY%0A"
MESSAGE+="<b>运行ID:</b> #$GITHUB_RUN_ID%0A"
MESSAGE+="<b>整体状态:</b> $WORKFLOW_STATUS_TEXT%0A"
MESSAGE+="<b>编译时间:</b> $(date '+%Y-%m-%d %H:%M:%S')%0A%0A"

MESSAGE+="<b>📊 编译统计:</b>%0A"
MESSAGE+="总包数: $TOTAL_BUILDS%0A"
MESSAGE+="✅ 成功: $SUCCESS_BUILDS%0A"
MESSAGE+="❌ 失败: $FAILED_BUILDS%0A"
MESSAGE+="⏭️ 跳过: $SKIPPED_BUILDS%0A%0A"

if [ -n "$STATUS_DETAILS" ]; then
    MESSAGE+="<b>📋 详细状态:</b>%0A"
    MESSAGE+="$STATUS_DETAILS%0A%0A"
fi

MESSAGE+="<b>🔗 相关链接:</b>%0A"
MESSAGE+="GitHub Actions: https://github.com/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID%0A"
MESSAGE+="编译输出: https://github.com/$GITHUB_REPOSITORY/tree/outputs"

# 发送到Telegram
TELEGRAM_URL="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

curl -s -X POST "$TELEGRAM_URL" \
    -d chat_id="$TELEGRAM_CHAT_ID" \
    -d text="$MESSAGE" \
    -d parse_mode="HTML" \
    -d disable_web_page_preview="true" > /tmp/telegram_response.json

if [ $? -eq 0 ]; then
    echo "Telegram notification sent successfully"
else
    echo "ERROR: Failed to send Telegram notification"
    cat /tmp/telegram_response.json
    exit 1
fi
