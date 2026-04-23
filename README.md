# 基于 EG4S20 的音频处理与声纹识别系统
This project is based on the domestic Anlu EG4S20 core board and ES8388 sound card, and designs a real-time audio processing and voiceprint authentication system

## 1. 项目简介
本项目面向 2025 年 FPGA 创新设计场景，完成了一个“硬件实时音频处理 + 软件声纹身份确认”的完整方案：

- FPGA 硬件侧负责音频采集、处理、回放与本地存储。
- Python 软件侧负责说话人注册、声纹特征提取和身份验证。
- 两部分可独立演示，也可组合构成端到端的智能语音系统原型。

## 2. 总体架构

### 2.1 硬件链路（FPGA）
ES8388 Codec -> I2S采集 -> 可选FIR滤波 -> 可选变声 -> I2S回放到ES8388 DAC

并行分支：
- 声源定位分支：左右声道能量估计 -> LED方向显示
- SD存储分支：录音写入SD卡 / 回放从SD卡读取

### 2.2 软件链路（Python）
音频输入（上传或录音） -> 预处理（单声道16kHz） -> Fbank特征 -> CAM++ ONNX推理 -> 嵌入向量

两种业务路径：
- 注册：保存说话人嵌入到本地数据库
- 验证：与数据库逐一计算余弦相似度，结合阈值给出认证结果

## 3. FPGA 硬件部分：功能与实现

## 3.1 顶层模块与系统组织
顶层模块为 `ES83881/RTL/audio_speak.v`，核心职责如下：

- 复位与时钟：通过 `rst_cnt` 延时释放复位，PLL 生成 `aud_mclk`。
- 音频源选择：`play_en=1` 时，DAC 数据来自 SD 回放；否则来自实时采集链路。
- 模块集成：串接 `es8388_ctrl`、`sd_audio_ctrl`、`sd_card_top`。
- 状态显示：`led = {sd_init_done, led_from_ctrl}`，高位显示 SD 初始化状态。

## 3.2 ES8388 初始化与实时音频处理
实时链路主要在 `ES83881/RTL/es8388_ctrl.v` 内实现：

- Codec 初始化：
  - `es8388_config` 封装 I2C 初始化流程。
  - `i2c_reg_cfg` 生成寄存器配置序列（24 组寄存器）。
  - `i2c_dri` 执行 I2C 位级时序（start/address/data/ack/stop）。

- I2S 收发：
  - `audio_receive` 从 `aud_adcdat` 采样并输出 24bit 音频数据。
  - `audio_send` 将处理后的音频序列化到 `aud_dacdat`。

- 可选 FIR 滤波：
  - 模块：`fir_filter`（综合生效版本为 `fir_filter.sv`）。
  - 双声道独立延迟线、定点乘加、饱和裁剪，支持开关 `filter_en`。

- 可选变声：
  - 模块：`voice_change_stereo` + 双路 `voice_change`。
  - 通过 `CHANGE_MODE` 选择变调方向，支持 `voice_change_en` 开关。

- 声源定位：
  - 模块：`sound_localization`。
  - 对左右声道做平滑能量估计并比较差值，映射为 LED 方向指示。

## 3.3 SD 录音/回放与 SPI 协议栈

### 音频桥接控制（`sd_audio_ctrl.v`）
- 状态机：`IDLE / RECORDING / PLAYING`。
- 录音路径：ADC 样本 -> 录音 FIFO -> 3 字节序列化 -> SD 扇区写入。
- 回放路径：SD 字节流 -> 3 字节重组样本 -> 播放 FIFO -> L/R 交替送 DAC。
- 扇区打包策略：每扇区写入 170 个 24bit 样本（510 字节）+ 2 字节填充。

### SD 底层协议（`sd_card_top.v`）
- `sd_card_sec_read_write`：初始化与读写流程调度（CMD0/CMD8/CMD55/ACMD41/CMD16 等）。
- `sd_card_cmd`：命令帧与数据块收发控制。
- `spi_master`：位级 SPI 读写时序。

## 3.4 硬件控制信号说明（顶层）

