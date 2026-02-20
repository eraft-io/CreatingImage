#!/bin/bash

# macOS PKG 打包脚本 - 生成可在 M 芯片 Mac 上运行的安装包
# 用法: ./build_pkg.sh [intel|arm64|universal]
#   intel     - 仅构建 Intel 架构版本
#   arm64     - 仅构建 M 芯片架构版本
#   universal - 构建通用二进制（默认）

set -e

# 解析命令行参数
BUILD_ARCH="${1:-universal}"  # 默认为 universal

APP_NAME="CreatingImage"
APP_BUNDLE="${APP_NAME}.app"

# 根据架构设置包名
if [ "${BUILD_ARCH}" = "intel" ]; then
    PKG_NAME="${APP_NAME}-macos-intel.pkg"
    WAILS_BUILD_FLAGS="-platform darwin/amd64"
    echo "=========================================="
    echo "开始打包 Intel 架构 macOS PKG 安装包"
    echo "=========================================="
elif [ "${BUILD_ARCH}" = "arm64" ]; then
    PKG_NAME="${APP_NAME}-macos-arm64.pkg"
    WAILS_BUILD_FLAGS="-platform darwin/arm64"
    echo "=========================================="
    echo "开始打包 M 芯片架构 macOS PKG 安装包"
    echo "=========================================="
else
    PKG_NAME="${APP_NAME}-macos-universal.pkg"
    WAILS_BUILD_FLAGS=""  # 默认构建通用二进制
    echo "=========================================="
    echo "开始打包通用二进制 macOS PKG 安装包"
    echo "=========================================="
fi

BUILD_DIR="build/bin"
RESOURCES_DIR="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources"

# 0. 生成应用图标
echo "[0/7] 生成应用图标..."
if [ -f "imgs/logo.png" ]; then
    if [ ! -f "create_icns.sh" ]; then
        echo "      ✗ 错误: 找不到 create_icns.sh 脚本"
        exit 1
    fi
    ./create_icns.sh
    echo "      ✓ 图标已生成"
else
    echo "      ⚠ 警告: 找不到 imgs/logo.png，使用默认图标"
fi

# 1. 构建应用（确保是通用二进制，支持 Intel 和 M 芯片）
echo "[1/7] 构建通用二进制应用..."
export PATH=$PATH:$(go env GOPATH)/bin

# 清理之前的构建
go clean -cache 2>/dev/null || true
rm -rf "${BUILD_DIR}"

# 确保图标目录存在
mkdir -p "build/darwin"

# 验证图标
if [ -f "build/darwin/iconfile.icns" ]; then
    ICON_SIZE=$(ls -lh build/darwin/iconfile.icns | awk '{print $5}')
    echo "      图标大小: ${ICON_SIZE}"
fi

# 构建应用
echo "      开始构建..."
# 根据架构选择构建参数
if [ "${BUILD_ARCH}" = "intel" ]; then
    echo "      构建 Intel 架构应用..."
    # 设置 Go 环境变量确保构建 Intel 架构
    export GOOS=darwin
    export GOARCH=amd64
    export CGO_ENABLED=1
    wails build -platform darwin/amd64 -clean
elif [ "${BUILD_ARCH}" = "arm64" ]; then
    echo "      构建 M 芯片架构应用..."
    export GOOS=darwin
    export GOARCH=arm64
    export CGO_ENABLED=1
    wails build -platform darwin/arm64 -clean
else
    echo "      构建通用二进制应用..."
    wails build -platform darwin/universal -clean
fi

# 验证构建的架构
echo "      验证应用架构..."
APP_BINARY="${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
if [ -f "${APP_BINARY}" ]; then
    ARCH_INFO=$(file "${APP_BINARY}")
    echo "      二进制架构: ${ARCH_INFO}"
    
    # 检查架构是否匹配
    if [ "${BUILD_ARCH}" = "intel" ]; then
        if echo "${ARCH_INFO}" | grep -q "x86_64"; then
            echo "      ✓ Intel 架构验证通过"
        else
            echo "      ✗ 错误: 未找到 Intel (x86_64) 架构"
        fi
    elif [ "${BUILD_ARCH}" = "arm64" ]; then
        if echo "${ARCH_INFO}" | grep -q "arm64"; then
            echo "      ✓ ARM64 架构验证通过"
        else
            echo "      ✗ 错误: 未找到 ARM64 架构"
        fi
    else
        if echo "${ARCH_INFO}" | grep -q "universal"; then
            echo "      ✓ 通用二进制验证通过"
        else
            echo "      ⚠ 警告: 可能不是通用二进制"
        fi
    fi
