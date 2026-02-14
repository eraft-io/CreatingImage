#!/bin/bash

# 构建 Windows 版本的 exe 可执行程序
# 注意：在 macOS 上交叉编译 Windows 版本需要安装 mingw-w64

set -e

APP_NAME="CreatingImage"
BUILD_DIR="build/bin"

echo "=========================================="
echo "构建 Windows 版本"
echo "=========================================="

# 检查是否安装了 mingw-w64
if ! command -v x86_64-w64-mingw32-gcc &> /dev/null; then
    echo "警告: 未找到 mingw-w64 交叉编译器"
    echo "在 macOS 上构建 Windows 版本需要安装 mingw-w64:"
    echo "  brew install mingw-w64"
    echo ""
    read -p "是否继续尝试构建? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

export PATH=$PATH:$(go env GOPATH)/bin

# 清理
go clean -cache 2>/dev/null || true

echo "[1/3] 构建 Windows amd64 版本..."
# 设置 Windows 交叉编译环境
export CGO_ENABLED=1
export GOOS=windows
export GOARCH=amd64
export CC=x86_64-w64-mingw32-gcc
export CXX=x86_64-w64-mingw32-g++

# 构建
wails build -platform windows/amd64 -o "${APP_NAME}.exe" || {
    echo ""
    echo "=========================================="
    echo "构建失败"
    echo "=========================================="
    echo ""
    echo "在 macOS 上交叉编译 Windows 版本需要："
    echo "1. 安装 mingw-w64:"
    echo "   brew install mingw-w64"
    echo ""
    echo "2. 如果仍然失败，建议在 Windows 机器上直接构建："
    echo "   wails build -platform windows/amd64"
    echo ""
    echo "或者使用 GitHub Actions 自动构建多平台版本"
    echo "=========================================="
    exit 1
}

echo "[2/3] 复制资源文件..."
WINDOWS_DIR="${BUILD_DIR}/windows"
mkdir -p "${WINDOWS_DIR}"

# 复制可执行文件
if [ -f "${BUILD_DIR}/${APP_NAME}.exe" ]; then
    cp "${BUILD_DIR}/${APP_NAME}.exe" "${WINDOWS_DIR}/"
    echo "      ✓ ${APP_NAME}.exe"
fi

# 复制 gen_image.py
if [ -f "../gen_image.py" ]; then
    cp "../gen_image.py" "${WINDOWS_DIR}/"
    echo "      ✓ gen_image.py"
fi

# 复制 requirements.txt
if [ -f "python/requirements.txt" ]; then
    cp python/requirements.txt "${WINDOWS_DIR}/"
    echo "      ✓ requirements.txt"
fi

# 复制图标
if [ -f "imgs/logo.png" ]; then
    cp "imgs/logo.png" "${WINDOWS_DIR}/"
    echo "      ✓ logo.png"
fi

echo "[3/3] 创建 ZIP 压缩包..."
cd "${BUILD_DIR}"
zip -r "${APP_NAME}-windows.zip" "windows/"
ZIP_SIZE=$(du -h "${APP_NAME}-windows.zip" | cut -f1)
cd ..

echo ""
echo "=========================================="
echo "Windows 版本构建完成！"
echo "=========================================="
echo ""
echo "文件: ${BUILD_DIR}/${APP_NAME}-windows.zip"
echo "大小: ${ZIP_SIZE}"
echo ""
echo "注意："
echo "1. Windows 版本不包含预装的 Python 依赖"
echo "2. 用户需要自行安装 Python 3.10+"
echo "3. 首次启动时会自动安装依赖"
echo ""
echo "使用说明："
echo "1. 解压 ZIP 文件到任意目录"
echo "2. 确保已安装 Python 3.10 或更高版本"
echo "3. 运行 ${APP_NAME}.exe"
echo "4. 首次启动会自动配置 Python 环境"
echo "=========================================="
