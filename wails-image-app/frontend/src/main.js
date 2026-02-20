import './style.css';
import {GenerateImage, CheckPythonEnvironment, GetInstallLog, GetImageData, SaveImageToDesktop} from '../wailsjs/go/main/App';

// 获取 DOM 元素
const promptInput = document.getElementById('prompt-input');
const generateBtn = document.getElementById('generate-btn');
const loadingDiv = document.getElementById('loading');
const resultDiv = document.getElementById('result');
const errorDiv = document.getElementById('error');
const generatedImage = document.getElementById('generated-image');
const resultMessage = document.getElementById('result-message');
const errorMessage = document.getElementById('error-message');
const installLogDiv = document.getElementById('install-log');
const logContentDiv = document.getElementById('log-content');
const envStatusDiv = document.getElementById('env-status');
const statusText = document.getElementById('status-text');
const statusIndicator = document.querySelector('.status-indicator');

// Python 环境状态
let pythonReady = false;
let logCollapsed = false;
let logLines = [];

// 添加日志行
function addLog(message, type = 'info') {
    const line = document.createElement('div');
    line.className = `log-line ${type}`;
    line.textContent = `[${new Date().toLocaleTimeString()}] ${message}`;
    logContentDiv.appendChild(line);
    logLines.push({ message, type });
    
    // 自动滚动到底部
    logContentDiv.scrollTop = logContentDiv.scrollHeight;
    
    // 限制日志行数
    while (logLines.length > 100) {
        logContentDiv.removeChild(logContentDiv.firstChild);
        logLines.shift();
    }
}

// 清空日志
function clearLog() {
    logContentDiv.innerHTML = '';
    logLines = [];
}

// 切换日志显示/隐藏
window.toggleLog = function() {
    logCollapsed = !logCollapsed;
    const logContent = document.getElementById('log-content');
    const toggleBtn = document.querySelector('.toggle-log');
    
    if (logCollapsed) {
        logContent.style.display = 'none';
        toggleBtn.textContent = '展开';
    } else {
        logContent.style.display = 'block';
        toggleBtn.textContent = '收起';
    }
}

// 切换高级选项显示/隐藏
window.toggleAdvancedOptions = function() {
    const panel = document.getElementById('advanced-panel');
    const icon = document.getElementById('advanced-toggle-icon');
    
    if (panel.classList.contains('hidden')) {
        panel.classList.remove('hidden');
        icon.textContent = '▲';
    } else {
        panel.classList.add('hidden');
        icon.textContent = '▼';
    }
    logContentDiv.classList.toggle('collapsed', logCollapsed);
    const btn = document.querySelector('.toggle-log');
    btn.textContent = logCollapsed ? '展开' : '收起';
};

// 显示安装日志区域
function showInstallLog() {
    installLogDiv.classList.remove('hidden');
    envStatusDiv.classList.remove('hidden');
}

// 隐藏安装日志区域
function hideInstallLog() {
    installLogDiv.classList.add('hidden');
    envStatusDiv.classList.add('hidden');
}

// 更新状态显示
function updateStatus(message, isReady = false) {
    statusText.textContent = message;
    if (isReady) {
        statusIndicator.classList.add('ready');
    } else {
        statusIndicator.classList.remove('ready');
    }
}

// 检查 Python 环境状态
function checkEnvironment() {
    CheckPythonEnvironment()
        .then((status) => {
            pythonReady = status.ready;
            if (status.ready) {
                generateBtn.disabled = false;
                generateBtn.textContent = '生成图片';
                updateStatus('环境就绪', true);
                addLog('Python 环境准备完成', 'info');
                hideError();
                // 延迟隐藏日志区域
                setTimeout(() => {
                    hideInstallLog();
                }, 2000);
            } else {
                generateBtn.disabled = true;
                generateBtn.textContent = '环境准备中...';
                updateStatus('正在安装依赖...');
                showInstallLog();
                addLog(status.message, 'warning');
                // 3秒后再次检查
                setTimeout(checkEnvironment, 3000);
            }
        })
        .catch((err) => {
            console.error('检查环境失败:', err);
            addLog('检查环境失败: ' + err.message, 'error');
            generateBtn.disabled = true;
            generateBtn.textContent = '检查环境中...';
            updateStatus('检查失败');
            setTimeout(checkEnvironment, 3000);
        });
}

// 页面加载时开始检查环境
showInstallLog();
addLog('正在初始化...', 'info');

// 启动日志轮询
startLogPolling();

// 启动环境检查
checkEnvironment();

// 聚焦输入框
promptInput.focus();

// 轮询获取日志
function startLogPolling() {
    const poll = () => {
        GetInstallLog()
            .then((log) => {
                if (log && log.message) {
                    addLog(log.message, log.type || 'info');
                }
                // 继续轮询
                setTimeout(poll, 100);
            })
            .catch((err) => {
                console.error('获取日志失败:', err);
                setTimeout(poll, 500);
            });
    };
    poll();
}

