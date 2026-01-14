#!/bin/bash

set -e

PACKAGE_NAME="$1"
SOURCE_TYPE="$2"
SOURCE_PATH="$3"
COMMIT_LOG_DIR="$4"
BUILD_STATUS_DIR="$5"

echo "Building package: $PACKAGE_NAME"

# 创建构建目录和状态目录
BUILD_DIR="/tmp/build-$PACKAGE_NAME-$(date +%s)"
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_STATUS_DIR"

# 记录开始时间
START_TIME=$(date +%s)
echo "START_TIME=$START_TIME" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}_start.txt"

# 设置构建状态初始值
BUILD_STATUS="failure"
SKIP_REASON=""

# 检查是否需要编译
if [ -f "$BUILD_STATUS_DIR/${PACKAGE_NAME}_skip" ]; then
    echo "Skipping $PACKAGE_NAME as requested"
    SKIP_REASON="no_changes"
    BUILD_STATUS="skipped"
    
    # 记录跳过状态
    echo "status=skipped" > "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
    echo "reason=no_changes" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
    echo "start_time=$START_TIME" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
    echo "end_time=$(date +%s)" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
    
    exit 0
fi

# 准备源码
echo "Preparing source for $PACKAGE_NAME from $SOURCE_TYPE..."

if [ "$SOURCE_TYPE" = "repo" ]; then
    # 从repos文件获取仓库信息
    REPO_INFO=$(grep "^$PACKAGE_NAME|" repos | head -1)
    if [ -z "$REPO_INFO" ]; then
        echo "ERROR: Repository info not found for $PACKAGE_NAME"
        BUILD_STATUS="error"
        SKIP_REASON="repo_not_found"
        exit 1
    fi
    
    IFS='|' read -r NAME PROTOCOL REPO_URL BRANCH <<< "$REPO_INFO"
    
    # 如果没指定分支，使用默认值
    BRANCH="${BRANCH:-master}"
    
    echo "Cloning $PROTOCOL repository: $REPO_URL (branch: $BRANCH)"
    
    case $PROTOCOL in
        "git")
            git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$BUILD_DIR/source"
            ;;
        "svn")
            svn checkout "$REPO_URL" "$BUILD_DIR/source"
            ;;
        "hg")
            hg clone -b "$BRANCH" "$REPO_URL" "$BUILD_DIR/source"
            ;;
        *)
            echo "ERROR: Unsupported protocol: $PROTOCOL"
            BUILD_STATUS="error"
            SKIP_REASON="unsupported_protocol"
            exit 1
            ;;
    esac
    
elif [ "$SOURCE_TYPE" = "file" ]; then
    # 从packages目录复制
    if [ -d "packages/$PACKAGE_NAME" ]; then
        echo "Copying local package from packages/$PACKAGE_NAME"
        cp -r "packages/$PACKAGE_NAME/"* "$BUILD_DIR/source/"
    else
        echo "ERROR: Local package not found: packages/$PACKAGE_NAME"
        BUILD_STATUS="error"
        SKIP_REASON="package_not_found"
        exit 1
    fi
else
    echo "ERROR: Unknown source type: $SOURCE_TYPE"
    BUILD_STATUS="error"
    SKIP_REASON="unknown_source_type"
    exit 1
fi

# 检查Makefile
if [ ! -f "$BUILD_DIR/source/Makefile" ]; then
    echo "ERROR: Makefile not found in source directory"
    BUILD_STATUS="error"
    SKIP_REASON="no_makefile"
    exit 1
fi

# 设置编译环境
echo "Setting up build environment..."
export ARCH="x86_64"
export CROSS_COMPILE="x86_64-openwrt-linux-musl-"
export CC="${CROSS_COMPILE}gcc"
export CXX="${CROSS_COMPILE}g++"
export AR="${CROSS_COMPILE}ar"
export AS="${CROSS_COMPILE}as"
export LD="${CROSS_COMPILE}ld"
export STRIP="${CROSS_COMPILE}strip"
export RANLIB="${CROSS_COMPILE}ranlib"

# 执行构建
echo "Building $PACKAGE_NAME..."
cd "$BUILD_DIR/source"

if make -j$(nproc); then
    BUILD_STATUS="success"
    echo "Build successful for $PACKAGE_NAME"
else
    BUILD_STATUS="failure"
    echo "Build failed for $PACKAGE_NAME"
    exit 1
fi

# 收集构建产物
echo "Collecting build artifacts..."
ARTIFACT_FILES=$(find . -type f \( -executable -o -name "*.apk" -o -name "*.ipk" -o -name "*.deb" -o -name "*.bin" \) ! -path "*/.*" 2>/dev/null || true)

if [ -n "$ARTIFACT_FILES" ]; then
    echo "Found artifacts:"
    echo "$ARTIFACT_FILES"
else
    echo "No standard artifacts found, looking for any output files..."
    # 如果没有找到标准文件，查找最近修改的文件
    ARTIFACT_FILES=$(find . -type f ! -path "*/.*" -mmin -10 2>/dev/null | head -20 || true)
fi

# 记录构建结束时间
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# 保存构建状态
echo "status=$BUILD_STATUS" > "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
echo "duration=$DURATION" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
echo "start_time=$START_TIME" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
echo "end_time=$END_TIME" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
if [ -n "$SKIP_REASON" ]; then
    echo "reason=$SKIP_REASON" >> "$BUILD_STATUS_DIR/${PACKAGE_NAME}.status"
fi

echo "Build process completed for $PACKAGE_NAME with status: $BUILD_STATUS"
