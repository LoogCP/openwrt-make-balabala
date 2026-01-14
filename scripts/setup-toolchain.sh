#!/bin/bash

set -e

TOOLCHAIN_VERSION="${1:-21.02}"
ARCH="x86_64"
TARGET="x86"
SUBARCH="64"

echo "Setting up ImmortalWRT toolchain version $TOOLCHAIN_VERSION"

# 创建工具链目录
TOOLCHAIN_DIR="/opt/immortalwrt-toolchain"
sudo mkdir -p $TOOLCHAIN_DIR

# 根据版本选择下载 URL
case $TOOLCHAIN_VERSION in
    "19.07")
        SDK_URL="https://downloads.immortalwrt.org/releases/19.07/targets/$TARGET/$SUBARCH/immortalwrt-sdk-19.07-$TARGET-${SUBARCH}_gcc-7.5.0_musl.Linux-x86_64.tar.xz"
        ;;
    "21.02")
        SDK_URL="https://downloads.immortalwrt.org/releases/21.02/targets/$TARGET/$SUBARCH/immortalwrt-sdk-21.02-$TARGET-${SUBARCH}_gcc-8.4.0_musl.Linux-x86_64.tar.xz"
        ;;
    "22.03")
        SDK_URL="https://downloads.immortalwrt.org/releases/22.03/targets/$TARGET/$SUBARCH/immortalwrt-sdk-22.03-$TARGET-${SUBARCH}_gcc-11.2.0_musl.Linux-x86_64.tar.xz"
        ;;
    "snapshot")
        SDK_URL="https://downloads.immortalwrt.org/snapshots/targets/$TARGET/$SUBARCH/immortalwrt-sdk-$TARGET-${SUBARCH}_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
        ;;
    *)
        echo "Unsupported toolchain version: $TOOLCHAIN_VERSION"
        exit 1
        ;;
esac

# 下载并解压工具链
echo "Downloading ImmortalWRT SDK..."
wget -O /tmp/sdk.tar.xz $SDK_URL

echo "Extracting toolchain..."
sudo tar -xJf /tmp/sdk.tar.xz -C $TOOLCHAIN_DIR --strip-components=1

# 设置环境变量
echo "Setting up environment variables..."
export STAGING_DIR=$TOOLCHAIN_DIR/staging_dir
export PATH=$TOOLCHAIN_DIR/staging_dir/toolchain-$ARCH_gcc-*_musl/bin:$PATH

# 保存环境变量供后续步骤使用
echo "STAGING_DIR=$STAGING_DIR" >> $GITHUB_ENV
echo "PATH=$PATH" >> $GITHUB_ENV

echo "Toolchain setup complete!"
