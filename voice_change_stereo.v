module voice_change_stereo#(parameter P_DATA_WIDTH = 6'd32,parameter P_PITCH_FACTOR = 3)
(
    input                       clk,
    input                       sck,
    input                       rst_n,
    input                       CHANGE_MODE, 
    input                       data_valid, // [新增]
    input      [P_DATA_WIDTH-1:0] data_in_left,
    input      [P_DATA_WIDTH-1:0] data_in_right,
    output     [P_DATA_WIDTH-1:0] data_out_left,
    output     [P_DATA_WIDTH-1:0] data_out_right
);
    // 左声道
    voice_change #(
        .DATA_WIDTH(P_DATA_WIDTH),.PITCH_FACTOR(P_PITCH_FACTOR)
    ) vc_left (
        .clk(clk),
        .sck(sck),
        .rst_n(rst_n),
        .data_valid(data_valid), // [连接]
        .CHANGE_MODE(CHANGE_MODE),
        .ldata_in(data_in_left),
        .ldata_out(data_out_left)
    );
    // 右声道
    voice_change #(
        .DATA_WIDTH(P_DATA_WIDTH),.PITCH_FACTOR(P_PITCH_FACTOR)
    ) vc_right (
        .clk(clk),
        .sck(sck),
        .rst_n(rst_n),
        .data_valid(data_valid), // [连接]
        .CHANGE_MODE(CHANGE_MODE),
        .ldata_in(data_in_right),
        .ldata_out(data_out_right)
    );
endmodule