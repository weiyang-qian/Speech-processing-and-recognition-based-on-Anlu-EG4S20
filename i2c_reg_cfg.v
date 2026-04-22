module i2c_reg_cfg (
    input                clk      ,     // i2c_reg_cfg驱动时钟（四倍于SCL的频率）
    input                rst_n    ,     // 复位信号
    input                i2c_done ,     // I2C一次操作完成反馈信号
  //  input        [1:0]   volume   ,     // 耳机音量选择输入
    output  reg          i2c_exec ,     // I2C触发执行信号
    output  reg          cfg_done ,     // es8388配置完成
    output  reg  [15:0]  i2c_data       // 寄存器数据(地址+数据)
);

//parameter define
parameter  WL           = 6'd32;        // word length音频字长参数设置

//parameter define
localparam REG_NUM      = 5'd24;        // 总共需要配置的寄存器个数

//reg define
reg    [1:0]  wl            ;           // word length音频字长参数定义
reg    [7:0]  start_init_cnt;           // 初始化延时计数器
reg    [4:0]  init_reg_cnt  ;           // 寄存器配置个数计数器
//reg    [5:0]  phone_volume  ;           // 耳机输出音量大小参数（0~63）,默认40

//音量设置
//always @ (volume) begin
//   case(volume)
//        2'b00 : phone_volume = 8'h02;    //-42dB
//        2'b01 : phone_volume = 8'h1A;    //-6dB
//        2'b10 : phone_volume = 8'h1E;    //0dB
//        default : phone_volume = 8'h1F;  //1.5dB
//    endcase
//end

//*****************************************************
//**                    main code
//*****************************************************

//音频字长（位数）参数设置
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        wl <= 2'b00;
    else begin
        case(WL)
            6'd16:  wl <= 2'b00; 
            6'd20:  wl <= 2'b01; 
            6'd24:  wl <= 2'b10; 
            6'd32:  wl <= 2'b11; 
            default: 
                    wl <= 2'd00;
        endcase
    end
end

//上电或复位后延时一段时间
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        start_init_cnt <= 8'd0;
    else if(start_init_cnt < 8'hff)
        start_init_cnt <= start_init_cnt + 1'b1;
end

//触发I2C操作
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        i2c_exec <= 1'b0;
    else if(init_reg_cnt == 5'd0 & start_init_cnt == 8'hfe)
        i2c_exec <= 1'b1;
    else if(i2c_done && init_reg_cnt < REG_NUM)
        i2c_exec <= 1'b1;
    else
        i2c_exec <= 1'b0;
end

//配置寄存器计数
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        init_reg_cnt <= 5'd0;
    else if(i2c_exec)
        init_reg_cnt <= init_reg_cnt + 1'b1;
end

//寄存器配置完成信号
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        cfg_done <= 1'b0;
    else if(i2c_done & (init_reg_cnt == REG_NUM) )
        cfg_done <= 1'b1;
end

//配置I2C器件内寄存器地址及其数据
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        i2c_data <= 16'b0;
    else begin
        case(init_reg_cnt)
            5'd0 : i2c_data <= {8'h00 ,8'h16};  // R0,ADC采样率=DAC采样率,使能VREF和VMID
            5'd1 : i2c_data <= {8'h01 ,8'h00};  // R1,打开所有电源
            5'd2 : i2c_data <= {8'h02 ,8'h00};  // R2,打开所有电源
            5'd3: i2c_data <=  {8'h03 ,8'h00};  // R3,打开ADC电源
            5'd4 : i2c_data <= {8'h04 ,8'h3c}; // R4,打开DAC电源
            5'd5 : i2c_data <= {8'h08 ,8'h80}; // R8,主模式，MCLK不分频，BCLK自动
            5'd6 : i2c_data <= {8'h09 ,8'h22}; // R9，麦克风增益6dB
            5'd7 : i2c_data <= {8'h0c,8'h00}; // R12, ADC设置为24bit I2S模式
            5'd8 : i2c_data <= {8'h0d,8'h02}; // R13,设置ADC采样率12.288/256 = 48KSPS
            5'd9 : i2c_data <= {8'h10,8'h0f}; // R16,设置左ADC数控音量衰减为0dB
            5'd10: i2c_data <= {8'h11,8'h0f};  // R17,设置右ADC数控音量衰减为0dB
            5'd11: i2c_data <= {8'h12,8'h38}; // R18,ALC和PGA增益范围设定
            5'd12: i2c_data <= {8'h17,8'h00}; // R23, DAC设置为24bit I2S模式
            5'd13: i2c_data <= {8'h18,8'h02}; // R24,设置DAC采样率12.288/256 = 48KSPS
            5'd14: i2c_data <= {8'h1a,8'h00 };  // R26,设置左DAC数控音量衰减为0dB
            5'd15: i2c_data <= {8'h1b,8'h00};  // R27,设置右DAC数控音量衰减为0dB
            5'd16: i2c_data <= {8'h27,8'hb8};  // R39,左DAC MIXER设置使能
            5'd17: i2c_data <= {8'h2a,8'hb8}; // R42,右DAC MIXER设置使能
            5'd18: i2c_data <= {8'h2b,8'h80};  // R43,ADC和DAC使用同一个LRC
            5'd19: i2c_data <= {8'h2e,8'h1A};  // LOUT1(耳机)输出音量控制：设置-6dB衰减
            5'd20: i2c_data <= {8'h2f,8'h1A};   // ROUT1(耳机)输出音量控制：设置-6dB衰减
            5'd21: i2c_data <= {8'h30,8'h1A}; //LOUT2(插座)输出音量控制：设置-6dB衰减
            5'd22: i2c_data <= {8'h31,8'h1A};  //ROUT2(插座)输出音量控制：设置-6dB衰减
            5'd23: i2c_data <= {8'h0a,8'h50}; //ADC输入选择，0x00为1通道输入（麦克风），0x50为2通道输入（Line-in）
            default : ;
        endcase
    end
    
end

endmodule 