else
    echo "      ✗ 错误: 找不到应用二进制文件"
fi

# 验证构建后的图标
echo "      验证应用图标..."
APP_ICON="${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/iconfile.icns"
if [ -f "${APP_ICON}" ]; then
    APP_ICON_SIZE=$(ls -lh "${APP_ICON}" | awk '{print $5}')
    echo "      应用图标大小: ${APP_ICON_SIZE}"
    
    # 比较图标大小（如果应用图标远小于源图标，可能是默认图标）
    SOURCE_ICON_SIZE=$(stat -f%z "build/darwin/iconfile.icns" 2>/dev/null || echo "0")
    APP_ICON_SIZE_BYTES=$(stat -f%z "${APP_ICON}" 2>/dev/null || echo "0")
    
    if [ "$APP_ICON_SIZE_BYTES" -lt "$SOURCE_ICON_SIZE" ]; then
        echo "      ⚠ 警告: 应用图标可能比预期小，可能使用了默认图标"
    else
        echo "      ✓ 应用图标已正确包含"
    fi
else
    echo "      ✗ 错误: 应用图标未找到"
fi

# 2. 复制 gen_image.py 到 app bundle 的 Resources 目录
echo "[2/7] 复制 gen_image.py 到应用 bundle..."
if [ -f "../gen_image.py" ]; then
    cp ../gen_image.py "${RESOURCES_DIR}/"
    echo "      ✓ 已复制 gen_image.py"
else
    echo "      ✗ 错误: 找不到 ../gen_image.py"
    exit 1
fi

# 3. 复制 requirements.txt
echo "[3/7] 复制 requirements.txt..."
if [ -f "python/requirements.txt" ]; then
    cp python/requirements.txt "${RESOURCES_DIR}/"
    echo "      ✓ 已复制 requirements.txt"
fi

# 4. 预安装 Python 依赖
echo "[4/6] 预安装 Python 依赖..."
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

# 根据构建架构选择 torch 版本
# 优先使用命令行参数指定的架构，否则检测当前系统架构
if [ "${BUILD_ARCH}" = "intel" ]; then
    TARGET_ARCH="intel"
elif [ "${BUILD_ARCH}" = "arm64" ]; then
    TARGET_ARCH="arm64"
else
    # 检测当前系统架构
    TARGET_ARCH=$(uname -m)
fi

echo "      目标架构: ${TARGET_ARCH}"

if [ "${TARGET_ARCH}" = "arm64" ]; then
    # M 芯片 Mac - 使用 pip 默认源（PyPI 有 ARM64 版本）
    echo "      安装 M 芯片兼容的 torch..."
    "${PIP_CMD}" install \
        "torch>=2.0.0" \
        "torchvision>=0.15.0" \
        --quiet
    
    "${PIP_CMD}" install \
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

# 5. 验证应用架构（确保支持 arm64）
echo "[5/7] 验证应用架构..."
ARCHS=$(lipo -archs "${BUILD_DIR}/${APP_BUNDLE}/Contents/MacOS/${APP_NAME}")
echo "      支持的架构: ${ARCHS}"

if echo "${ARCHS}" | grep -q "arm64"; then
    echo "      ✓ 支持 M 芯片 (arm64)"
else
    echo "      ⚠ 警告: 可能不支持 M 芯片"
fi

if echo "${ARCHS}" | grep -q "x86_64"; then
    echo "      ✓ 支持 Intel 芯片 (x86_64)"
fi

# 6. 创建 PKG 组件包
echo "[6/7] 创建 PKG 组件包..."

# 创建临时目录
PKG_TEMP=$(mktemp -d)
PKG_COMPONENTS="${PKG_TEMP}/components"
mkdir -p "${PKG_COMPONENTS}"

# 复制应用到临时目录
mkdir -p "${PKG_COMPONENTS}/Applications"
cp -R "${BUILD_DIR}/${APP_BUNDLE}" "${PKG_COMPONENTS}/Applications/"

