#!/bin/bash

# Python 环境设置脚本
# 在应用启动时自动安装依赖

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$SCRIPT_DIR/venv"
REQUIREMENTS_FILE="$SCRIPT_DIR/requirements.txt"

echo "正在检查 Python 环境..."

# 检查 Python3 是否安装
if ! command -v python3 &> /dev/null; then
    echo "错误: 未找到 Python3，请先安装 Python3"
    exit 1
fi

# 创建虚拟环境（如果不存在）
if [ ! -d "$VENV_DIR" ]; then
    echo "创建 Python 虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

# 激活虚拟环境
source "$VENV_DIR/bin/activate"

# 检查是否需要安装依赖
if [ -f "$REQUIREMENTS_FILE" ]; then
    echo "安装 Python 依赖..."
    pip install --upgrade pip
    pip install -r "$REQUIREMENTS_FILE"
fi

echo "Python 环境准备完成"
