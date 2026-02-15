package main

import (
	"bufio"
	"context"
	"encoding/base64"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"time"
)

// LogMessage 日志消息结构
type LogMessage struct {
	Message string `json:"message"`
	Type    string `json:"type"` // info, error, warning
}

// App struct
type App struct {
	ctx         context.Context
	pythonReady bool
	pythonMutex sync.Mutex
	venvPython  string
	logChannel  chan LogMessage
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{
		pythonReady: false,
		venvPython:  "",
		logChannel:  make(chan LogMessage, 100),
	}
}

// GetInstallLog 获取安装日志（前端轮询调用）
func (a *App) GetInstallLog() LogMessage {
	select {
	case log := <-a.logChannel:
		return log
	case <-time.After(100 * time.Millisecond):
		return LogMessage{Message: "", Type: ""}
	}
}

// sendLog 发送日志到前端
func (a *App) sendLog(message string, logType string) {
	select {
	case a.logChannel <- LogMessage{Message: message, Type: logType}:
	default:
		// 通道满了，丢弃旧日志
		select {
		case <-a.logChannel:
		default:
		}
		a.logChannel <- LogMessage{Message: message, Type: logType}
	}
	// 同时打印到控制台
	fmt.Printf("[%s] %s\n", strings.ToUpper(logType), message)
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	// 在后台准备 Python 环境
	go a.setupPythonEnvironment()
}

// CheckPythonStatus 检查 Python 环境状态
type CheckPythonStatus struct {
	Ready   bool   `json:"ready"`
	Message string `json:"message"`
}

// CheckPythonEnvironment 检查 Python 环境是否就绪
func (a *App) CheckPythonEnvironment() CheckPythonStatus {
	a.pythonMutex.Lock()
	defer a.pythonMutex.Unlock()

	if a.pythonReady {
		return CheckPythonStatus{
			Ready:   true,
			Message: "Python 环境已就绪",
		}
	}

	// 检查系统是否安装了 Python3
	_, err := exec.LookPath("python3")
	if err != nil {
		return CheckPythonStatus{
			Ready:   false,
			Message: "未找到 Python3，请先安装 Python3",
		}
	}

	return CheckPythonStatus{
		Ready:   false,
		Message: "正在准备 Python 环境...",
	}
}

