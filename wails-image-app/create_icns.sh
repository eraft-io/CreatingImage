#!/bin/bash

# 将 logo.png 转换为 macOS 应用图标 (icns 格式)

set -e

LOGO_PATH="imgs/logo.png"
OUTPUT_DIR="build/darwin"
ICON_NAME="iconfile.icns"

echo "=========================================="
echo "创建 macOS 应用图标"
echo "=========================================="

# 检查 logo.png 是否存在
if [ ! -f "$LOGO_PATH" ]; then
    echo "错误: 找不到 $LOGO_PATH"
    exit 1
fi

echo "源文件: $LOGO_PATH"

# 创建临时目录（使用工作目录内的位置）
TEMP_DIR="build/temp_icon"
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
ICONSET_DIR="$TEMP_DIR/icon.iconset"
mkdir -p "$ICONSET_DIR"

# 生成不同尺寸的图标
echo "生成图标尺寸..."

# 16x16
sips -z 16 16 "$LOGO_PATH" --out "$ICONSET_DIR/icon_16x16.png"
# 16x16 @2x (32x32)
sips -z 32 32 "$LOGO_PATH" --out "$ICONSET_DIR/icon_16x16@2x.png"

# 32x32
sips -z 32 32 "$LOGO_PATH" --out "$ICONSET_DIR/icon_32x32.png"
# 32x32 @2x (64x64)
sips -z 64 64 "$LOGO_PATH" --out "$ICONSET_DIR/icon_32x32@2x.png"

# 128x128
sips -z 128 128 "$LOGO_PATH" --out "$ICONSET_DIR/icon_128x128.png"
# 128x128 @2x (256x256)
sips -z 256 256 "$LOGO_PATH" --out "$ICONSET_DIR/icon_128x128@2x.png"

# 256x256
sips -z 256 256 "$LOGO_PATH" --out "$ICONSET_DIR/icon_256x256.png"
# 256x256 @2x (512x512)
sips -z 512 512 "$LOGO_PATH" --out "$ICONSET_DIR/icon_256x256@2x.png"

# 512x512
sips -z 512 512 "$LOGO_PATH" --out "$ICONSET_DIR/icon_512x512.png"
# 512x512 @2x (1024x1024)
sips -z 1024 1024 "$LOGO_PATH" --out "$ICONSET_DIR/icon_512x512@2x.png"

echo "创建 icns 文件..."
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_DIR/$ICON_NAME"

# 清理
rm -rf "$TEMP_DIR"

echo ""
echo "=========================================="
echo "图标创建完成！"
echo "=========================================="
echo "输出文件: $OUTPUT_DIR/$ICON_NAME"
echo ""
echo "现在可以重新构建应用："
echo "  wails build -platform darwin/universal"
echo "=========================================="
