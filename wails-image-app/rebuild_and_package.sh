#!/bin/bash

# 重新构建应用并打包（包含预安装依赖）
# 需要在沙箱外运行

set -e

APP_NAME="CreatingImage"
APP_BUNDLE="${APP_NAME}.app"
ZIP_NAME="${APP_NAME}-macos.zip"
BUILD_DIR="build/bin"

echo "=========================================="
echo "重新构建并打包应用"
echo "=========================================="

# 1. 构建应用
echo "[1/4] 构建应用..."
export PATH=$PATH:$(go env GOPATH)/bin
go clean -cache 2>/dev/null || true
wails build -platform darwin/universal

# 2. 复制资源文件
echo "[2/4] 复制资源文件..."
RESOURCES_DIR="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources"

if [ -f "../gen_image.py" ]; then
    cp ../gen_image.py "${RESOURCES_DIR}/"
    echo "      ✓ gen_image.py"
fi

if [ -f "python/requirements.txt" ]; then
    cp python/requirements.txt "${RESOURCES_DIR}/"
    echo "      ✓ requirements.txt"
fi

# 3. 预安装 Python 依赖
echo "[3/4] 预安装 Python 依赖..."

PYTHON_DIR="${RESOURCES_DIR}/python"
VENV_DIR="${PYTHON_DIR}/venv"

# 清理旧的虚拟环境
if [ -d "${VENV_DIR}" ]; then
    echo "      清理旧虚拟环境..."
    rm -rf "${VENV_DIR}"
fi

# 创建新的虚拟环境
echo "      创建 Python 虚拟环境..."
python3 -m venv "${VENV_DIR}"

# 安装依赖
PIP_CMD="${VENV_DIR}/bin/pip"
PYTHON_CMD="${VENV_DIR}/bin/python3"

echo "      升级 pip..."
"${PIP_CMD}" install --upgrade pip -q

echo "      安装依赖包（约 5-10 分钟）..."

# 先安装 numpy 1.x 版本（避免 NumPy 2.0 兼容性问题）
echo "      安装 numpy 1.x..."
"${PIP_CMD}" install "numpy<2" --quiet

# 检测芯片架构，选择合适的 torch 版本
ARCH=$(uname -m)
echo "      检测到架构: ${ARCH}"

if [ "${ARCH}" = "arm64" ]; then
    # M 芯片 Mac
    echo "      安装 M 芯片兼容的 torch..."
    "${PIP_CMD}" install \
        "torch>=2.0.0" \
        "transformers>=4.30.0" \
        "diffusers>=0.21.0" \
        "accelerate>=0.20.0" \
        "safetensors>=0.3.0" \
        "pillow>=9.0.0" \
        "modelscope>=1.9.0" \
        --quiet
else
    # Intel 芯片 Mac - 使用较稳定的 torch 2.6.0 版本（支持 Python 3.13）
    echo "      安装 Intel 芯片兼容的 torch..."
    "${PIP_CMD}" install \
        "torch==2.6.0" \
        "torchvision==0.21.0" \
        "transformers>=4.30.0" \
        "diffusers>=0.21.0" \
        "accelerate>=0.20.0" \
        "safetensors>=0.3.0" \
        "pillow>=9.0.0" \
        "modelscope>=1.9.0" \
        --quiet
fi

echo "      ✓ 依赖安装完成"

# 验证安装
echo "      验证 Python 环境..."
if "${PYTHON_CMD}" -c "import torch, transformers, diffusers, modelscope; print('OK')" 2>/dev/null; then
    echo "      ✓ Python 环境正常"
else
    echo "      ✗ Python 环境验证失败"
    exit 1
fi

# 显示大小
echo "      Python 环境大小:"
du -sh "${VENV_DIR}"

# 4. 创建 ZIP
echo "[4/4] 创建 ZIP 压缩包..."
cd "${BUILD_DIR}"
rm -f "${ZIP_NAME}"

# 压缩（保留符号链接）
zip -ry "${ZIP_NAME}" "${APP_BUNDLE}"

ZIP_SIZE=$(du -h "${ZIP_NAME}" | cut -f1)

cd ../..

echo ""
echo "=========================================="
echo "构建完成！"
echo "=========================================="
echo ""
echo "文件: ${BUILD_DIR}/${ZIP_NAME}"
echo "大小: ${ZIP_SIZE}"
echo ""
echo "此版本包含："
echo "  ✓ 修复后的 app.go（支持跨机器使用预装依赖）"
echo "  ✓ 预装的 Python 依赖"
echo ""
echo "用户首次启动时："
echo "  - 自动检测并修复虚拟环境路径"
echo "  - 保留预装的依赖包"
echo "  - 只需下载 AI 模型（约 5-10GB）"
echo ""
echo "使用说明："
echo "  1. 解压 ZIP"
echo "  2. 拖到 Applications"
echo "  3. 执行: sudo xattr -rd com.apple.quarantine /Applications/${APP_BUNDLE}"
echo "  4. 启动应用"
echo "=========================================="