// setupPythonEnvironment 设置 Python 虚拟环境并安装依赖
func (a *App) setupPythonEnvironment() {
	a.pythonMutex.Lock()
	defer a.pythonMutex.Unlock()

	if a.pythonReady {
		return
	}

	// 获取应用资源目录
	execPath, err := os.Executable()
	if err != nil {
		a.sendLog(fmt.Sprintf("获取可执行文件路径失败: %v", err), "error")
		return
	}

	var resourcesDir string
	var userPythonDir string

	if runtime.GOOS == "darwin" {
		// macOS: 资源在 app bundle 中
		resourcesDir = filepath.Join(filepath.Dir(execPath), "..", "Resources")
		homeDir, _ := os.UserHomeDir()
		userPythonDir = filepath.Join(homeDir, ".cache", "CreatingImage", "python")
	} else if runtime.GOOS == "windows" {
		// Windows: 资源在可执行文件同级目录
		resourcesDir = filepath.Join(filepath.Dir(execPath), "resources")
		// Windows 使用 AppData/Local 目录
		appData := os.Getenv("LOCALAPPDATA")
		if appData == "" {
			appData = os.Getenv("APPDATA")
		}
		if appData == "" {
			homeDir, _ := os.UserHomeDir()
			appData = filepath.Join(homeDir, "AppData", "Local")
		}
		userPythonDir = filepath.Join(appData, "CreatingImage", "python")
	} else {
		// Linux: 资源在可执行文件同级目录
		resourcesDir = filepath.Join(filepath.Dir(execPath), "resources")
		homeDir, _ := os.UserHomeDir()
		userPythonDir = filepath.Join(homeDir, ".cache", "CreatingImage", "python")
	}

	// 应用 bundle 内的 Python 目录（只读，用于复制预装依赖）
	bundlePythonDir := filepath.Join(resourcesDir, "python")
	bundleVenvDir := filepath.Join(bundlePythonDir, "venv")

	// 用户可写的 Python 目录（运行时实际使用）
	venvDir := filepath.Join(userPythonDir, "venv")

	// Windows 使用 Scripts/python.exe，其他平台使用 bin/python3
	var venvPython string
	if runtime.GOOS == "windows" {
		venvPython = filepath.Join(venvDir, "Scripts", "python.exe")
	} else {
		venvPython = filepath.Join(venvDir, "bin", "python3")
	}

	a.sendLog(fmt.Sprintf("应用资源目录: %s", resourcesDir), "info")
	a.sendLog(fmt.Sprintf("用户 Python 目录: %s", userPythonDir), "info")
	a.sendLog(fmt.Sprintf("虚拟环境目录: %s", venvDir), "info")

	// 检查系统 Python3
	var python3Path string

	if runtime.GOOS == "windows" {
		// Windows 上尝试 python 和 python3
		python3Path, err = exec.LookPath("python")
		if err != nil {
			python3Path, err = exec.LookPath("python3")
		}
	} else {
		python3Path, err = exec.LookPath("python3")
	}

	if err != nil {
		a.sendLog("错误: 未找到系统 Python3，请先安装 Python3", "error")
		return
	}
	a.sendLog(fmt.Sprintf("找到系统 Python3: %s", python3Path), "info")

	if _, err := os.Stat(venvPython); err == nil {
		a.sendLog("检查现有虚拟环境...", "info")
		if a.checkDependencies(venvPython) {
			a.venvPython = venvPython
			a.pythonReady = true
			a.sendLog("现有 Python 环境可用", "info")
			return
		}
		a.sendLog("现有环境依赖不完整，需要修复", "warning")
	}

	// 检查应用 bundle 中是否有预装依赖
	// Windows 使用 Scripts/python.exe，其他平台使用 bin/python3
	var bundleVenvPython string
	if runtime.GOOS == "windows" {
		bundleVenvPython = filepath.Join(bundleVenvDir, "Scripts", "python.exe")
	} else {
		bundleVenvPython = filepath.Join(bundleVenvDir, "bin", "python3")
	}

	bundleSitePackages := ""
	if _, err := os.Stat(bundleVenvPython); err == nil {
		a.sendLog("检测到应用内预装依赖", "info")
		// 查找 bundle 中的 site-packages
		var pattern string
		if runtime.GOOS == "windows" {
			pattern = filepath.Join(bundleVenvDir, "Lib", "site-packages")
		} else {
			pattern = filepath.Join(bundleVenvDir, "lib", "python*", "site-packages")
		}
		matches, _ := filepath.Glob(pattern)
		if len(matches) > 0 {
			bundleSitePackages = matches[0]
			a.sendLog(fmt.Sprintf("预装依赖位置: %s", bundleSitePackages), "info")
		}
	}

	// 需要创建虚拟环境
	a.sendLog("正在设置 Python 环境...", "info")

	// 确保目录存在
	if err := os.MkdirAll(userPythonDir, 0755); err != nil {
		a.sendLog(fmt.Sprintf("创建 Python 目录失败: %v", err), "error")
		return
	}
	a.sendLog(fmt.Sprintf("已创建目录: %s", userPythonDir), "info")

	// 创建虚拟环境
	a.sendLog("创建 Python 虚拟环境...", "info")
	cmd := exec.Command(python3Path, "-m", "venv", venvDir)
	output, err := cmd.CombinedOutput()
	if err != nil {
		a.sendLog(fmt.Sprintf("创建虚拟环境失败: %v\n%s", err, output), "error")
		return
	}
	a.sendLog("虚拟环境创建成功", "info")

	// 如果有预装依赖，复制到新的虚拟环境
	if bundleSitePackages != "" {
		a.sendLog("复制预装依赖包...", "info")
		// 找到新虚拟环境的 site-packages
		var newSitePackagesPattern string
		if runtime.GOOS == "windows" {
			newSitePackagesPattern = filepath.Join(venvDir, "Lib", "site-packages")
		} else {
			newSitePackagesPattern = filepath.Join(venvDir, "lib", "python*", "site-packages")
		}
		newMatches, _ := filepath.Glob(newSitePackagesPattern)
		if len(newMatches) > 0 {
			newSitePackages := newMatches[0]
			// 复制 bundle 中的 site-packages 内容
			entries, err := os.ReadDir(bundleSitePackages)
			if err == nil {
				copied := 0
				for _, entry := range entries {
					src := filepath.Join(bundleSitePackages, entry.Name())
					dst := filepath.Join(newSitePackages, entry.Name())
					// 根据平台选择复制命令
					var cpCmd *exec.Cmd
					if runtime.GOOS == "windows" {
						cpCmd = exec.Command("xcopy", src, dst, "/E", "/I", "/Q")
					} else {
						cpCmd = exec.Command("cp", "-R", src, dst)
					}
					if err := cpCmd.Run(); err == nil {
						copied++
					}
				}
				a.sendLog(fmt.Sprintf("已复制 %d 个依赖包", copied), "info")

				// 检查依赖是否完整
				if a.checkDependencies(venvPython) {
					a.venvPython = venvPython
					a.pythonReady = true
					a.sendLog("预装依赖复制成功，环境已就绪", "info")
					return
				}
				a.sendLog("预装依赖不完整，将安装缺失的依赖", "warning")
			}
		}
	}

	// 安装依赖
	a.sendLog("开始安装 Python 依赖（这可能需要几分钟）...", "info")
	// Windows 使用 Scripts/pip.exe，其他平台使用 bin/pip
	var pipCmd string
	if runtime.GOOS == "windows" {
		pipCmd = filepath.Join(venvDir, "Scripts", "pip.exe")
	} else {
		pipCmd = filepath.Join(venvDir, "bin", "pip")
	}

	// 先升级 pip
	a.sendLog("升级 pip...", "info")
	cmd = exec.Command(pipCmd, "install", "--upgrade", "pip")
	output, _ = cmd.CombinedOutput()
	a.sendLog("pip 升级完成", "info")
	if len(output) > 0 {
		a.sendLog(string(output), "info")
	}

	// 检测 Windows 是否有 NVIDIA GPU
	var useCUDA bool
	if runtime.GOOS == "windows" {
		a.sendLog("检测 GPU 设备...", "info")
		// 使用 PowerShell 检测 NVIDIA GPU（兼容 Windows 10/11）
		cmd := exec.Command("powershell", "-Command", "Get-WmiObject Win32_VideoController | Select-Object -ExpandProperty Name")
		output, err := cmd.Output()
		if err == nil && strings.Contains(strings.ToLower(string(output)), "nvidia") {
			a.sendLog("检测到 NVIDIA GPU，将安装 CUDA 版本 PyTorch", "info")
			useCUDA = true
		} else {
			if err != nil {
				a.sendLog(fmt.Sprintf("GPU 检测命令执行失败: %v", err), "warning")
			}
			a.sendLog("未检测到 NVIDIA GPU，将安装 CPU 版本 PyTorch", "info")
			useCUDA = false
		}
	}

	// 安装依赖
	if runtime.GOOS == "windows" && useCUDA {
		// Windows + NVIDIA GPU: 安装 CUDA 版本 PyTorch
		a.sendLog("[1/8] 安装 PyTorch (CUDA 版本)...", "info")
		a.sendLog("正在使用国内镜像源加速下载...", "info")
		// 使用清华镜像源加速下载
		cmd := exec.Command(pipCmd, "install", "torch==2.2.2", "torchvision==0.17.2",
			"--index-url", "https://pypi.tuna.tsinghua.edu.cn/simple",
			"--extra-index-url", "https://download.pytorch.org/whl/cu121",
			"--trusted-host", "pypi.tuna.tsinghua.edu.cn",
			"--trusted-host", "download.pytorch.org")
		output, err := cmd.CombinedOutput()
		if err != nil {
			a.sendLog(fmt.Sprintf("安装 CUDA 版本 PyTorch 失败: %v\n%s", err, output), "error")
			a.sendLog("尝试安装 CPU 版本...", "warning")
			useCUDA = false
		} else {
			a.sendLog("PyTorch (CUDA 版本) 安装成功", "info")
		}
	}

	if runtime.GOOS != "windows" || !useCUDA {
		// macOS/Linux 或 Windows 无 GPU: 安装普通版本
		a.sendLog("[1/8] 安装 PyTorch...", "info")
		// 使用清华镜像源
		cmd := exec.Command(pipCmd, "install", "torch>=2.0.0",
			"--index-url", "https://pypi.tuna.tsinghua.edu.cn/simple",
			"--trusted-host", "pypi.tuna.tsinghua.edu.cn")
		output, _ := cmd.CombinedOutput()
		a.sendLog("PyTorch 安装完成", "info")
		if len(output) > 0 {
			a.sendLog(string(output), "info")
		}
	}

	// 安装其他依赖
	deps := []string{
		"transformers>=4.30.0",
		"diffusers>=0.21.0",
		"accelerate>=0.20.0",
		"safetensors>=0.3.0",
		"pillow>=9.0.0",
		"modelscope>=1.9.0",
	}

	for i, dep := range deps {
		a.sendLog(fmt.Sprintf("[%d/%d] 开始安装 %s...", i+2, len(deps)+1, dep), "info")

		// 使用实时输出，使用清华镜像源
		cmd := exec.Command(pipCmd, "install", dep,
			"--index-url", "https://pypi.tuna.tsinghua.edu.cn/simple",
			"--trusted-host", "pypi.tuna.tsinghua.edu.cn")
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			a.sendLog(fmt.Sprintf("创建输出管道失败: %v", err), "error")
			continue
		}
		stderr, err := cmd.StderrPipe()
		if err != nil {
			a.sendLog(fmt.Sprintf("创建错误管道失败: %v", err), "error")
			continue
		}

		if err := cmd.Start(); err != nil {
			a.sendLog(fmt.Sprintf("启动安装失败: %v", err), "error")
			continue
		}

		// 实时读取输出
		go func() {
			scanner := bufio.NewScanner(stdout)
			for scanner.Scan() {
				a.sendLog(scanner.Text(), "info")
			}
		}()

		go func() {
			scanner := bufio.NewScanner(stderr)
			for scanner.Scan() {
				a.sendLog(scanner.Text(), "warning")
			}
		}()

		if err := cmd.Wait(); err != nil {
			a.sendLog(fmt.Sprintf("安装 %s 失败: %v", dep, err), "error")
		} else {
			a.sendLog(fmt.Sprintf("%s 安装成功", dep), "info")
		}
	}

	// 验证安装
	a.sendLog("验证依赖安装...", "info")
	if a.checkDependencies(venvPython) {
		a.venvPython = venvPython
		a.pythonReady = true
		a.sendLog("Python 环境设置完成", "info")
	} else {
		a.sendLog("依赖验证失败", "error")
	}
}

