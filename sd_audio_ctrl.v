module sd_audio_ctrl(
    input               clk,
    input               rst_n,
    
    // 音频接口
    input [31:0]        audio_data_in,        // 来自ADC的音频数据 (实际24位有效)
    output reg [31:0]   audio_data_out,       // 发送到DAC的音频数据
    input               audio_data_valid,     // 音频数据有效信号
    input               aud_lrc,              // 声道指示信号
    
    // SD卡接口 (8-bit)
    input               sd_init_done,
    output reg          sd_sec_read,
    output reg [31:0]   sd_sec_read_addr,
    input [7:0]         sd_sec_read_data,     
    input               sd_sec_read_data_valid,
    input               sd_sec_read_end,
    output reg          sd_sec_write,
    output reg [31:0]   sd_sec_write_addr,
    output [7:0]        sd_sec_write_data,    // 使用组合逻辑
    input               sd_sec_write_data_req,
    input               sd_sec_write_end,
    
    // 控制信号
    input               record_en,
    input               play_en
);

// 状态定义
localparam IDLE        = 3'd0;
localparam RECORDING   = 3'd1;
localparam PLAYING     = 3'd2;

localparam DATA_START_SECTOR = 32'd33000; 
localparam SAMPLES_PER_SECTOR = 9'd170;  // 170 个 24-bit 样本 (510 字节)

// 内部寄存器
reg [2:0] state;
reg [31:0] record_addr;      
reg [31:0] play_addr;        
reg channel_flag;            
reg lrc_d0;                  
reg record_fifo_data_valid; // 用于标记 FIFO 数据已出现在总线上
// --- FIFO 接口 ---
// 录音 FIFO (ADC -> SD)
wire            record_fifo_full;
wire            record_fifo_empty;
wire [23:0]     record_fifo_dout;
reg             record_fifo_rd_en;

// 播放 FIFO (SD -> DAC)
wire            play_fifo_full;
wire            play_fifo_empty;
reg [23:0]      play_fifo_din;
reg             play_fifo_wr_en;
wire [23:0]     play_fifo_dout;
reg             play_fifo_rd_en;
// --- 跨时钟域处理 (CDC) ---
reg [2:0] valid_sync; // 用于同步 audio_data_valid
wire      valid_pulse; // 系统时钟域下的单周期脉冲

// 边沿检测逻辑
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        valid_sync <= 3'd0;
    else 
        valid_sync <= {valid_sync[1:0], audio_data_valid};
end

// 检测上升沿：当前是高 (bit 1)，上一拍是低 (bit 2)
assign valid_pulse = valid_sync[1] && ~valid_sync[2];
// --- 状态机寄存器 ---
// (录音)
reg [8:0]       rec_sample_cnt;     // 0-169, SD卡从FIFO已读取的样本数
reg [23:0]      rec_sample_reg;     // 存储从FIFO读出的样本
reg [1:0]       rec_byte_cnt;       // 0-2, 序列化器字节计数
// (播放)
reg [8:0]       play_sample_cnt;    // 0-169, SD卡已写入FIFO的样本数
reg [1:0]       play_byte_cnt;      // 0-2, 解串器字节计数
reg [15:0]      play_byte_temp;     // 存储字节 0 和 1
// (DAC)
reg [23:0]      playback_buffer [0:1]; // L/R 缓冲
reg             playback_data_ready;
reg [1:0] dac_read_state; // 修改为 2 bit
localparam DAC_IDLE   = 2'd0;
localparam DAC_WAIT_L = 2'd1; // 原来的状态 1
localparam DAC_WAIT_R = 2'd2; // 新增状态
// LRC边沿检测 (逻辑不变)
wire lrc_edge;
assign lrc_edge = aud_lrc ^ lrc_d0;
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        lrc_d0 <= 1'b0;
        channel_flag <= 1'b0;
    end else begin
        lrc_d0 <= aud_lrc;
        if(lrc_edge) begin
            channel_flag <= ~channel_flag;
        end
    end
end

