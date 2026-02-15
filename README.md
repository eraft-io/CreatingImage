# AI 图片生成器 - 安装使用指南

基于 Stable Diffusion XL 的桌面应用，支持通过文字描述生成图片。

**支持平台**: macOS (Intel/M 芯片) | Windows (CPU/CUDA)

## 文件说明

| 文件 | 说明 | 下载链接 |
|------|------|----------|
| `CreatingImage-macos-intel.pkg` | Intel 芯片 Mac 安装包 | [下载](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-macos-intel.pkg) |
| `CreatingImage-macos-arm64.pkg` | M 芯片 Mac 安装包 | [下载](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-macos-arm64.pkg) |
| `CreatingImage-windows.exe` | Windows 可执行程序 | [下载](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-windows.exe) |

**安装包选择：**
- **Intel 芯片 Mac** → [下载 CreatingImage-macos-intel.pkg](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-macos-intel.pkg)
- **M1/M2/M3 芯片 Mac** → [下载 CreatingImage-macos-arm64.pkg](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-macos-arm64.pkg)
- **Windows** → [下载 CreatingImage-windows.exe](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-windows.exe)

## 系统要求

### macOS
- **系统版本**: 11.0 (Big Sur) 或更高版本
- **芯片支持**: Apple Silicon (M1/M2/M3) 或 Intel 芯片
- **内存**: 至少 8GB 内存（推荐 16GB）
- **磁盘空间**: 约 10GB 可用空间（用于模型下载）
- **网络**: 首次启动需要下载 Python 依赖和 AI 模型

### Windows
- **系统版本**: Windows 10/11 64位
- **Python**: Python 3.11（必须预先安装）
- **CUDA**: NVIDIA CUDA 11.8 或更高版本（推荐，用于GPU加速）
- **内存**: 至少 8GB 内存（推荐 16GB）
- **磁盘空间**: 约 10GB 可用空间（用于模型下载）
- **显卡**: NVIDIA 显卡（推荐 4GB 显存以上）
- **网络**: 首次启动需要下载 Python 依赖和 AI 模型

### Windows 预装要求

在运行 Windows 版本前，请确保已安装：

1. **Python 3.11**
   - 从 [python.org](https://www.python.org/downloads/release/python-3119/) 下载安装
   - 安装时勾选 "Add Python to PATH"
   - 验证安装：`python --version`

2. **Microsoft C++ 生成工具**
   - 安装 pip 依赖时需要编译 C++ 扩展
   - 下载地址：[Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   - 安装时选择 **"使用 C++ 的桌面开发"** 工作负载
   - 或下载 Visual Studio Community 并安装 C++ 开发组件

3. **NVIDIA CUDA（推荐用于GPU加速）**
   - 从 [NVIDIA 官网](https://developer.nvidia.com/cuda-downloads) 下载 CUDA 11.8+
   - 或使用 CPU 模式运行（速度较慢）

### Windows 常见问题

#### Q: 安装依赖时提示 "Microsoft Visual C++ 14.0 or greater is required"

**A:** 需要安装 Microsoft C++ 生成工具：

1. 访问 [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
2. 下载并运行 **Build Tools for Visual Studio**
3. 在安装界面勾选 **"使用 C++ 的桌面开发"**
4. 点击安装，等待完成（约 5-10GB）
5. 重启电脑后重新运行应用

或者使用命令行快速安装（约 6GB）：
```powershell
# 使用 Visual Studio Installer
winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools"
```

## Demo

![](resources/demo001.png)