// checkDependencies 检查依赖是否已安装
func (a *App) checkDependencies(pythonPath string) bool {
	// 逐个检查依赖，以便定位问题
	deps := []string{"torch", "transformers", "diffusers", "modelscope"}
	allOK := true

	for _, dep := range deps {
		// 使用 try-except 忽略非关键错误（如 xpu 属性缺失）
		checkScript := fmt.Sprintf(`
try:
    import %s
    print('%s OK')
except Exception as e:
    err_str = str(e)
    # 忽略 xpu 等非关键属性错误
    if "has no attribute 'xpu'" in err_str or "has no attribute 'xpu'" in err_str:
        print('%s OK (with warnings)')
    else:
        print('%s ERROR:', err_str)
`, dep, dep, dep, dep)

		cmd := exec.Command(pythonPath, "-c", checkScript)
		output, err := cmd.CombinedOutput()
		outputStr := string(output)

		if err != nil {
			// 检查是否是已知可忽略的错误
			if strings.Contains(outputStr, "OK (with warnings)") {
				a.sendLog(fmt.Sprintf("依赖 %s 已安装 (有警告)", dep), "info")
			} else {
				a.sendLog(fmt.Sprintf("依赖 %s 检查失败: %v", dep, err), "error")
				a.sendLog(fmt.Sprintf("输出: %s", outputStr), "error")
				allOK = false
			}
		} else if strings.Contains(outputStr, "OK") {
			a.sendLog(fmt.Sprintf("依赖 %s 已安装", dep), "info")
		} else {
			a.sendLog(fmt.Sprintf("依赖 %s 检查异常: %s", dep, outputStr), "error")
			allOK = false
		}
	}

	return allOK
}

