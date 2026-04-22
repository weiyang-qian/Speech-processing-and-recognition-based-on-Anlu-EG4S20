module es8388_ctrl(
    input                clk        ,   // 时钟信号
    input                rst_n      ,   // 复位信号
    input                filter_en  ,   // 新增：滤波器使能信号
    input                voice_change_en, // 新增：变调使能
    input                change_mode,     // 新增：变调模式
    input                localization_en,
    //audio interface(mast  
    input                aud_bclk   ,   // es8388位时钟
    input                aud_lrc    ,   // 对齐信号
    input                aud_adcdat ,   // 音频输入
    output               aud_dacdat ,   // 音频输出
    
    //control interfac  
    output               aud_scl    ,   // es8388的SCL信号
    inout                aud_sda    ,   // es8388的SDA信号
    
    //user i    
    output     [31:0]    adc_data   ,   // 输入的音频数据
    input      [31:0]    dac_data   ,   // 输出的音频数据
	 
	// input      [1:0]    volume     ,    //音量配置输入
    output               rx_done    ,   // 一次采集完成
    output               tx_done ,       // 一次发送完成
    output     [7:0]     led_out      //
);

//parameter define
parameter    WL = 6'd24;                // word length音频字长定义
wire [31:0] adc_data_raw;
wire        rx_done_raw;
// 滤波器的输出信号
wire [WL-1:0] filtered_data_out;
wire          filtered_data_valid;
wire          filtered_channel;

//*****************************************************
//**                    main code
//*****************************************************

reg aud_lrc_d0;
always @(posedge aud_bclk or negedge rst_n) begin
    if(!rst_n)
        aud_lrc_d0 <= 1'b0;
    else
        aud_lrc_d0 <= aud_lrc;
end

reg [31:0] adc_data_delay;
reg        rx_done_delay;

always @(posedge aud_bclk or negedge rst_n) begin
    if (!rst_n) begin
        adc_data_delay <= 32'b0;
        rx_done_delay  <= 1'b0;
    end
    else begin
        adc_data_delay <= adc_data_raw;
        rx_done_delay  <= rx_done_raw;
    end
end

assign adc_data = filter_en
                ? { {32-WL{filtered_data_out[WL-1]}}, filtered_data_out[WL-1:0] } // 滤波路径 (带符号扩展)
                : adc_data_delay;                                           // 旁路路径

assign rx_done = filter_en
               ? filtered_data_valid // 滤波路径
               : rx_done_delay;     // 旁路路径
               
wire post_fir_valid = filter_en ? filtered_data_valid : rx_done_delay;
wire post_fir_channel = filter_en ? filtered_channel : aud_lrc_d0;

reg [31:0] vc_left_data_in_reg;
reg [31:0] vc_right_data_in_reg;
reg          vc_stereo_valid_in; // 

// 当L/R对都准备好时，脉冲为高 (但未被 voice_change 使用)
always @(posedge aud_bclk or negedge rst_n) begin
    if (!rst_n) begin
        vc_stereo_valid_in <= 1'b0;
        vc_left_data_in_reg <= 32'b0;
        vc_right_data_in_reg <= 32'b0;
    end else begin
        vc_stereo_valid_in <= 1'b0; // 默认为低
        if (post_fir_valid) begin // 检查环回数据 (dac_data) 是否有效
            if (post_fir_channel == 1'b0) begin // 0 = 左声道
                vc_left_data_in_reg <= dac_data; // 锁存左声道数据 [cite: 100]
            end else begin // 1 = 右声道
                vc_right_data_in_reg <= dac_data; // 锁存右声道数据 [cite: 100]
                vc_stereo_valid_in <= 1'b1; // L/R 对已准备好
            end
        end
    end
end

// 2. 变调模块实例
//    警告：此模块的 sck 逻辑 (cnt1 ) 与脉冲式的 vc_stereo_valid_in 不兼容。
wire [31:0] vc_data_out_left;
wire [31:0] vc_data_out_right;

voice_change_stereo #(
    .P_DATA_WIDTH(32), 
    .P_PITCH_FACTOR(4) 
) u_voice_change_stereo (
    .clk          (clk),       
    .sck          (aud_bclk),  
    .rst_n        (rst_n),
    .CHANGE_MODE  (change_mode), 
    
    .data_valid   (vc_stereo_valid_in), // [新增连接] 关键！
    
    .data_in_left (vc_left_data_in_reg),  
    .data_in_right(vc_right_data_in_reg), 
    .data_out_left (vc_data_out_left),  
    .data_out_right(vc_data_out_right)  
);