// 生成图片函数
window.generateImage = function () {
    const prompt = promptInput.value.trim();
    
    // 检查输入是否为空
    if (!prompt) {
        showError('请输入图片描述');
        return;
    }
    
    // 显示加载状态
    showLoading();
    
    // 获取生成参数
    const steps = parseInt(document.getElementById('steps-input').value) || 20;
    const guidanceScale = parseFloat(document.getElementById('guidance-scale-input').value) || 7.5;
    const width = parseInt(document.getElementById('width-input').value) || 1024;
    const height = parseInt(document.getElementById('height-input').value) || 1024;
    const seed = parseInt(document.getElementById('seed-input').value) || 0;
    const optimizeSpeed = document.getElementById('optimize-speed-check').checked;
    const optimizeMemory = document.getElementById('optimize-memory-check').checked;
    
    const options = {
        steps: steps,
        guidanceScale: guidanceScale,
        width: width,
        height: height,
        seed: seed,
        optimizeSpeed: optimizeSpeed,
        optimizeMemory: optimizeMemory
    };
    
    // 调用 Go 后端生成图片
    GenerateImage(prompt, options)
        .then((result) => {
            if (result.success) {
                showResult(result.imagePath);
            } else {
                showError(result.message);
            }
        })
        .catch((err) => {
            console.error(err);
            showError('生成图片时发生错误: ' + err.message);
        });
};

// 显示加载状态
function showLoading() {
    loadingDiv.classList.remove('hidden');
    resultDiv.classList.add('hidden');
    errorDiv.classList.add('hidden');
    generateBtn.disabled = true;
    generateBtn.textContent = '生成中...';
    // 显示日志区域以便查看生成进度
    showInstallLog();
    // 清空之前的日志
    clearLog();
    addLog('开始生成图片...', 'info');
}

// 当前图片的 base64 数据（用于下载）
let currentImageBase64 = null;
let currentImageName = null;
let currentImagePath = null;

// 显示结果
function showResult(imagePath) {
    loadingDiv.classList.add('hidden');
    resultDiv.classList.remove('hidden');
    errorDiv.classList.add('hidden');
    generateBtn.disabled = false;
    generateBtn.textContent = '生成图片';
    resultMessage.textContent = '图片生成成功！';
    
    // 保存图片路径
    currentImagePath = imagePath;
    
    // 生成文件名
    currentImageName = 'CreatingImage_' + Date.now() + '.png';
    
    // 使用 base64 加载图片
    GetImageData(imagePath)
        .then((base64Data) => {
            generatedImage.src = base64Data;
            currentImageBase64 = base64Data;
        })
        .catch((err) => {
            console.error('加载图片失败:', err);
            resultMessage.textContent = '图片生成成功，但加载失败: ' + err.message;
        });
}

// 保存到桌面
window.saveToDesktop = function() {
    console.log('另存到桌面按钮被点击');
    
    if (!currentImagePath) {
        alert('没有可保存的图片，请先生成图片');
        return;
    }
    
    // 更新按钮状态
    const saveBtn = document.getElementById('save-btn');
    const originalText = saveBtn.textContent;
    saveBtn.textContent = '保存中...';
    saveBtn.disabled = true;
    
    // 调用 Go 后端保存图片到桌面
    SaveImageToDesktop(currentImagePath)
        .then((destPath) => {
            console.log('图片已保存到:', destPath);
            // 在页面上显示成功提示
            resultMessage.textContent = '✓ 图片已保存到桌面: ' + destPath;
            resultMessage.style.color = '#4ade80';
            // 恢复按钮
            saveBtn.textContent = originalText;
            saveBtn.disabled = false;
        })
        .catch((err) => {
            console.error('保存失败:', err);
            // 在页面上显示错误提示
            resultMessage.textContent = '✗ 保存失败: ' + err;
            resultMessage.style.color = '#f87171';
            // 恢复按钮
            saveBtn.textContent = originalText;
            saveBtn.disabled = false;
        });
};

// 显示错误
function showError(message) {
    loadingDiv.classList.add('hidden');
    resultDiv.classList.add('hidden');
    errorDiv.classList.remove('hidden');
    if (pythonReady) {
        generateBtn.disabled = false;
        generateBtn.textContent = '生成图片';
    }
    
    errorMessage.textContent = message;
}

// 隐藏错误
function hideError() {
    errorDiv.classList.add('hidden');
}

// 支持 Enter 键触发生成（Ctrl+Enter 或 Cmd+Enter）
promptInput.addEventListener('keydown', (e) => {
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
        generateImage();
    }
});