// GenerateImageResult 图片生成结果
type GenerateImageResult struct {
	Success   bool   `json:"success"`
	ImagePath string `json:"imagePath"`
	Message   string `json:"message"`
}

// GenerateImage 调用 Python 脚本生成图片
func (a *App) GenerateImage(prompt string) GenerateImageResult {
	// 检查 Python 环境是否就绪
	a.pythonMutex.Lock()
	if !a.pythonReady {
		a.pythonMutex.Unlock()
		return GenerateImageResult{
			Success: false,
			Message: "Python 环境尚未就绪，请稍后再试",
		}
	}
	pythonPath := a.venvPython
	a.pythonMutex.Unlock()

	// 创建输出目录
	outputDir := filepath.Join(os.TempDir(), "CreatingImage")
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("创建输出目录失败: %v", err),
		}
	}

	// 生成唯一的文件名
	timestamp := time.Now().Unix()
	outputFile := filepath.Join(outputDir, fmt.Sprintf("generated_%d.png", timestamp))

	// 获取可执行文件路径，然后计算脚本路径
	execPath, err := os.Executable()
	if err != nil {
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("获取可执行文件路径失败: %v", err),
		}
	}
	execDir := filepath.Dir(execPath)

	// 尝试多个可能的路径（按优先级排序）
	var possiblePaths []string

	if runtime.GOOS == "windows" {
		// Windows 路径
		possiblePaths = []string{
			// 生产模式：脚本在 resources 目录中（与 exe 同级）
			filepath.Join(execDir, "resources", "gen_image.py"),
			// 备选：脚本在 exe 同级目录
			filepath.Join(execDir, "gen_image.py"),
			// 开发模式
			filepath.Join(execDir, "..", "..", "..", "gen_image.py"),
			filepath.Join(execDir, "..", "..", "gen_image.py"),
		}
	} else {
		// macOS/Linux 路径
		possiblePaths = []string{
			// 生产模式：脚本在 app bundle 的 Resources 目录中
			filepath.Join(execDir, "..", "Resources", "gen_image.py"),
			// 开发模式：脚本在项目根目录
			filepath.Join(execDir, "..", "..", "..", "gen_image.py"),
			// 备选：脚本在 app 同级目录
			filepath.Join(execDir, "..", "..", "gen_image.py"),
		}
	}

	scriptPath := ""
	for _, path := range possiblePaths {
		// 转换为绝对路径并清理
		absPath, _ := filepath.Abs(path)
		if _, err := os.Stat(absPath); err == nil {
			scriptPath = absPath
			break
		}
	}

	if scriptPath == "" {
		return GenerateImageResult{
			Success: false,
			Message: "找不到 gen_image.py 脚本文件，请确保脚本已正确打包到应用中",
		}
	}

	a.sendLog(fmt.Sprintf("[生成] 使用脚本: %s", scriptPath), "info")

	// 使用虚拟环境的 Python 执行脚本
	// 设置模型缓存目录
	var cacheDir string
	if runtime.GOOS == "windows" {
		// Windows 使用 AppData/Local
		appData := os.Getenv("LOCALAPPDATA")
		if appData == "" {
			appData = os.Getenv("APPDATA")
		}
		if appData == "" {
			homeDir, _ := os.UserHomeDir()
			appData = filepath.Join(homeDir, "AppData", "Local")
		}
		cacheDir = filepath.Join(appData, "CreatingImage", "models")
	} else {
		// macOS/Linux 使用 ~/.cache
		homeDir, _ := os.UserHomeDir()
		cacheDir = filepath.Join(homeDir, ".cache", "CreatingImage", "models")
	}
	cmd := exec.Command(pythonPath, scriptPath, prompt, "--output", outputFile, "--steps", "20", "--cache-dir", cacheDir)

	// 捕获输出
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("创建输出管道失败: %v", err),
		}
	}

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("创建错误管道失败: %v", err),
		}
	}

	// 启动命令
	if err := cmd.Start(); err != nil {
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("启动 Python 脚本失败: %v", err),
		}
	}

	// 读取输出并发送到前端
	var outputLines []string
	go func() {
		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			outputLines = append(outputLines, line)
			a.sendLog("[生成] "+line, "info")
		}
	}()

	var errorLines []string
	go func() {
		scanner := bufio.NewScanner(stderr)
		for scanner.Scan() {
			line := scanner.Text()
			errorLines = append(errorLines, line)
			a.sendLog("[生成错误] "+line, "error")
		}
	}()

	// 等待命令完成
	if err := cmd.Wait(); err != nil {
		errMsg := strings.Join(errorLines, "\n")
		if errMsg == "" {
			errMsg = err.Error()
		}
		return GenerateImageResult{
			Success: false,
			Message: fmt.Sprintf("生成图片失败: %v\n%s", err, errMsg),
		}
	}

	// 检查输出中是否包含 SUCCESS
	outputStr := strings.Join(outputLines, "\n")
	if strings.Contains(outputStr, "SUCCESS") {
		return GenerateImageResult{
			Success:   true,
			ImagePath: outputFile,
			Message:   "图片生成成功",
		}
	}

	// 检查文件是否生成
	if _, err := os.Stat(outputFile); err == nil {
		return GenerateImageResult{
			Success:   true,
			ImagePath: outputFile,
			Message:   "图片生成成功",
		}
	}

	return GenerateImageResult{
		Success: false,
		Message: "图片生成失败，未找到输出文件",
	}
}