- `filter_en`：FIR 滤波使能。
- `voice_change_en`：变声使能。
- `change_mode`：变声模式选择。
- `localization_en`：声源定位使能。
- `record_en`：录音到 SD。
- `play_en`：从 SD 回放。

## 4. Python 声纹识别平台：功能与实现

Python 平台位于：
`speaker_verification_demo(1)/speaker_verification_demo/speaker_verification_demo`

## 4.1 技术栈
- 推理引擎：ONNX Runtime
- 声纹模型：CAM++（`models/sv/campplus_emb.onnx`）
- 特征提取：80 维 Fbank
- 音频处理：torchaudio + soundfile + ffmpeg 三级降级
- Web 界面：Gradio

## 4.2 核心实现（`speaker_verification.py`）

- 音频读取与格式兼容：
  - 优先 `torchaudio`，失败后回退 `soundfile`，再回退 `ffmpeg`。
  - 统一转换为单声道 16kHz。

- 特征提取与向量生成：
  - 分块策略：`seg_dur=1.5s`，`seg_shift=0.75s`。
  - 每块计算 Fbank 后输入 CAM++ 模型得到 embedding。
  - 对所有块 embedding 求均值并做 L2 归一化。

- 身份注册：
  - `register_speaker()` 提取 embedding 后写入 `speaker_db.json`。

- 身份验证：
  - `verify_speaker()` 将待测 embedding 与库内向量做余弦相似度（点积）匹配。
  - 返回最高相似度身份；默认阈值 `0.6`，可外部传入阈值覆盖。

- 数据管理：
  - 支持查询用户、删除用户、清空数据库。

## 4.3 前端交互实现（`gradio_app.py`）

界面按比赛展示需求划分为四个功能区：
- 身份注册区
- 注册人员信息区
- 身份检测区（支持上传和在线录音）
- 身份认证结果区（结果文本、匹配身份、相似度）

同时支持：
- 阈值滑块实时调整
- 音频文件就绪状态提示
- 刷新名单和清空数据库操作

## 5. 目录结构（关键部分）

```text
FPGA-ES8388/
├── ES83881/
│   ├── RTL/                       # FPGA RTL 源码
│   ├── TD/                        # 综合/实现输出与报告
│   └── FPGA_Code_Analysis_Report.md
├── speaker_verification_demo(1)/
│   └── speaker_verification_demo/speaker_verification_demo/
│       ├── gradio_app.py
│       ├── speaker_verification.py
│       ├── requirements.txt
│       ├── speaker_db.json
│       └── models/sv/campplus_emb.onnx
└── README.md
```

## 6. 运行与演示

## 6.1 硬件侧
1. 以 `ES83881/RTL/audio_speak.v` 作为顶层进行综合实现。
2. 连接 ES8388 与 SD 卡外设，完成下载后通过控制信号切换实时/录放/定位模式。
3. 演示建议：
   - 实时链路：开启/关闭 `filter_en`、`voice_change_en` 比较效果。
   - 存储链路：`record_en` 录音后 `play_en` 回放。
   - 定位链路：开启 `localization_en` 观察 LED 指向变化。

## 6.2 软件侧
在 Python 项目目录执行：

```bash
pip install -r requirements.txt
python gradio_app.py --host 0.0.0.0 --port 6011
```

启动后在浏览器打开对应地址，按“注册 -> 验证”流程进行展示。

## 7. 当前实现状态与工程提示

基于现有综合与代码分析结果，建议关注以下点：

- 资源占用：DSP 使用率已接近满载（29/29，约 100%）。
- 时序约束：当前报告显示 STA 覆盖不足，建议补齐时序约束后再做签核。
- 接口位宽：顶层与 SD/I2C 部分存在位宽不匹配告警，建议统一接口定义。

这些问题不影响你进行功能演示，但在工程收敛和可维护性上建议优先清理。

## 8. 项目亮点总结

- FPGA 侧实现了“采集-处理-存储-回放-定位”的完整闭环。
- 软件侧实现了“注册-比对-阈值判决-可视化交互”的完整闭环。
- 整体架构清晰、可演示性强，适合作为比赛展示和后续优化迭代基础。
