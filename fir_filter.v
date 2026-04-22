//*****************************************************
//** fir_filter_stereo - 双声道FIR滤波器
//** 功能: 支持左右声道的FIR滤波器
//*****************************************************
module fir_filter #(
    parameter DATA_WIDTH = 24,
    parameter COEFF_WIDTH = 16
)(
    input                       clk,
    input                       rst_n,
    input      [DATA_WIDTH-1:0] data_in,
    input                       data_in_valid,
    input                       channel,           // 新增：声道选择，0=左声道，1=右声道
    output reg [DATA_WIDTH-1:0] data_out,
    output reg                  data_out_valid,
    output reg                  data_out_channel   // 新增：输出声道指示
);

// 使用少量抽头测试（51抽头低通滤波器）
localparam TAPS = 51;
localparam [COEFF_WIDTH-1:0] coeffs [0:TAPS-1] = '{
    16'hFE29, 16'hFE55, 16'hFDB0, 16'hFCFC, 16'hFC3E, 16'hFB7F, 16'hFAC7, 16'hFA20, 
16'hF993, 16'hF92C, 16'hF8F6, 16'hF8FF, 16'hF953, 16'hF9FF, 16'hFB0C, 16'hFC7D, 
16'hFE52, 16'h007E, 16'h02ED, 16'h0582, 16'h0817, 16'h0A85, 16'h0CA0, 16'h0E41, 
16'h0F49, 16'h0FA4, 16'h0F49, 16'h0E41, 16'h0CA0, 16'h0A85, 16'h0817, 16'h0582, 
16'h02ED, 16'h007E, 16'hFE52, 16'hFC7D, 16'hFB0C, 16'hF9FF, 16'hF953, 16'hF8FF, 
16'hF8F6, 16'hF92C, 16'hF993, 16'hFA20, 16'hFAC7, 16'hFB7F, 16'hFC3E, 16'hFCFC, 
16'hFDB0, 16'hFE55, 16'hFE29
};

// 寄存器定义 - 为左右声道分别维护延迟线
reg [DATA_WIDTH-1:0] delay_line_left [0:TAPS-1];   // 左声道延迟线
reg [DATA_WIDTH-1:0] delay_line_right [0:TAPS-1];  // 右声道延迟线

// 使用两个32位寄存器代替一个46位累加器
reg signed [31:0] accumulator_high; // 高32位
reg signed [31:0] accumulator_low;  // 低32位

// 中间乘积寄存器
reg signed [31:0] product_high [0:TAPS-1];
reg signed [31:0] product_low [0:TAPS-1];

// 临时变量声明在always块外部
reg signed [55:0] full_product; // 56位完整乘积
reg signed [63:0] temp_accumulator; // 64位临时累加器
reg signed [63:0] shifted_result;

// 声道选择寄存器
reg channel_delayed;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 初始化左右声道延迟线
        for (i = 0; i < TAPS; i = i + 1) begin
            delay_line_left[i] <= {DATA_WIDTH{1'b0}};
            delay_line_right[i] <= {DATA_WIDTH{1'b0}};
            product_high[i] <= 0;
            product_low[i] <= 0;
        end
        accumulator_high <= 0;
        accumulator_low <= 0;
        data_out <= 0;
        data_out_valid <= 1'b0;
        data_out_channel <= 1'b0;
        channel_delayed <= 1'b0;
    end
    else if (data_in_valid) begin
        // 保存当前声道信息用于后续处理
        channel_delayed <= channel;
        
        // 根据声道选择更新对应的延迟线
        if (channel == 1'b0) begin // 左声道
            for (i = TAPS-1; i > 0; i = i - 1) begin
                delay_line_left[i] <= delay_line_left[i-1];
            end
            delay_line_left[0] <= data_in;
        end
        else begin // 右声道
            for (i = TAPS-1; i > 0; i = i - 1) begin
                delay_line_right[i] <= delay_line_right[i-1];
            end
            delay_line_right[0] <= data_in;
        end
        
        // 第一阶段：计算每个抽头的乘积，分成高低两部分
        for (i = 0; i < TAPS; i = i + 1) begin
            // 根据声道选择对应的延迟线数据
            if (channel == 1'b0) begin
                // 左声道处理
                full_product = $signed({{8{delay_line_left[i][DATA_WIDTH-1]}}, delay_line_left[i]}) * 
                              $signed({{8{coeffs[i][COEFF_WIDTH-1]}}, coeffs[i]});
            end
            else begin
                // 右声道处理
                full_product = $signed({{8{delay_line_right[i][DATA_WIDTH-1]}}, delay_line_right[i]}) * 
                              $signed({{8{coeffs[i][COEFF_WIDTH-1]}}, coeffs[i]});
            end
            
            // 将56位乘积分成两个32位部分
            product_high[i] <= full_product[55:24]; // 高32位
            product_low[i] <= full_product[23:0];   // 低32位，扩展到32位
        end
        
        // 第二阶段：累加所有乘积
        temp_accumulator = 0;
        
        for (i = 0; i < TAPS; i = i + 1) begin
            // 将高低部分组合成64位数进行累加
            temp_accumulator = temp_accumulator + 
                              {product_high[i], product_low[i]};
        end
        
        // 将64位累加结果存回两个32位寄存器
        accumulator_high <= temp_accumulator[63:32];
        accumulator_low <= temp_accumulator[31:0];
        
        // 输出处理 - Q格式转换
        // 系数是Q1.15格式，所以结果需要右移15位
        shifted_result = temp_accumulator >>> (COEFF_WIDTH+1); // 右移15位
        
        // 截取合适的24位输出
        data_out <= shifted_result[DATA_WIDTH+$clog2(TAPS)-1:$clog2(TAPS)];
        data_out_valid <= 1'b1;
        data_out_channel <= channel_delayed; // 输出对应的声道信息
    end
    else begin
        data_out_valid <= 1'b0;
    end
end

endmodule