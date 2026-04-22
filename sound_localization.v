`timescale 1ns / 1ps
//
// 模块: sound_localization.v
// 功能: 通过比较左右声道音量强度，判断声源方向并驱动LED。
//
module sound_localization
#(
    parameter DATA_WIDTH = 24,
    parameter LEVEL_BITS = 18,
    parameter SMOOTH_FACTOR = 6,
    parameter THRESHOLD_1 = 2000,
    parameter THRESHOLD_2 = 6000,
    parameter THRESHOLD_3 = 12000
)
(
    input                       clk,
    input                       rst_n,
    input                       localization_en,
    input      [DATA_WIDTH-1:0] data_in_left,
    input      [DATA_WIDTH-1:0] data_in_right,
    input                       data_in_valid,
    
    output reg [7:0]            led_out
);

    // 内部寄存器，用于存储平滑后的音量
    reg [LEVEL_BITS-1:0] left_intensity;
    reg [LEVEL_BITS-1:0] right_intensity;

    // 中间信号
    wire [LEVEL_BITS-1:0] abs_left;
    wire [LEVEL_BITS-1:0] abs_right;

    // **关键修正：将 diff 的声明移到模块顶层**
    // 将其声明为 wire，因为它的值可以用组合逻辑直接计算得出
    wire signed [LEVEL_BITS:0] diff;

    // 使用连续赋值计算绝对值
    assign abs_left  = (data_in_left[DATA_WIDTH-1]) ? -data_in_left[DATA_WIDTH-1:DATA_WIDTH-LEVEL_BITS] : data_in_left[DATA_WIDTH-1:DATA_WIDTH-LEVEL_BITS];
    assign abs_right = (data_in_right[DATA_WIDTH-1]) ? -data_in_right[DATA_WIDTH-1:DATA_WIDTH-LEVEL_BITS] : data_in_right[DATA_WIDTH-1:DATA_WIDTH-LEVEL_BITS];

    // **优化：使用组合逻辑直接计算强度差异**
    // 这是一个更简洁、高效的写法
    assign diff = left_intensity - right_intensity;


    // --- 音量计算 (漏电积分器) ---
    // 这部分是时序逻辑，保持不变
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            left_intensity <= 0;
            right_intensity <= 0;
        end else if (data_in_valid && localization_en) begin
            left_intensity  <= left_intensity - (left_intensity >> SMOOTH_FACTOR) + (abs_left >> SMOOTH_FACTOR);
            right_intensity <= right_intensity - (right_intensity >> SMOOTH_FACTOR) + (abs_right >> SMOOTH_FACTOR);
        end
    end

    // --- 映射到LED (时序逻辑) ---
    // **修正：这个 always 块现在只负责根据 diff 的值更新 led_out**
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_out <= 8'b10000000; // 复位时点亮中间的LED3
        end 
        else if (!localization_en) begin
            led_out <= 8'b10000000; // 禁用时，点亮 LED 7
        end else begin
            if (diff > THRESHOLD_3)      led_out <= 8'b00000001; // Far Left  (LED0)
            else if (diff > THRESHOLD_2) led_out <= 8'b00000010; // Mid Left  (LED1)
            else if (diff > THRESHOLD_1) led_out <= 8'b00000100; // Near Left (LED2)
            else if (diff < -THRESHOLD_3) led_out <= 8'b01000000; // Far Right (LED6)
            else if (diff < -THRESHOLD_2) led_out <= 8'b00100000; // Mid Right (LED5)
            else if (diff < -THRESHOLD_1) led_out <= 8'b00010000; // Near Right(LED4)
            else                         led_out <= 8'b00001000; // Center    (LED3)
        end
    end

endmodule