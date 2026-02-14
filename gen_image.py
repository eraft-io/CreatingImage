from diffusers import StableDiffusionXLPipeline
import torch
import os
import sys
import argparse
import time

# ===================== 命令行参数解析 =====================
parser = argparse.ArgumentParser(description='Generate image using Stable Diffusion XL')
parser.add_argument('prompt', type=str, help='Text prompt for image generation')
parser.add_argument('--output', type=str, default='sdxl_output.png', help='Output image path')
parser.add_argument('--model-path', type=str, default=None, help='Path to local model')
parser.add_argument('--steps', type=int, default=20, help='Number of inference steps')
parser.add_argument('--cache-dir', type=str, default=None, help='Model cache directory')
args = parser.parse_args()

# ===================== 进度回调函数 =====================
class ProgressTracker:
    def __init__(self, total_steps):
        self.total_steps = total_steps
        self.current_step = 0
        self.start_time = time.time()
        
    def on_step_end(self, pipe, step_index, timestep, callback_kwargs):
        self.current_step = step_index + 1
        progress = (self.current_step / self.total_steps) * 100
        elapsed = time.time() - self.start_time
        eta = (elapsed / self.current_step) * (self.total_steps - self.current_step) if self.current_step > 0 else 0
        
        print(f'[生成进度] 步骤 {self.current_step}/{self.total_steps} ({progress:.1f}%) - 已用时间: {elapsed:.1f}s - 预计剩余: {eta:.1f}s', flush=True)
        return callback_kwargs

# ===================== 模型下载函数 =====================
def download_model(cache_dir):
    """使用 modelscope 下载模型"""
    try:
        from modelscope import snapshot_download
        
        print('[模型下载] 开始下载 stable-diffusion-xl-base-1.0 模型...', flush=True)
        print('[模型下载] 这可能需要较长时间（约 5-10GB），请耐心等待...', flush=True)
        
        download_start = time.time()
        
        # 使用 modelscope 下载模型
        model_dir = snapshot_download(
            'AI-ModelScope/stable-diffusion-xl-base-1.0',
            cache_dir=cache_dir,
            revision='master'
        )
        
        download_time = time.time() - download_start
        print(f'[模型下载] 模型下载完成，耗时: {download_time:.1f}s', flush=True)
        print(f'[模型下载] 模型保存在: {model_dir}', flush=True)
        
        return model_dir
        
    except ImportError:
        print('ERROR: 未找到 modelscope 库，请先安装: pip install modelscope', file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f'ERROR: 模型下载失败: {str(e)}', file=sys.stderr)
        sys.exit(1)

# ===================== 获取模型路径 =====================
def get_model_path():
    """获取模型路径，如果不存在则下载"""
    # 优先使用命令行参数
    if args.model_path and os.path.exists(args.model_path):
        return args.model_path
    
    # 其次使用环境变量
    env_path = os.environ.get('SDXL_MODEL_PATH')
    if env_path and os.path.exists(env_path):
        return env_path
    
    # 使用默认缓存目录
    if args.cache_dir:
        cache_dir = args.cache_dir
    else:
        # 使用用户主目录下的 .cache
        cache_dir = os.path.expanduser('~/.cache/CreatingImage/models')
    
    # 检查模型是否已存在
    model_dir = os.path.join(cache_dir, 'AI-ModelScope/stable-diffusion-xl-base-1.0')
    
    # 调试信息
    print(f'[调试] 缓存目录: {cache_dir}', flush=True)
    print(f'[调试] 模型目录: {model_dir}', flush=True)
    print(f'[调试] 模型目录是否存在: {os.path.exists(model_dir)}', flush=True)
    print(f'[调试] 缓存目录内容: {os.listdir(cache_dir) if os.path.exists(cache_dir) else "目录不存在"}', flush=True)
    
    if os.path.exists(model_dir):
        print(f'[初始化] 找到本地模型: {model_dir}', flush=True)
        return model_dir
    
    # 模型不存在，需要下载
    print('[初始化] 本地模型不存在，需要下载...', flush=True)
    return download_model(cache_dir)

# 获取模型路径
LOCAL_MODEL_PATH = get_model_path()

print(f'[初始化] 模型路径: {LOCAL_MODEL_PATH}', flush=True)

# ===================== 设备适配（兼容 CUDA/CPU/MPS） =====================
# 优先使用 MPS（M 芯片）→ CUDA → CPU
if torch.backends.mps.is_available():
    device = 'mps'
elif torch.cuda.is_available():
    device = 'cuda'
else:
    device = 'cpu'
print(f'[初始化] 使用设备: {device}', flush=True)

# ===================== 加载本地模型 =====================
print(f'[模型加载] 开始加载模型...', flush=True)
load_start_time = time.time()

try:
    pipe = StableDiffusionXLPipeline.from_pretrained(
        LOCAL_MODEL_PATH,  # 加载本地模型（核心修改点）
        torch_dtype=torch.float16,
        # M 芯片优化：禁用 FlashAttention，启用兼容的 Attention
        disable_flash_attention=True if device == 'mps' else False,
        # 显示加载进度
        low_cpu_mem_usage=True,
    ).to(device)
    
    load_time = time.time() - load_start_time
    print(f'[模型加载] 模型加载完成，耗时: {load_time:.1f}s', flush=True)
    
except Exception as e:
    print(f'ERROR: 模型加载失败：{str(e)}', file=sys.stderr, flush=True)
    sys.exit(1)

# ===================== 内存优化（可选） =====================
# M 芯片/低显存设备开启 CPU 分块加载，减少内存占用
if device in ['mps', 'cpu']:
    print(f'[优化] 启用内存优化...', flush=True)
    pipe.enable_sequential_cpu_offload()
    pipe.vae.enable_slicing()  # VAE 分块推理
    print(f'[优化] 内存优化完成', flush=True)

# ===================== 生成图片 =====================
print(f'[生成] 开始生成图片', flush=True)
print(f'[生成] 提示词: {args.prompt}', flush=True)
print(f'[生成] 推理步数: {args.steps}', flush=True)

try:
    # 创建进度追踪器
    progress_tracker = ProgressTracker(args.steps)
    
    # 开始生成
    gen_start_time = time.time()
    
    image = pipe(
        args.prompt,
        num_inference_steps=args.steps,
        guidance_scale=7.5,
        callback_on_step_end=progress_tracker.on_step_end,
        callback_on_step_end_tensor_inputs=['latents'],
    ).images[0]
    
    gen_time = time.time() - gen_start_time
    print(f'[生成] 图片生成完成，耗时: {gen_time:.1f}s', flush=True)

    # 保存图片
    print(f'[保存] 正在保存图片到: {args.output}', flush=True)
    image.save(args.output)
    print(f'SUCCESS: 图片已保存为：{args.output}', flush=True)
    
except Exception as e:
    print(f'ERROR: 生成图片时出错：{str(e)}', file=sys.stderr, flush=True)
    sys.exit(1)
