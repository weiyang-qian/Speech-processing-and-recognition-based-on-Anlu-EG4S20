# ES8388 FPGA 项目完整代码解析（中文版）

更新时间：2026-04-14  
项目根目录：ES8388/ES83881

## 1. 生效构建基线

- 顶层模块是 RTL/audio_speak.v。
- 当前综合真正生效的 FIR 实现是 RTL/fir_filter.sv，而不是同名的 RTL/fir_filter.v。
- 证据来自综合日志：
  - TD/ES8388_Runs/syn_1/run.log 中出现 `analyze verilog file ../../../RTL/fir_filter.sv`。
  - 同文件出现 `elaborate module fir_filter ... in ../../../RTL/fir_filter.sv(1)`。
- 时序报告当前无有效约束路径：
  - TD/audio_speak_timing.rpt 显示 `Constraint path number: 0 (STA coverage = 0.00%)`。

## 2. 顶层架构（RTL/audio_speak.v）

### 2.1 顶层职责

- 通过 rst_cnt 做复位释放延时。
- 通过 PLL（clk_wiz_0）生成 aud_mclk。
- 串接三条主链路：
  - 实时音频处理链：es8388_ctrl。
  - SD 音频缓存与录放控制：sd_audio_ctrl。
  - SD SPI 协议栈：sd_card_top。

### 2.2 播放源选择逻辑

- 关键选择寄存器：dac_data_sel。
- 行为如下：
  - play_en=1 时，DAC 数据来自 sd_playback_data（回放模式）。
  - 否则 DAC 数据来自 adc_data（实时链路）。

### 2.3 顶层集成中的重要注意点

- 在 audio_speak.v 中，sd_sec_read_data / sd_sec_write_data 定义为 32 位。
- 在 sd_card_top.v 中，这两个接口是 8 位。
- 因此综合日志出现端口位宽不匹配告警（属于可解释但应清理的问题）。

## 3. ES8388 初始化链（I2C）

### 3.1 模块关系与数据流

- 封装模块：RTL/es8388_config.v。
- 其内部包含：
  - i2c_reg_cfg：产生寄存器初始化序列。
  - i2c_dri：执行 I2C 位级时序。

整体流程：
1. i2c_reg_cfg 输出 i2c_exec 以及寄存器地址/数据。
2. i2c_dri 完成 start/address/data/ack/stop 传输。
3. i2c_done 回传后触发下一条寄存器写入。
4. 全部完成后 cfg_done 拉高。

### 3.2 寄存器配置表（RTL/i2c_reg_cfg.v）

- REG_NUM=24，表示共写 24 组寄存器。
- WL 参数会映射到 codec 的字长配置编码。
- 表中包含关键项：
  - ADC 24bit I2S 配置。
  - DAC 24bit I2S 配置。
  - ADC/DAC 相关采样率配置（48k 路径）。
  - 输入/输出增益与 mixer 相关寄存器。

### 3.3 I2C 驱动状态机（RTL/i2c_dri.v）

主要状态：
- st_idle：空闲态，等待 i2c_exec 启动一次事务。
- st_sladdr：发送从设备地址和读写位（R/W）。
- st_addr16：发送 16 位寄存器地址高 8 位（仅在 bit_ctrl=1 时进入）。
- st_addr8：发送 8 位寄存器地址。
- st_data_wr：发送 1 字节写数据。
- st_addr_rd：读流程中的重复起始和读地址阶段。
- st_data_rd：读取 1 字节数据。
- st_stop：发送停止条件并结束本次事务。

常见状态路径：
- 写寄存器：st_idle -> st_sladdr -> st_addr8（或先 st_addr16 再 st_addr8）-> st_data_wr -> st_stop -> st_idle。
- 读寄存器（模块通用能力）：st_idle -> st_sladdr -> st_addr8（或先 st_addr16 再 st_addr8）-> st_addr_rd -> st_data_rd -> st_stop -> st_idle。
- 当前工程在 es8388_config 中将 i2c_rh_wl 固定为 1'b0，因此实际主要走写寄存器路径。