# 创建组件 plist
cat > "${PKG_TEMP}/component.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<array>
    <dict>
        <key>BundleHasStrictIdentifier</key>
        <true/>
        <key>BundleIsRelocatable</key>
        <false/>
        <key>BundleIsVersionChecked</key>
        <false/>
        <key>BundleOverwriteAction</key>
        <string>upgrade</string>
        <key>RootRelativeBundlePath</key>
        <string>Applications/${APP_BUNDLE}</string>
    </dict>
</array>
</plist>
EOF

# 创建分发 plist
cat > "${PKG_TEMP}/distribution.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script min-spec-version="1">
    <title>AI 图片生成器</title>
    <organization>com.yourcompany.wailsimageapp</organization>
    <domains enable_localSystem="true"/>
    <options customize="never" require-scripts="true" rootVolumeOnly="true" />
    <background file="background.png" alignment="topleft" scaling="none"/>
    <welcome file="welcome.txt"/>
    <conclusion file="conclusion.txt"/>
    <pkg-ref id="com.yourcompany.wailsimageapp"/>
    <pkg-ref id="com.yourcompany.wailsimageapp.app" version="1.0" onConclusion="none">${APP_NAME}.pkg</pkg-ref>
    <choices-outline>
        <line choice="default">
            <line choice="com.yourcompany.wailsimageapp.app"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="com.yourcompany.wailsimageapp.app" visible="false">
        <pkg-ref id="com.yourcompany.wailsimageapp.app"/>
    </choice>
</installer-gui-script>
EOF

# 创建组件 pkg
pkgbuild \
    --root "${PKG_COMPONENTS}" \
    --component-plist "${PKG_TEMP}/component.plist" \
    --identifier "com.yourcompany.wailsimageapp" \
    --version "1.0.0" \
    --install-location "/" \
    "${PKG_TEMP}/${APP_NAME}.pkg"

# 7. 创建最终分发 PKG
echo "[7/7] 创建最终分发 PKG..."

# 创建资源目录
mkdir -p "${PKG_TEMP}/Resources"

# 创建欢迎文本
cat > "${PKG_TEMP}/Resources/welcome.txt" << 'EOF'
欢迎使用 AI 图片生成器

本应用基于 Stable Diffusion XL 模型，可以通过文字描述生成图片。

安装说明：
1. 首次启动时需要安装 Python 依赖（约 5-10 分钟）
2. 如果本地没有模型，会自动下载（约 5-10GB）
3. 支持 M 芯片和 Intel 芯片的 Mac

系统要求：
- macOS 11.0 或更高版本
- 至少 8GB 内存
- 约 10GB 可用磁盘空间
EOF

# 创建结束文本
cat > "${PKG_TEMP}/Resources/conclusion.txt" << 'EOF'
安装完成！

AI 图片生成器已成功安装到您的应用程序文件夹。

首次使用说明：
1. 从启动台或应用程序文件夹打开 "CreatingImage"
2. 首次启动会自动配置 Python 环境
3. 如果提示下载模型，请耐心等待（约 5-10GB）
4. 配置完成后即可开始生成图片

提示：
- 生成图片需要一定时间，请耐心等待
- 可以在日志区域查看详细进度
- 支持中文提示词

祝您使用愉快！
EOF

# 创建产品归档
productbuild \
    --distribution "${PKG_TEMP}/distribution.xml" \
    --resources "${PKG_TEMP}/Resources" \
    --package-path "${PKG_TEMP}" \
    "${BUILD_DIR}/${PKG_NAME}"

# 清理临时目录
rm -rf "${PKG_TEMP}"

echo ""
echo "=========================================="
echo "PKG 打包完成！"
echo "=========================================="
echo "安装包位置: ${BUILD_DIR}/${PKG_NAME}"
echo ""
echo "安装说明:"
echo "1. 双击 ${PKG_NAME} 开始安装"
echo "2. 按照向导完成安装"
echo "3. 应用将安装到 /Applications 文件夹"
echo ""
echo "兼容性:"
echo "- 支持 M 芯片 (Apple Silicon)"
echo "- 支持 Intel 芯片"
echo "- 需要 macOS 11.0 或更高版本"
echo "=========================================="