// GetImageData 读取图片文件并返回 base64 编码的数据
func (a *App) GetImageData(imagePath string) (string, error) {
	data, err := os.ReadFile(imagePath)
	if err != nil {
		return "", fmt.Errorf("读取图片失败: %v", err)
	}
	// 返回 base64 编码的图片数据
	return "data:image/png;base64," + base64.StdEncoding.EncodeToString(data), nil
}

// SaveImageToDesktop 将图片保存到桌面
func (a *App) SaveImageToDesktop(imagePath string) (string, error) {
	// 获取桌面路径
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("获取用户目录失败: %v", err)
	}

	desktopDir := filepath.Join(homeDir, "Desktop")

	// 检查桌面目录是否存在
	if _, err := os.Stat(desktopDir); os.IsNotExist(err) {
		return "", fmt.Errorf("桌面目录不存在")
	}

	// 生成文件名
	fileName := fmt.Sprintf("CreatingImage_%d.png", time.Now().Unix())
	destPath := filepath.Join(desktopDir, fileName)

	// 复制文件
	srcFile, err := os.Open(imagePath)
	if err != nil {
		return "", fmt.Errorf("打开源文件失败: %v", err)
	}
	defer srcFile.Close()

	destFile, err := os.Create(destPath)
	if err != nil {
		return "", fmt.Errorf("创建目标文件失败: %v", err)
	}
	defer destFile.Close()

	_, err = destFile.ReadFrom(srcFile)
	if err != nil {
		return "", fmt.Errorf("复制文件失败: %v", err)
	}

	return destPath, nil
}
