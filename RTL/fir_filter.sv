module fir_filter #(
    parameter DATA_WIDTH = 24,
    parameter COEFF_WIDTH = 16
)(
    input                       clk,
    input                       rst_n,
    input      [DATA_WIDTH-1:0] data_in,
    input                       data_in_valid,
    input                       channel,           // 声道选择，0=左声道，1=右声道
    output reg [DATA_WIDTH-1:0] data_out,
    output reg                  data_out_valid,
    output reg                  data_out_channel   // 输出声道指示
);

localparam TAPS = 28;
localparam VOLUME_SHIFT = 0; //移位控制音量大小
localparam [COEFF_WIDTH-1:0] coeffs [0:TAPS-1] = '{
    //抽头系数
    16'h007C, 16'h019B, 16'h01D6, 16'h01E3, 16'h00AD, 16'hFEA0, 16'hFC52, 16'hFB11,
    16'hFC24, 16'h004F, 16'h0747, 16'h0F9E, 16'h171B, 16'h1B8A, 16'h1B8A, 16'h171B,
    16'h0F9E, 16'h0747, 16'h004F, 16'hFC24, 16'hFB11, 16'hFC52, 16'hFEA0, 16'h00AD,
    16'h01E3, 16'h01D6, 16'h019B, 16'h007C
};

// 寄存器定义 - 为左右声道分别维护延迟线
reg [DATA_WIDTH-1:0] delay_line_left [0:TAPS-1];   // 左声道延迟线
reg [DATA_WIDTH-1:0] delay_line_right [0:TAPS-1];  // 右声道延迟线

// 修改：将full_product改为64位
reg signed [31:0] accumulator_high;
reg signed [31:0] accumulator_low;
reg signed [31:0] product_high [0:TAPS-1];
reg signed [31:0] product_low [0:TAPS-1];
reg signed [63:0] full_product;  // 改为64位
reg signed [63:0] temp_accumulator;
reg signed [63:0] shifted_result;
reg channel_delayed;

// 修改：增加饱和处理相关参数
localparam ACCUMULATOR_WIDTH = 64;
localparam OUTPUT_MAX_POS = (2**(DATA_WIDTH-1))-1;  // 24位有符号数最大值: 8388607
localparam OUTPUT_MAX_NEG = -(2**(DATA_WIDTH-1));   // 24位有符号数最小值: -8388608

integer i;

// 修改：增加饱和处理函数
function signed [DATA_WIDTH-1:0] saturate;
    input signed [ACCUMULATOR_WIDTH-1:0] value;
    begin
        if (value > OUTPUT_MAX_POS) begin
            saturate = OUTPUT_MAX_POS;
        end else if (value < OUTPUT_MAX_NEG) begin
            saturate = OUTPUT_MAX_NEG;
        end else begin
            saturate = value[DATA_WIDTH-1:0];
        end
    end
endfunction

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
        
        // 第一阶段：计算每个抽头的乘积
        for (i = 0; i < TAPS; i = i + 1) begin
            // 根据声道选择对应的延迟线数据
            if (channel == 1'b0) begin
                full_product = $signed({{8{delay_line_left[i][DATA_WIDTH-1]}}, delay_line_left[i]}) * 
                              $signed({{8{coeffs[i][COEFF_WIDTH-1]}}, coeffs[i]});
            end
            else begin
                full_product = $signed({{8{delay_line_right[i][DATA_WIDTH-1]}}, delay_line_right[i]}) * 
                              $signed({{8{coeffs[i][COEFF_WIDTH-1]}}, coeffs[i]});
            end
            
            // 修改：将64位乘积拆分成高32位和低32位
            product_high[i] <= full_product[63:32];
            product_low[i] <= full_product[31:0];
        end
        
        // 第二阶段：累加所有乘积
        temp_accumulator = 0;
        for (i = 0; i < TAPS; i = i + 1) begin
            temp_accumulator = temp_accumulator + {product_high[i], product_low[i]};
        end
        
        accumulator_high <= temp_accumulator[63:32];
        accumulator_low <= temp_accumulator[31:0];
        
        // 系数是Q1.15格式，右移15位
        shifted_result = temp_accumulator >>> (COEFF_WIDTH-1); // 右移15位
        
        shifted_result = shifted_result >>> VOLUME_SHIFT;
        
        // 修改：使用饱和处理代替直接截断
        data_out <= saturate(shifted_result);
        
        data_out_valid <= 1'b1;
        data_out_channel <= channel_delayed;
    end
    else begin
        data_out_valid <= 1'b0;
    end
end

endmodule