关键实现点：
- dri_clk 由系统时钟分频得到，分频公式为 clk_divide = (CLK_FREQ/I2C_FREQ) >> 3。
- 当 clk_cnt == clk_divide - 1 时翻转 dri_clk，主状态机和位级计数都在 dri_clk 域推进。
- 完成一次完整事务后，i2c_done 拉高通知上层。
- 分频后的 dri_clk 作用是：
  - 把系统时钟（当前配置 50MHz）降到 I2C 友好的内部节拍，保证外部 SCL 约 250kHz 的目标时序可实现。
  - 在统一节拍上精确安排 start/stop、SDA 翻转、ACK 采样等时刻。
  - 避免状态机直接运行在高速系统时钟下导致时序过密、控制不稳定。

已观察到的对应告警：
- i2c_dri 端口 i2c_addr 是 16 位。
- 上层连接 reg_data[15:8]（8 位）到该端口。
- 综合日志因此给出 bit-length mismatch 告警。

## 4. 实时音频处理链（RTL/es8388_ctrl.v）

### 4.1 前端采集与声道对齐

- audio_receive 在 aud_bclk 域采样串行 ADC 数据。
- aud_lrc 先打一拍（aud_lrc_d0）用于声道对齐。
- 原始输出为 adc_data_raw 和 rx_done_raw。

### 4.2 FIR 可开关路径

- FIR 实例：u_fir_filter。
- 输入有效信号使用 rx_done_raw。
- FIR 输出携带声道标记 data_out_channel。
- filter_en 控制旁路：
  - 1：走 FIR 输出。
  - 0：走延时后的原始数据。

### 4.3 变声前立体声重组

- FIR 后数据流是 L/R 交织。
- 控制逻辑分别缓存左、右样本。
- 当右声道到达且左右都就绪时，vc_stereo_valid_in 拉高一拍。

### 4.4 变声与最终输出选择

- voice_change_stereo 对左右声道并行处理。
- voice_change_en=1 时选择变声输出。
- voice_change_en=0 时选择原始左右缓存。
- 然后按当前声道重新交织为 dac_data_final 送 audio_send。

### 4.5 并行定位分支

- sound_localization 读取左右缓存与有效信号。
- localization_en 控制定位分支是否工作。

## 5. I2S 收发细节

### 5.1 audio_receive（RTL/audio_receive.v）

- 用 lrc_edge 检测声道切换并清零 rx_cnt。
- 在 aud_bclk 上升沿移入 aud_adcdat。
- 数据组装到 adc_data_t。
- 当 rx_cnt==WL 时，rx_done 拉高一拍并更新 adc_data。

### 5.2 audio_send（RTL/audio_send.v）

- 在 lrc_edge 时锁存待发送帧 dac_data_t。
- 在 aud_bclk 下降沿串行输出 aud_dacdat。
- tx_cnt==WL 时 tx_done 拉高一拍。

## 6. FIR 实现细节（当前生效：RTL/fir_filter.sv）

### 6.1 结构

- TAPS=28。
- 左右声道各自独立延迟线。
- 使用有符号乘加，内部累计宽度扩展到 64 位。

### 6.2 数值处理

- 系数按有符号定点处理。
- 乘加结束后按 COEFF_WIDTH-1 右移（Q 格式缩放）。
- 输出前调用饱和函数，避免直接截断溢出。

### 6.3 资源映射

- 面积报告显示 u_fir_filter 是 DSP 主要消耗源之一。
- 层级表中 u_fir_filter 使用 25 个 DSP。

## 7. 变声算法（RTL/voice_change.v 与 RTL/voice_change_stereo.v）

### 7.1 核心思路

- 双 RAM ping-pong 缓冲。
- 相位累加器 phase_acc 产生重采样读地址。
- CHANGE_MODE 选择升调/降调步进。
- 使用相邻样本简单插值平滑。

### 7.2 伪影抑制

- 算法叠加两层窗函数：
  - 相位窗（phase window）。
  - 帧窗（frame window）。
- 窗后数据写入 FIFO，供输出侧读取。

### 7.3 立体声封装

- voice_change_stereo 内部实例化：
  - vc_left
  - vc_right
- 二者共享 CHANGE_MODE 与 data_valid 控制。

### 7.4 与日志告警对应

- run.log 中可见 voice_change_ram 实例的 doa/ocea 未连接相关告警。
- 需结合 IP 端口设计意图判断是否为可接受告警。

## 8. 声源定位（RTL/sound_localization.v）

### 8.1 计算流程

- 计算左右输入幅值绝对值。
- 通过漏电积分器做平滑：
  - left_intensity
  - right_intensity
- 计算差分 diff = left_intensity - right_intensity。

### 8.2 LED 映射

