#!/bin/bash

# 创建 Windows 图标 (.ico) 文件
# 需要安装 ImageMagick: brew install imagemagick

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# 检查 logo.png 是否存在
if [ ! -f "imgs/logo.png" ]; then
    echo "错误: 找不到 imgs/logo.png"
    exit 1
fi

# 检查 ImageMagick 是否安装
if ! command -v convert &> /dev/null; then
    echo "错误: 未找到 ImageMagick 的 convert 命令"
    echo "请安装 ImageMagick: brew install imagemagick"
    exit 1
fi

echo "创建 Windows 图标..."

# 创建图标目录
mkdir -p build/windows

# 生成不同尺寸的图标
convert imgs/logo.png -resize 16x16 build/windows/icon_16.png
convert imgs/logo.png -resize 32x32 build/windows/icon_32.png
convert imgs/logo.png -resize 48x48 build/windows/icon_48.png
convert imgs/logo.png -resize 64x64 build/windows/icon_64.png
convert imgs/logo.png -resize 128x128 build/windows/icon_128.png
convert imgs/logo.png -resize 256x256 build/windows/icon_256.png

# 合并为 .ico 文件
convert build/windows/icon_16.png \
        build/windows/icon_32.png \
        build/windows/icon_48.png \
        build/windows/icon_64.png \
        build/windows/icon_128.png \
        build/windows/icon_256.png \
        build/windows/icon.ico

echo "✓ Windows 图标已创建: build/windows/icon.ico"

# 清理临时文件
rm -f build/windows/icon_*.png

echo "完成！"