// --- 录音序列化器 (组合逻辑) ---
// (在 sd_sec_write_data_req 的同一周期立即提供数据)
assign sd_sec_write_data = (rec_sample_cnt >= SAMPLES_PER_SECTOR) 
                           ? 8'hFF // 已发送完 510 字节, 用 0xFF 填充剩余的 2 字节
                           : (rec_byte_cnt == 2'd0) 
                             ? rec_sample_reg[7:0]   // LSB
                             : (rec_byte_cnt == 2'd1) 
                               ? rec_sample_reg[15:8]  // Mid
                               : rec_sample_reg[23:16]; // MSB
// ============================================================
// 新增：独立的 FIFO 数据锁存逻辑 (必须放在主状态机外面)
// ============================================================

// 1. 产生延迟一拍的有效信号 (打拍)
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) 
        record_fifo_data_valid <= 1'b0;
    else 
        record_fifo_data_valid <= record_fifo_rd_en;
end

// 2. 当有效信号为高时，锁存 FIFO 输出的数据
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        rec_sample_reg <= 24'd0;
    else if(record_fifo_data_valid) 
        rec_sample_reg <= record_fifo_dout;
end
// ============================================================
// --- 状态机 (时序逻辑) ---
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        state <= IDLE;
        record_addr <= DATA_START_SECTOR;
        play_addr <= DATA_START_SECTOR;
        sd_sec_read <= 1'b0;
        sd_sec_write <= 1'b0;
        audio_data_out <= 32'd0;
        playback_data_ready <= 1'b0;
        
        // 复位FIFO控制
        record_fifo_rd_en <= 1'b0;
        play_fifo_wr_en <= 1'b0;
        play_fifo_rd_en <= 1'b0;
        
        // 复位状态机
        rec_sample_cnt <= 9'd0;
        rec_byte_cnt <= 2'd0;
        play_sample_cnt <= 9'd0;
        play_byte_cnt <= 2'd0;
        dac_read_state <= 1'b0;
        
    end else begin
    
        // 默认关闭使能
        record_fifo_rd_en <= 1'b0;
        play_fifo_wr_en <= 1'b0;
        play_fifo_rd_en <= 1'b0;

        case(state)
            IDLE: begin
                if(record_en && sd_init_done) begin
                    state <= RECORDING;
                    record_addr <= DATA_START_SECTOR;
                    rec_sample_cnt <= 9'd0;
                    rec_byte_cnt <= 2'd0;
                end else if(play_en && sd_init_done) begin
                    state <= PLAYING;
                    sd_sec_read <= 1'b1;
                    sd_sec_read_addr <= DATA_START_SECTOR;
                    play_addr <= DATA_START_SECTOR + 1;
                    
                    play_sample_cnt <= 9'd0;
                    play_byte_cnt <= 2'd0;
                    dac_read_state <= 1'b0;
                    playback_data_ready <= 1'b0;
                end
            end
            
            RECORDING: begin
                if(!record_en) begin
                    state <= IDLE;
                    sd_sec_write <= 1'b0; 
                end
                
                // --- SD 卡写入状态机 (低速) ---
                if(!sd_sec_write) begin
                    // 状态 1: 等待 FIFO 中有足够的数据
                    if(!record_fifo_empty) begin // 只要有数据就开始写，不一定等满
                        sd_sec_write <= 1'b1;
                        sd_sec_write_addr <= record_addr;
                        record_addr <= record_addr + 1;
                        
                        rec_sample_cnt <= 9'd0;
                        rec_byte_cnt <= 2'd0;
                        record_fifo_rd_en <= 1'b1; // 发出第一次读取请求
                    end
                end else begin
                    // 状态 2: 正在写入
                    
                    // 当 SD 卡请求数据时，推进序列化器
                    if(sd_sec_write_data_req) begin
                        if(rec_sample_cnt < SAMPLES_PER_SECTOR) begin
                            if(rec_byte_cnt == 2'd2) begin
                                rec_byte_cnt <= 2'd0;
                                rec_sample_cnt <= rec_sample_cnt + 1;
                                // 从 FIFO 请求下一个样本
                                record_fifo_rd_en <= 1'b1; 
                            end else begin
                                rec_byte_cnt <= rec_byte_cnt + 1;
                            end
                        end
                        // (如果 >= SAMPLES_PER_SECTOR, 计数器停止, 组合逻辑将发送 0xFF)
                    end
                    
                    // 状态 3: 写入完成
                    if(sd_sec_write_end) begin
                        sd_sec_write <= 1'b0;
                    end
                end                          
			
            end // case RECORDING
            
            PLAYING: begin
                if(!play_en) begin
                    state <= IDLE;
                    sd_sec_read <= 1'b0;
                end
                
                // --- 1. SD 卡填充 FIFO (解串器) ---
                if(sd_sec_read_data_valid) begin
                    if(play_sample_cnt < SAMPLES_PER_SECTOR) begin
                        if(play_byte_cnt == 2'd0) begin
                            play_byte_temp[7:0] <= sd_sec_read_data; // LSB
                            play_byte_cnt <= 2'd1;
                        end else if(play_byte_cnt == 2'd1) begin
                            play_byte_temp[15:8] <= sd_sec_read_data; // Mid
                            play_byte_cnt <= 2'd2;
                        end else begin 
                            // 收到 MSB，样本已完整
                            play_fifo_din <= {sd_sec_read_data, play_byte_temp};
                            play_fifo_wr_en <= 1'b1; // 向 FIFO 写入一个 24-bit 样本
                            
                            play_byte_cnt <= 2'd0;
                            play_sample_cnt <= play_sample_cnt + 1;
                        end
                    end
                    // (忽略扇区末尾多余的 2 字节)
                end
                
                // --- 2. SD 卡读取完成 ---
                if(sd_sec_read_end) begin
    				sd_sec_read <= 1'b0;              // 先停止读取信号
    				play_addr <= play_addr + 1;       // 无论 FIFO 是否满，扇区地址都要加 1，为下次做准备
				end

				// --- 新增：SD 卡读取重启逻辑 ---
				// 如果当前没有在读 (sd_sec_read == 0)，且 FIFO 不满，且不在读取结束的那一拍
				if(sd_sec_read == 1'b0 && play_fifo_full == 1'b0 && sd_sec_read_end == 1'b0) begin
    				sd_sec_read <= 1'b1;              // 重新拉高读取信号
    				sd_sec_read_addr <= play_addr;    // 使用更新后的地址
    				play_sample_cnt <= 9'd0;          // 重置计数器
    				play_byte_cnt <= 2'd0;
				end

                // --- 3. DAC 读取逻辑 (高速) ---
                case(dac_read_state)
    				DAC_IDLE: begin
        				// 当 DAC 准备好接收新数据 (ready=0) 且 FIFO 有数时
        				if(!playback_data_ready && !play_fifo_empty) begin
            				play_fifo_rd_en <= 1'b1;      // 请求 L 样本
            				dac_read_state <= DAC_WAIT_L; // 进入等待 L 状态
        				end
    				end

    				DAC_WAIT_L: begin
       			 	play_fifo_rd_en <= 1'b0;          // 停止读请求
        			playback_buffer[0] <= play_fifo_dout; // 【关键】此时 dout 是有效的 L 数据
        
        				// 检查是否有 R 样本
        				if(!play_fifo_empty) begin
            				play_fifo_rd_en <= 1'b1;      // 请求 R 样本
            				dac_read_state <= DAC_WAIT_R; // 进入等待 R 状态
        				end
        				// 如果 FIFO 空了，就停在这里等数据，不会乱跑
    				end

    				DAC_WAIT_R: begin
        				play_fifo_rd_en <= 1'b0;          // 停止读请求
        				playback_buffer[1] <= play_fifo_dout; // 【关键】此时 dout 是有效的 R 数据
        
        				playback_data_ready <= 1'b1;      // 标记 L/R 数据都准备好了
        				dac_read_state <= DAC_IDLE;       // 回到空闲
   					end
    
    				default: dac_read_state <= DAC_IDLE;
				endcase

				// --- 4. 音频输出 (LRC 驱动) ---
if(playback_data_ready) begin
    if(channel_flag == 1'b0) begin
        // 【修正】改回低位对齐！
        // audio_send 模块只会读取低 24 位，所以数据必须放在低位。
        audio_data_out <= {8'd0, playback_buffer[0]}; // 播放 L
    end else begin
        // 【修正】改回低位对齐！
        audio_data_out <= {8'd0, playback_buffer[1]}; // 播放 R
        
        playback_data_ready <= 1'b0; 
    end
end

            end // case PLAYING
            
            default: state <= IDLE;
        endcase
    end
end

// =============================================================================
//                             FIFO 实例化
// =============================================================================

// *** 录音 FIFO: ADC (写) -> SD 卡 (读) ***
// (您必须使用 IP 生成器创建此模块)
record_fifo record_fifo_inst (
    .clkw      (clk),                  
    .we        (valid_pulse && (state == RECORDING)), 
    .di        (audio_data_in[23:0]),  // 宽度必须是 24!
    .full_flag (record_fifo_full),     

    .clkr      (clk),                  
    .re        (record_fifo_rd_en),    
    .do        (record_fifo_dout),     // 宽度必须是 24!
    .empty_flag(record_fifo_empty),
    
    .rst       (~rst_n) // 假设 rst 是高电平复位
);


// *** 播放 FIFO: SD 卡 (写) -> DAC (读) ***
// (您必须使用 IP 生成器创建此模块)
play_fifo play_fifo_inst (
    .clkw      (clk),                  
    .we        (play_fifo_wr_en),      // <-- 修正: 使用播放FIFO的写使能
    .di        (play_fifo_din),        // <-- 修正: 使用播放FIFO的写数据
    .full_flag (play_fifo_full),       // <-- 修正: 使用播放FIFO的满标志

    // 读端口 (由 DAC 逻辑驱动)
    .clkr      (clk),                  
    .re        (play_fifo_rd_en),      // <-- 修正: 使用播放FIFO的读使能
    .do        (play_fifo_dout),       // <-- 修正: 使用播放FIFO的读数据
    .empty_flag(play_fifo_empty),      // <-- 修正: 使用播放FIFO的空标志
    
    .rst       (~rst_n)
);


endmodule