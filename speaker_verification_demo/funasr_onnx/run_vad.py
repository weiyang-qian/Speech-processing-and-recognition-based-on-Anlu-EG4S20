# -*- coding: utf-8 -*-
"""
一键运行的 VAD 推理脚本（基于 ONNX）。

用法示例：
  python run_vad.py --model_dir ./FSMN-VAD --wav_path ./test.wav

可选参数：
  --quantize            使用量化 ONNX（model_quant.onnx）
  --device_id           设备 ID（-1=CPU，>=0 指定 GPU/设备，取决于 onnxruntime 后端）
  --threads             onnxruntime 计算线程数

说明：
- 该脚本依赖仓库中的 `funasr_onnx.vad_bin.Fsmn_vad`。
- 模型目录需包含：model.onnx 或 model_quant.onnx、config.yaml、am.mvn。
"""

import argparse
import sys
from pathlib import Path


# 确保可以以包形式导入 funasr_onnx（从仓库根目录/父目录运行也可用）
CURRENT_FILE = Path(__file__).resolve()
PACKAGE_DIR = CURRENT_FILE.parent
PARENT_DIR = PACKAGE_DIR.parent
if str(PARENT_DIR) not in sys.path:
    sys.path.insert(0, str(PARENT_DIR))

from funasr_onnx.vad_bin import Fsmn_vad  # noqa: E402


def parse_args():
    parser = argparse.ArgumentParser(description="FSMN-VAD ONNX 推理")
    parser.add_argument("--model_dir", type=str, default="./FSMN-VAD", help="模型目录")
    parser.add_argument("--wav_path", type=str, required=True, help="待推理音频（.wav）路径")
    parser.add_argument("--quantize", action="store_true", help="使用量化 ONNX 模型")
    parser.add_argument("--device_id", type=str, default="-1", help="-1=CPU，其他按后端规定")
    parser.add_argument("--threads", type=int, default=4, help="onnxruntime 线程数")
    return parser.parse_args()


def main():
    args = parse_args()

    model_dir = Path(args.model_dir).resolve()
    wav_path = Path(args.wav_path).resolve()

    # 基本参数检查
    if not model_dir.exists():
        print(f"[ERROR] 模型目录不存在: {model_dir}")
        sys.exit(1)
    if not wav_path.exists():
        print(f"[ERROR] 音频文件不存在: {wav_path}")
        sys.exit(1)

    # 创建 VAD 模型（基于 ONNX）
    # 说明：Fsmn_vad 内部会根据 quantize 选择 model.onnx 或 model_quant.onnx
    model = Fsmn_vad(
        model_dir=str(model_dir),
        quantize=args.quantize,
        device_id=args.device_id,
        intra_op_num_threads=args.threads,
    )

    # 进行推理，返回分段结果
    # 结果通常为 [[(start_ms, end_ms), ...]]，不同配置可能有所差异
    result = model(str(wav_path))

    print("=== VAD 推理结果 ===")
    print(result)


if __name__ == "__main__":
    main()