// 3. Mux 2 (变调旁路选择)
//    警告：此旁路没有匹配 voice_change 模块的延迟
wire [31:0] final_data_left;
wire [31:0] final_data_right;

assign final_data_left = voice_change_en 
                       ? vc_data_out_left    // 变调路径
                       : vc_left_data_in_reg; // 旁路路径
assign final_data_right = voice_change_en 
                        ? vc_data_out_right   // 变调路径
                        : vc_right_data_in_reg; // 旁路路径


// 4. 重交织器 (Re-interleaver)
//    功能：将并行的 L/R 数据转换回交织流，以馈送 audio_send
wire [31:0] dac_data_final;
assign dac_data_final = (aud_lrc_d0 == 1'b0)
                        ? final_data_left
                        : final_data_right;                           
//例化es8388寄存器配置模块
es8388_config #(
    .WL             (WL)
) u_es8388_config(
    .clk            (clk),              // 时钟信号
    .rst_n          (rst_n),            // 复位信号
    
	// .volume       (volume),          //音量配置输入
	 
    .aud_scl        (aud_scl),          // es8388的SCL时钟
    .aud_sda        (aud_sda)           // es8388的SDA信号
);

//例化es8388音频接收模块
audio_receive #(
    .WL             (WL)
) u_audio_receive(    
    .rst_n          (rst_n),            // 复位信号
    
    .aud_bclk       (aud_bclk),         // es8388位时钟
    .aud_lrc        (aud_lrc),          // 对齐信号
    .aud_adcdat     (aud_adcdat),       // 音频输入
        
    .adc_data       (adc_data_raw),         // FPGA接收的数据
    .rx_done        (rx_done_raw)           // FPGA接收数据完成
);

//例化 FIR 滤波器
fir_filter #(
    .DATA_WIDTH(WL),                
    .COEFF_WIDTH(16)
) u_fir_filter (
    .clk              (aud_bclk),         // 使用 aud_bclk
    .rst_n            (rst_n),
    .data_in          (adc_data_raw[WL-1:0]), // 输入原始数据
    .data_in_valid    (rx_done_raw),      // 使用原始 rx_done
    .channel          (aud_lrc_d0),       // 输入当前声道
    .data_out         (filtered_data_out),
    .data_out_valid   (filtered_data_valid),
    .data_out_channel (filtered_channel)    // 
);

//例化es8388音频发送模块
audio_send #(
    .WL             (WL)
) u_audio_send(
    .rst_n          (rst_n),            // 复位信号
        
    .aud_bclk       (aud_bclk),         // es83888位时钟
    .aud_lrc        (aud_lrc),          // 对齐信号
    .aud_dacdat     (aud_dacdat),       // 音频数据输出
        
    .dac_data       (dac_data_final),         // 预输出的音频数据
    .tx_done        (tx_done)           // 发送完成信号
);

sound_localization #(
    .DATA_WIDTH(WL),       
    .LEVEL_BITS(18)        
) u_sound_localization (
    .clk              (clk),      
    .rst_n            (rst_n),
    .data_in_left     (vc_left_data_in_reg[WL-1:0]),  
    .data_in_right    (vc_right_data_in_reg[WL-1:0]), 
    .data_in_valid    (vc_stereo_valid_in),      
    .led_out          (led_out),
    .localization_en  (localization_en)            
);

endmodule 