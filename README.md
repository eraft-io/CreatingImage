# AI 图片生成器 - 安装使用指南

基于 Stable Diffusion XL 的 macOS 桌面应用，支持通过文字描述生成图片。

## 文件说明

| 文件 | 说明 |
|------|------|
| `demo001.png` | 应用演示截图 |
| `CreatingImage-macos-intel.pkg` | Intel 芯片 Mac 安装包 |
| `CreatingImage-macos-arm64.pkg` | M 芯片 (M1/M2/M3) Mac 安装包 |

**请根据您的 Mac 芯片类型选择对应的安装包：**
- **Intel 芯片 Mac** → 使用 `CreatingImage-macos-intel.pkg`
- **M1/M2/M3 芯片 Mac** → 使用 `CreatingImage-macos-arm64.pkg`

## 系统要求

- **macOS 版本**: 11.0 (Big Sur) 或更高版本
- **芯片支持**: Apple Silicon (M1/M2/M3) 和 Intel 芯片
- **内存**: 至少 8GB 内存（推荐 16GB）
- **磁盘空间**: 约 10GB 可用空间（用于模型下载）
- **网络**: 首次启动需要下载 Python 依赖和 AI 模型

## 安装步骤

### 1. 下载应用

下载 `CreatingImage-macos.zip` 文件到你的 Mac。

### 2. 解压应用

**方法 A - 双击解压（推荐）:**
```
双击 CreatingImage-macos.zip 文件
系统会自动解压到同一目录
```

**方法 B - 终端命令:**
```bash
cd ~/Downloads
unzip CreatingImage-macos.zip
```

### 3. 安装到 Applications 文件夹

将解压后的 `CreatingImage.app` 拖到 **Applications（应用程序）** 文件夹：

```bash
mv ~/Downloads/CreatingImage.app /Applications/
```

或者通过 Finder 手动拖动。

### 4. 解除系统安全限制（关键步骤）

由于应用未经过 Apple 官方签名，首次运行前需要解除隔离属性：

**在终端执行以下命令：**

```bash
sudo xattr -rd com.apple.quarantine /Applications/CreatingImage.app
```

输入你的 Mac 密码（输入时不会显示），按回车确认。

**为什么需要这一步？**
- macOS 会阻止运行从互联网下载的未签名应用
- 这个命令告诉系统允许运行此应用
- 只需执行一次，之后正常使用

### 5. 首次启动

**方法 A - 从启动台启动:**
- 打开启动台（Launchpad）
- 找到 "CreatingImage" 图标
- 点击打开

**方法 B - 从 Applications 文件夹启动:**
- 打开 Finder
- 进入 Applications 文件夹
- 双击 "CreatingImage"

**方法 C - 终端启动（调试用）:**
```bash
/Applications/CreatingImage.app/Contents/MacOS/CreatingImage
```

### 6. 首次启动配置（约 10-30 分钟）

**好消息：此版本已预装 Python 依赖，无需等待安装！**

首次启动时，应用只需：

1. **下载 AI 模型** (10-30 分钟，取决于网速)
   - 自动从 modelscope 下载 Stable Diffusion XL 模型
   - 模型大小约 5-10GB
   - 下载完成后会保存在本地，下次无需重复下载
   - 可以在日志区域查看下载进度

**注意：** 配置过程中请保持网络连接，耐心等待。模型只需下载一次。

## 使用方法

### 生成图片

1. **输入提示词**
   - 在主界面的输入框中输入图片描述
   - 支持中文和英文
   - 例如："一只坐在云朵上的猫，8k，超写实风格"

2. **点击生成**
   - 点击"生成图片"按钮
   - 等待生成完成（首次生成可能需要加载模型，时间较长）

3. **查看结果**
   - 生成的图片会显示在下方
   - 图片会自动保存到临时目录

### 快捷键

- **Ctrl+Enter** 或 **Cmd+Enter**: 快速触发生成

## 常见问题

### Q: 提示"无法打开，因为无法验证开发者"

**A:** 按照安装步骤第 4 步，执行解除隔离属性命令：
```bash
sudo xattr -rd com.apple.quarantine /Applications/CreatingImage.app
```

### Q: 应用闪退或打不开

**A:** 尝试以下步骤：

1. 确认已执行解除隔离属性命令
2. 检查 macOS 版本是否 >= 11.0
3. 尝试从终端启动查看错误信息：
   ```bash
   /Applications/CreatingImage.app/Contents/MacOS/CreatingImage
   ```

### Q: 首次启动卡住很久

**A:** 这是正常现象。应用正在下载 AI 模型（约 5-10GB）：
- 下载时间取决于网速（约 10-30 分钟）
- 可以在日志区域查看下载进度
- 模型只需下载一次，下次启动直接使用

请在日志区域查看进度，不要关闭应用。

### Q: 生成图片失败

**A:** 检查日志区域的错误信息，常见原因：

1. **模型下载不完整**
   - 删除模型缓存重新下载：
   ```bash
   rm -rf ~/.cache/CreatingImage/models
   ```
   - 重启应用重新下载

2. **内存不足**
   - 关闭其他占用内存的应用
   - 重启电脑释放内存

3. **Python 环境问题**
   - 删除虚拟环境重新配置：
   ```bash
   rm -rf /tmp/CreatingImage
   ```
   - 重启应用

### Q: 支持哪些 Mac 设备？

**A:** 支持所有运行 macOS 11.0+ 的 Mac：
- M3 系列: MacBook Pro、iMac
- M2 系列: MacBook Air、MacBook Pro、Mac mini、Mac Studio
- M1 系列: MacBook Air、MacBook Pro、Mac mini、iMac
- Intel 芯片的 Mac（需要 macOS 11.0+）

### Q: 如何卸载？

**A:** 直接删除应用即可：
```bash
rm -rf /Applications/CreatingImage.app
rm -rf ~/.cache/CreatingImage
rm -rf /tmp/CreatingImage
```

## 技术说明

- **框架**: Wails v2 (Go + WebView)
- **AI 模型**: Stable Diffusion XL 1.0
- **模型来源**: ModelScope (阿里云)
- **Python 版本**: 3.13
- **支持架构**: x86_64 (Intel) 和 arm64 (Apple Silicon)

## 文件位置

- **应用**: `/Applications/CreatingImage.app`
- **模型缓存**: `~/.cache/CreatingImage/models/`
- **Python 环境**: `/tmp/CreatingImage/python/venv/`
- **生成的图片**: `/tmp/CreatingImage/generated_*.png`

## 更新日志

### v1.0.0
- 初始版本
- 支持文字生成图片
- 自动下载和配置 Python 环境
- 自动下载 AI 模型
- 实时显示生成进度

## 许可证

本项目仅供学习和个人使用。

Stable Diffusion XL 模型遵循其原始许可证。

## 反馈与支持

如有问题，请检查应用日志区域的错误信息。

---

**注意**: 首次启动需要较长时间进行环境配置，请耐心等待。

### debug

```
open /Users/jieliu/Desktop/CreatingImage/wails-image-app/build/bin/CreatingImage.app
```
