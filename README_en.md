# AI Image Generator - Installation Guide

A desktop application based on Stable Diffusion XL that generates images from text descriptions.

**Supported Platforms**: macOS (Apple Silicon) | Windows (GPU/CUDA)

[中文文档](README.md)

## File Descriptions

| File | Description | Download Link |
|------|-------------|---------------|
| `CreatingImage-macos-arm64.pkg` | macOS Apple Silicon Installer | [Download](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-macos-arm64.pkg) |
| `CreatingImage-windows.exe` | Windows Executable | [Download](https://github.com/eraft-io/CreatingImage/releases/download/v1.0.0/CreatingImage-windows.zip) |

## System Requirements

### macOS
- **OS Version**: 11.0 (Big Sur) or later
- **Chip Support**: Apple Silicon (M1/M2/M3) or Intel
- **Memory**: At least 8GB RAM (16GB recommended)
- **Disk Space**: ~10GB free space (for model downloads)
- **Network**: Required for downloading Python dependencies and AI models on first launch

### Windows
- **OS Version**: Windows 10/11 64-bit
- **Python**: Python 3.11 (must be pre-installed)
- **Memory**: At least 8GB RAM (16GB recommended)
- **Disk Space**: ~10GB free space (for model downloads)
- **Graphics**: NVIDIA GPU (4GB+ VRAM recommended)
- **Network**: Required for downloading Python dependencies and AI models on first launch

### Windows Prerequisites

Before running the Windows version, ensure you have installed:

1. **Python 3.11**
   - Download from [python.org](https://www.python.org/downloads/windows/)
   - Check "Add Python to PATH" during installation
   - Verify installation: `python --version`

2. **Microsoft C++ Build Tools**
   - Required for compiling C++ extensions during pip installation
   - Download: [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
   - Select **"Desktop development with C++"** workload during installation
   - Or install Visual Studio Community with C++ development components

### Windows FAQ

#### Q: "Microsoft Visual C++ 14.0 or greater is required" error during dependency installation

**A:** You need to install Microsoft C++ Build Tools:

1. Visit [Microsoft C++ Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/)
2. Download and run **Build Tools for Visual Studio**
3. Check **"Desktop development with C++"** in the installation interface
4. Click Install and wait for completion (~5-10GB)
5. Restart your computer and run the application again

Or install quickly via command line (~6GB):
```powershell
# Using Visual Studio Installer
winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools"
```

## Application Demo

### Example Image, Prompt - "tian an men square in cartoon"

<img src="resources/demo002.png" width="600" alt="macOS Version Demo">

### macOS Version

<img src="resources/demo001.png" width="600" alt="macOS Version Demo">

### Windows 10 Version

<img src="resources/windemo.png" width="600" alt="Windows 10 Version Demo">

## Performance Comparison: Mac M Chip vs Windows NVIDIA

### Why Mac M Chip is Faster than Windows NVIDIA GPU

| Feature | Mac M Chip | Windows NVIDIA |
|---------|-----------|----------------|
| **Memory Architecture** | CPU/GPU unified memory pool | CPU memory + GPU VRAM separated |
| **Data Transfer** | Near zero-copy, no PCIe bottleneck | Data copy required via PCIe |
| **Model Loading** | Direct access to large memory, no batching | Limited by VRAM capacity |
| **Memory Bandwidth** | High-bandwidth unified memory (400-800 GB/s) | High VRAM bandwidth but capacity limited |

### Key Differences Explained

**1. Unified Memory Architecture**
- Mac M chips share the same physical memory pool between CPU and GPU
- Large models can be loaded directly into memory without batching
- Data transfer has near-zero latency

**2. Impact of VRAM Limitations**
- NVIDIA GPUs with limited VRAM may trigger when processing large models:
  - Gradient checkpointing - increases computational overhead
  - CPU offloading - frequent PCIe data transfers
  - Batched inference - increases overall latency

**3. Software Optimization**
- Mac: Metal Performance Shaders (MPS) backend is highly optimized for Apple Silicon
- Windows: CUDA is powerful, but PyTorch's Windows optimization path is longer

### Real-World Scenario Example

When generating 1024x1024 images:
```
Mac M2/M3: Uses 20-30GB unified memory, no bottlenecks, smooth inference
NVIDIA 16GB: May trigger memory optimization strategies, adding 20-50% latency
```

### Windows NVIDIA Optimization Tips

To improve Windows version performance:

1. **Enable half-precision inference**
   ```python
   torch_dtype=torch.float16
   ```

2. **Use torch.compile()** (PyTorch 2.0+)
   ```python
   model = torch.compile(model)
   ```

3. **Enable CUDA graph capture** - reduces CPU overhead

4. **Ensure CUDA version compatibility** - This app is configured with CUDA 12.1
