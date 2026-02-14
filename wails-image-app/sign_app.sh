#!/bin/bash

# macOS 应用签名脚本
# 需要 Apple Developer ID Application 证书

set -e

APP_NAME="CreatingImage"
APP_BUNDLE="${APP_NAME}.app"
BUILD_DIR="build/bin"

# 配置 - 修改为你的证书名称和 Bundle ID
# 证书名称可以从钥匙串中找到，格式如："Developer ID Application: Your Name (TEAM_ID)"
CERTIFICATE_NAME="Developer ID Application: Your Name (XXXXXXXXXX)"
BUNDLE_ID="com.yourcompany.wailsimageapp"

echo "=========================================="
echo "macOS 应用签名"
echo "=========================================="

# 检查证书是否设置
if [ "${CERTIFICATE_NAME}" = "Developer ID Application: Your Name (XXXXXXXXXX)" ]; then
    echo "错误: 请先修改脚本中的 CERTIFICATE_NAME 变量"
    echo ""
    echo "查找证书名称的方法："
    echo "1. 打开'钥匙串访问'应用"
    echo "2. 在'登录'或'系统'钥匙串中找到你的开发者证书"
    echo "3. 证书名称格式：'Developer ID Application: Your Name (TEAM_ID)'"
    exit 1
fi

# 检查应用是否存在
if [ ! -d "${BUILD_DIR}/${APP_BUNDLE}" ]; then
    echo "错误: 找不到应用 bundle: ${BUILD_DIR}/${APP_BUNDLE}"
    echo "请先构建应用: wails build -platform darwin/universal"
    exit 1
fi

echo "[1/6] 确保 gen_image.py 已打包..."
if [ ! -f "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/gen_image.py" ]; then
    cp ../gen_image.py "${BUILD_DIR}/${APP_BUNDLE}/Contents/Resources/"
fi

echo "[2/6] 更新 Bundle ID..."
# 使用 PlistBuddy 更新 Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${BUILD_DIR}/${APP_BUNDLE}/Contents/Info.plist"
echo "      Bundle ID: ${BUNDLE_ID}"

echo "[3/6] 签名应用..."
# 签名应用
# --deep: 递归签名所有嵌套的可执行文件和库
# --force: 强制重新签名
# --options runtime: 启用强化运行时（推荐）
codesign \
    --sign "${CERTIFICATE_NAME}" \
    --deep \
    --force \
    --options runtime \
    --entitlements build/darwin/Info.plist \
    --timestamp \
    "${BUILD_DIR}/${APP_BUNDLE}"

echo "      ✓ 签名完成"

echo "[4/6] 验证签名..."
codesign -dv "${BUILD_DIR}/${APP_BUNDLE}"

echo "[5/6] 验证代码完整性..."
codesign --verify --verbose "${BUILD_DIR}/${APP_BUNDLE}"

echo "[6/6] 公证应用（可选）..."
echo "      如果要分发到 Mac App Store 外，建议进行公证"
echo "      命令: xcrun notarytool submit ${APP_NAME}.zip --apple-id your@email.com --team-id XXXXXXXXXX --wait"

echo ""
echo "=========================================="
echo "签名完成！"
echo "=========================================="
echo ""
echo "签名后的应用: ${BUILD_DIR}/${APP_BUNDLE}"
echo ""
echo "验证签名:"
echo "  codesign -dv ${BUILD_DIR}/${APP_BUNDLE}"
echo ""
echo "检查是否可以通过门禁:"
echo "  spctl -a -vv ${BUILD_DIR}/${APP_BUNDLE}"
echo ""
echo "注意："
echo "1. 签名后的应用可以在其他 Mac 上运行，不会显示'无法验证开发者'"
echo "2. 如果分发到 Mac App Store 外，建议进行公证（notarization）"
echo "3. 用户首次运行时可能仍需要右键->打开"
echo "=========================================="
