#!/bin/bash

set -e

PACKAGE_NAME="$1"
SOURCE_TYPE="$2"
SOURCE_PATH="$3"
COMMIT_LOG_DIR="$4"

echo "Checking commit history for $PACKAGE_NAME..."

# 创建提交日志目录
mkdir -p "$COMMIT_LOG_DIR"
COMMIT_LOG_FILE="$COMMIT_LOG_DIR/$PACKAGE_NAME.commit"

# 根据来源类型获取最后一次提交
if [ "$SOURCE_TYPE" = "git" ]; then
    # Git仓库：获取最后一次提交哈希和日期
    LAST_COMMIT=$(git -C "$SOURCE_PATH" log -1 --format="%H|%cd" --date=iso-strict 2>/dev/null || echo "unknown")
    echo "Git last commit: $LAST_COMMIT"
    
elif [ "$SOURCE_TYPE" = "svn" ]; then
    # SVN仓库：获取最后版本号和日期
    # 注意：这里需要svn客户端支持
    LAST_REVISION=$(svn info "$SOURCE_PATH" | grep "Last Changed Rev" | cut -d: -f2 | tr -d ' ' 2>/dev/null || echo "unknown")
    LAST_DATE=$(svn info "$SOURCE_PATH" | grep "Last Changed Date" | cut -d: -f2- | tr -d ' ' 2>/dev/null || echo "unknown")
    LAST_COMMIT="r$LAST_REVISION|$LAST_DATE"
    echo "SVN last revision: $LAST_COMMIT"
    
elif [ "$SOURCE_TYPE" = "hg" ]; then
    # Mercurial仓库：获取最后一次变更集
    CHANGESET=$(hg -R "$SOURCE_PATH" log -l 1 --template "{node}|{date|isodatesec}" 2>/dev/null || echo "unknown")
    LAST_COMMIT="$CHANGESET"
    echo "HG last changeset: $LAST_COMMIT"
    
elif [ "$SOURCE_TYPE" = "file" ]; then
    # 本地文件夹：计算文件夹内容的哈希值
    if [ -d "$SOURCE_PATH" ]; then
        # 计算所有文件的MD5总和
        FILE_HASH=$(find "$SOURCE_PATH" -type f -name "*" ! -path "*/.*" -exec md5sum {} \; 2>/dev/null | \
                   sort -k2 | md5sum | cut -d' ' -f1 || echo "unknown")
        LAST_COMMIT="local|$(date +%Y-%m-%dT%H:%M:%S)|$FILE_HASH"
        echo "Local directory hash: $FILE_HASH"
    else
        LAST_COMMIT="local|$(date +%Y-%m-%dT%H:%M:%S)|unknown"
    fi
    
else
    LAST_COMMIT="unknown|$(date +%Y-%m-%dT%H:%M:%S)"
fi

# 检查是否有上次编译的记录
if [ -f "$COMMIT_LOG_FILE" ]; then
    PREVIOUS_COMMIT=$(cat "$COMMIT_LOG_FILE")
    echo "Previous commit: $PREVIOUS_COMMIT"
    echo "Current commit: $LAST_COMMIT"
    
    if [ "$PREVIOUS_COMMIT" = "$LAST_COMMIT" ]; then
        echo "No changes detected. Skipping compilation for $PACKAGE_NAME."
        SKIP_COMPILE="true"
    else
        echo "Changes detected. Need to compile $PACKAGE_NAME."
        SKIP_COMPILE="false"
    fi
else
    echo "No previous commit record found. Need to compile $PACKAGE_NAME."
    SKIP_COMPILE="false"
fi

# 输出结果供调用脚本使用
echo "SKIP_COMPILE=$SKIP_COMPILE" >> $GITHUB_ENV
echo "LAST_COMMIT=$LAST_COMMIT" >> $GITHUB_ENV

# 如果跳过编译，也返回跳过状态
if [ "$SKIP_COMPILE" = "true" ]; then
    exit 2  # 特殊退出码表示跳过
fi
