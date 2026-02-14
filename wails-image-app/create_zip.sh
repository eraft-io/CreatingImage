#!/bin/bash

# 创建 ZIP 分发包（最简单可靠的跨机器分发方式）

set -e

APP_NAME="CreatingImage"
APP_BUNDLE="${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-macos-universal.zip"
BUILD_DIR="build/bin"

echo "=========================================="
echo "创建 ZIP 分发包"
echo "=========================================="

# 1. 确保应用已构建
echo "[1/3] 检查应用 bundle..."
if [ ! -d "${BUILD_DIR}/${APP_BUNDLE}" ]; then
    echo "错误: 找不到应用 bundle"
    echo "请先运行: wails build -platform darwin/universal"
    exit 1
fi

# 2. 确保 gen_image.py 已复制
echo "[2/3] 确保 gen_image.py 已打包..."
if [ ! -f "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/gen_image.py" ]; then
    cp ../gen_image.py "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/"
    echo "      ✓ 已复制 gen_image.py"
fi

# 验证架构
echo "      验证架构支持..."
ARCHS=$(lipo -archs "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}")
echo "      支持的架构: ${ARCHS}"

# 3. 创建 ZIP
echo "[3/3] 创建 ZIP 压缩包..."
cd "${BUILD_DIR}"
rm -f "${ZIP_NAME}"
zip -ry "${ZIP_NAME}" "${APP_BUNDLE}"
cd ../..

echo ""
echo "=========================================="
echo "ZIP 创建完成！"
echo "=========================================="
echo "文件: ${BUILD_DIR}/${ZIP_NAME}"
echo ""
echo "在其他 Mac 上使用步骤:"
echo ""
echo "1. 传输文件"
echo "   将 ${ZIP_NAME} 复制到目标 Mac"
echo ""
echo "2. 解压"
echo "   双击 ZIP 文件解压"
echo ""
echo "3. 首次运行准备（二选一）"
echo ""
echo "   方法 A - 终端命令（推荐）:"
echo "   cd ~/Downloads"
echo "   xattr -rd com.apple.quarantine ${APP_BUNDLE}"
echo "   然后将应用拖到 Applications 文件夹"
echo ""
echo "   方法 B - 图形界面:"
echo "   - 将 ${APP_BUNDLE} 拖到 Applications 文件夹"
echo "   - 右键点击应用图标"
echo "   - 选择'打开'"
echo "   - 在弹出的对话框中点击'打开'按钮"
echo ""
echo "4. 如果系统阻止运行"
echo "   系统设置 -> 隐私与安全性 -> 安全性"
echo "   -> 点击'仍要打开'"
echo ""
echo "系统要求:"
echo "- macOS 11.0 或更高版本"
echo "- 支持 M 芯片 (Apple Silicon) 和 Intel 芯片"
echo "- 至少 8GB 内存"
echo "- 约 10GB 可用磁盘空间（用于模型下载）"
echo ""
echo "注意: 首次启动需要 5-10 分钟安装 Python 依赖"
echo "=========================================="