- 根据 diff 与多级阈值比较，映射为方向 LED 图样：
  - diff 正向大：偏左。
  - diff 负向大：偏右。
  - 接近 0：居中。

## 9. SD 音频桥（RTL/sd_audio_ctrl.v）

### 9.1 状态与数据粒度

- 主状态：IDLE / RECORDING / PLAYING。
- SAMPLES_PER_SECTOR=170：
  - 每样本 24bit=3 字节。
  - 170 样本正好 510 字节。
  - 扇区余下 2 字节填 0xFF。

### 9.2 CDC 处理

- audio_data_valid 经 valid_sync 打拍同步到 clk 域。
- valid_pulse 在系统时钟域产生单周期上升沿脉冲。

### 9.3 录音路径（ADC -> FIFO -> SD）

1. valid_pulse 到来时，将 24bit 样本写入 record_fifo。
2. SD 请求写数据时，从 FIFO 读出样本。
3. 序列化顺序：LSB -> Mid -> MSB。
4. 达到 170 样本后，剩余两字节由 0xFF 填充。

### 9.4 播放路径（SD -> FIFO -> DAC）

1. SD 读回字节流后，每 3 字节重组为 24bit 样本。
2. 样本写入 play_fifo。
3. DAC 侧小状态机按 L 后 R 读出到 playback_buffer。
4. 最终按 channel_flag 选择左/右，低 24 位对齐输出给 audio_send。

## 10. SD SPI 协议栈

### 10.1 sd_card_top（RTL/sd_card_top.v）

- 作为 8-bit 接口封装层，连接：
  - sd_card_sec_read_write
  - sd_card_cmd
  - spi_master
- 主要是接口透传与模块编排。

### 10.2 sd_card_sec_read_write（RTL/sd_card_sec_read_write.v）

初始化状态序列：
- CMD0 -> CMD8 -> CMD55 -> ACMD41 -> CMD16

读写状态：
- 读：CMD17 + READ
- 写：CMD24 + WRITE

职责：
- 负责卡初始化、扇区地址管理、读写请求流程调度。

### 10.3 sd_card_cmd（RTL/sd_card_cmd.v）

- 字节级命令与数据收发状态机。
- 关键行为：
  - 命令发送与 R1 响应判定。
  - 读 token 0xFE 等待与块读。
  - 写 token 0xFE、512 字节写入、CRC、响应判定、busy 释放等待。

### 10.4 spi_master（RTL/spi_master.v）

- 位级 SPI 发送/接收状态机。
- 支持 CPOL/CPHA 时序分支。
- 使用 wr_req / wr_ack 做字节握手。

## 11. 报告映射：资源与风险

### 11.1 资源利用（TD/ES8388_Runs/phy_1/ES8388_phy.area）

- LUT: 6349 / 19600 (32.39%)
- REG: 3224 / 19600 (16.45%)
- DSP: 29 / 29 (100.00%)
- BRAM: 30 / 64 (46.88%)

层级重点：
- u_fir_filter：DSP 主要来源。
- u_voice_change_stereo：BRAM + DSP 占用较高。
- u_sd_audio_ctrl：FIFO 占 BRAM。
- u_sd_card_top：协议控制逻辑为主。

### 11.2 时序状态

- STA coverage=0.00% 表示当前未形成有效用户时序约束覆盖。
- 板上可运行不等于时序签核完成。

### 11.3 综合日志告警类型

- 顶层 SD 接口 32/8 位宽不匹配。
- I2C 地址端口位宽不匹配。
- 顶层隐式网络（chipwatcherclk）告警。
- voice_change_ram 的未连接端口告警。

## 12. 端到端运行行为总结

1. 上电阶段
   - PLL 锁定后，I2C 链路按表初始化 ES8388。

2. 实时模式（play_en=0）
   - ADC 采集 -> 可选 FIR -> 可选变声 -> DAC 发送。

3. 录音模式（record_en=1）
   - ADC 数据缓冲并序列化，经 SD 协议栈写入扇区。

4. 播放模式（play_en=1）
   - 从 SD 扇区读回，解串重组，缓存后按 L/R 输出到 DAC。

5. 定位模式（localization_en=1）
   - 与主音频链并行运行，输出方向 LED。

## 13. 文档用途建议

本中文版文档按“代码真实行为 + 状态机 + 报告证据”组织，可直接用于：
- 课程/项目技术报告正文。
- 后续重构与清理告警的检查清单。
- 现场汇报时的讲解底稿。
