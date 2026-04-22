module audio_speak(
    input           sys_clk   ,               // 系统时钟(50MHz)
    input           sys_rst_n ,               // 系统复位
    
	// input   [1:0]  volume,                  //音量配置输入
	input           filter_en ,               // 新增：滤波器使能信号
    input           voice_change_en,          // 新增：变调使能
    input           change_mode,
    input           localization_en,        
    //es8388 audio interface (master mode)
    input           aud_bclk  ,               // es8388位时钟
    input           aud_lrc   ,               // 对齐信号
    input           aud_adcdat,               // 音频输入
    output          aud_mclk  ,               // es8388的主时钟
    output          aud_dacdat,               // 音频输出
    output          SD_nCS,                   // SD卡片选信号
    output          SD_DCLK,                  // SD卡时钟信号
    output          SD_MOSI,                  // SD卡主出从入数据线
    input           SD_MISO,                  // SD卡主入从出数据线
    
    // 用户控制接口
    input           record_en,                // 录音使能
    input           play_en,                  // 播放使能
    //es8388 control interface
    output          aud_scl   ,               // es8388的SCL信号
    inout           aud_sda ,                  // es8388的SDA信号
    output [8:0]    led
);


//wire define
wire [31:0] adc_data;                         // FPGA采集的音频数据                                 
wire rst_n,locked;
wire [31:0] dac_data;                         // 发送到DAC的音频数据
wire rx_done_signal;                          // 接收完成信号
wire        sd_init_done;                     // 新增：明确声明 sd_init_done 信号
wire [7:0]  led_from_ctrl;                    // 新增：用于接收8位声源定位LED
// SD卡控制信号
wire sd_sec_read, sd_sec_write;
wire [31:0] sd_sec_read_addr, sd_sec_write_addr;
wire [31:0] sd_sec_read_data, sd_sec_write_data;
wire sd_sec_read_data_valid, sd_sec_write_data_req;
wire sd_sec_read_end, sd_sec_write_end;

// 音频数据选择
reg [31:0] dac_data_sel;
wire [31:0] sd_playback_data;                // 从SD卡读取的播放数据
//*****************************************************
//**                    main code
//*****************************************************
assign led = {sd_init_done, led_from_ctrl};
reg	[7:0]	rst_cnt=0;	

always @(posedge sys_clk)
begin
	if (rst_cnt[7])
		rst_cnt <=  rst_cnt;
	else
		rst_cnt <= rst_cnt+1'b1;
end			  	

// 音频数据选择逻辑
always @(posedge sys_clk or negedge locked) begin
    if(!locked)
        dac_data_sel <= 32'd0;
    else if(play_en)
        dac_data_sel <= sd_playback_data;     // 播放模式：使用SD卡数据
    else
        dac_data_sel <= adc_data;             // 监听模式：直通输入音频
end


//例化PLL，生成es8388主时钟
  clk_wiz_0 u_pll_clk
   (
  
    .refclk(sys_clk),// input clk_50M
    .reset(!rst_cnt[7]),// input resetn
    .stdby(1'b0),
    .extlock(locked),// output locked
    .clk0_out(chipwatcherclk),
    .clk1_out(aud_mclk) // output clk_12M，12.288MHz
   );      



//例化es8388控制模块
es8388_ctrl u_es8388_ctrl(
    .clk                (sys_clk    ),        // 时钟信号
    .rst_n              (locked      ),        // 复位信号
	.filter_en          (filter_en  ),        // 新增：连接滤波器使能
    .voice_change_en    (voice_change_en),    // 新增
    .change_mode        (change_mode),
    .localization_en    (localization_en),
    .aud_bclk           (aud_bclk   ),        // es8388位时钟
    .aud_lrc            (aud_lrc    ),        // 对齐信号
    .aud_adcdat         (aud_adcdat ),        // 音频输入
    .aud_dacdat         (aud_dacdat ),        // 音频输出
    
    .aud_scl            (aud_scl    ),        // es8388的SCL信号
    .aud_sda            (aud_sda    ),        // es8388的SDA信号
    
	// .volume             (volume),              //音量配置输入
	 
    .adc_data           (adc_data   ),        // 输入的音频数据
    .dac_data           (dac_data_sel   ),        // 输出的音频数据
    .rx_done            (rx_done_signal),                   // 1次接收完成
    .tx_done            ()   ,                 // 1次发送完成
    .led_out            (led_from_ctrl)                 //
);

// 实例化SD卡音频存储控制模块
sd_audio_ctrl u_sd_audio_ctrl(
    .clk                (sys_clk    ),
    .rst_n              (locked     ),
    
    // 音频接口
    .audio_data_in      (adc_data   ),        // 来自ADC的音频数据
    .audio_data_out     (sd_playback_data),   // 发送到DAC的音频数据
    .audio_data_valid   (rx_done_signal),     // 使用接收完成信号作为数据有效
    .aud_lrc            (aud_lrc),            //声道指示信号
    
    // SD卡接口
    .sd_init_done       (sd_init_done),
    .sd_sec_read        (sd_sec_read),
    .sd_sec_read_addr   (sd_sec_read_addr),
    .sd_sec_read_data   (sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end    (sd_sec_read_end),
    .sd_sec_write       (sd_sec_write),
    .sd_sec_write_addr  (sd_sec_write_addr),
    .sd_sec_write_data  (sd_sec_write_data),
    .sd_sec_write_data_req(sd_sec_write_data_req),
    .sd_sec_write_end   (sd_sec_write_end),
    
    // 控制信号
    .record_en          (record_en),
    .play_en            (play_en)
);

// 实例化SD卡顶层模块
sd_card_top u_sd_card_top(
    .clk                (sys_clk    ),
    .rst                (!locked    ),
    
    // SD卡SPI物理接口
    .SD_nCS             (SD_nCS     ),
    .SD_DCLK            (SD_DCLK    ),
    .SD_MOSI            (SD_MOSI    ),
    .SD_MISO            (SD_MISO    ),
    
    // SD卡状态指示
    .sd_init_done       (sd_init_done),
    
    // 扇区读取接口
    .sd_sec_read        (sd_sec_read),
    .sd_sec_read_addr   (sd_sec_read_addr),
    .sd_sec_read_data   (sd_sec_read_data),
    .sd_sec_read_data_valid(sd_sec_read_data_valid),
    .sd_sec_read_end    (sd_sec_read_end),
    
    // 扇区写入接口
    .sd_sec_write       (sd_sec_write),
    .sd_sec_write_addr  (sd_sec_write_addr),
    .sd_sec_write_data  (sd_sec_write_data),
    .sd_sec_write_data_req(sd_sec_write_data_req),
    .sd_sec_write_end   (sd_sec_write_end)
);


endmodule 