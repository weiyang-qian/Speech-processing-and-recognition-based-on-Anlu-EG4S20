module voice_change
#(
    parameter DATA_WIDTH = 6'd32,
    parameter PITCH_FACTOR = 2 
)
(   
    input                       clk,
    input                       sck,       
    input                       rst_n,
    input                       data_valid, 
    input                       CHANGE_MODE, 
    output     [DATA_WIDTH - 1:0]  ldata_out,
    input      [DATA_WIDTH - 1:0]  ldata_in
);

    // ============================================================
    // 信号定义
    // ============================================================
    wire  [DATA_WIDTH-1:0] rd_data_ram1;
    wire  [DATA_WIDTH-1:0] rd_data_ram2;
    wire signed [DATA_WIDTH-1:0] ram_raw_out; 
    wire  [DATA_WIDTH-1:0] rd_data_fifo;
    
    reg   [9:0] cnt1;           
    reg   [9:0] rd_addr_ram;    
    reg         wr_en_ram1;
    wire        wr_en_ram2;
    
    reg         wr_en_ram1_reg1, wr_en_ram1_reg2;
    reg         pose_flag, nege_flag;

    reg         wr_en_fifo;     
    reg   [9:0] cnt2;           

    wire        wr_full_fifo;
    wire        rd_empty_fifo;
    wire        rst_n_low;      
    assign      rst_n_low = ~rst_n;

    // ============================================================
    // 参数设置
    // ============================================================
    reg [25:0] phase_acc;  
    wire [9:0] current_read_index;
    
    // 1.0倍 = 65536
    // 保持之前的激进参数以保证变调效果
    localparam STEP_PITCH_UP   = 26'd104857; // 1.6倍 (男变女)
    localparam STEP_PITCH_DOWN = 26'd42598;  // 0.65倍 (女变男)

    // 插值与平滑变量
    reg signed [31:0] last_ram_data; 
    wire signed [32:0] sum_temp;      
    wire signed [31:0] interpolated_data; 
    
    // 双重窗函数变量
    reg [8:0]  phase_fade_factor; 
    reg [8:0]  frame_fade_factor;
    
    wire signed [40:0] mult_temp_1; 
    wire signed [31:0] data_stage_1;
    wire signed [40:0] mult_temp_2; 
    wire [31:0] final_data;     

    assign current_read_index = phase_acc[25:16]; 

    // ============================================================
    // 逻辑实现
    // ============================================================

    assign wr_en_ram2 = rst_n ? ~wr_en_ram1 : 1'b0;
    assign ram_raw_out = $signed(wr_en_ram1 ? rd_data_ram2 : rd_data_ram1); 
    assign ldata_out = rd_data_fifo;

    // 1. RAM 写地址控制 (Input Side) - 采样率对齐
    always @(posedge sck or negedge rst_n) begin
        if(~rst_n) begin
            cnt1 <= 10'd0;
            wr_en_ram1 <= 1'b0;
        end 
        else if (data_valid) begin 
            if(cnt1 == 10'd1023) begin
                cnt1 <= 10'd0;
                wr_en_ram1 <= ~wr_en_ram1; 
            end else begin
                cnt1 <= cnt1 + 1'b1;
            end
        end
    end

    // 2. 边沿检测
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            wr_en_ram1_reg1 <= 1'b0;
            wr_en_ram1_reg2 <= 1'b0;
            pose_flag <= 1'b0;
            nege_flag <= 1'b0;
        end else begin
            wr_en_ram1_reg1 <= wr_en_ram1;
            wr_en_ram1_reg2 <= wr_en_ram1_reg1;
            pose_flag <= wr_en_ram1_reg1 & (~wr_en_ram1_reg2);
            nege_flag <= (~wr_en_ram1_reg1) & (wr_en_ram1_reg2);
        end
    end

    // 3. 相位累加器
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            rd_addr_ram <= 10'd0;
            phase_acc   <= 26'd0;
        end
        else if (pose_flag | nege_flag) begin
            rd_addr_ram <= 10'd0;
            phase_acc   <= 26'd0;
        end
        else begin
            if (CHANGE_MODE == 1'b0) phase_acc <= phase_acc + STEP_PITCH_UP;
            else                     phase_acc <= phase_acc + STEP_PITCH_DOWN;
            rd_addr_ram <= current_read_index; 
        end
    end 

    // 4. 插值
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) last_ram_data <= 32'd0;
        else       last_ram_data <= ram_raw_out; 
    end
    assign sum_temp = {ram_raw_out[31], ram_raw_out} + {last_ram_data[31], last_ram_data};
    assign interpolated_data = sum_temp[32:1];

    // ============================================================
    // [关键修正] 窗函数参数调整：收窄窗口以消除“哒哒”声
    // ============================================================

    // 5.1 第一层：相位窗 (Phase Window) - 消除循环金属音
    // 缩小范围至 128 (0~127 淡入, 896~1023 淡出)
    // 之前是256，太宽了导致声音糊
    always @(*) begin
        if (current_read_index < 10'd128) 
            // 淡入: index * 2
            phase_fade_factor = {current_read_index[6:0], 1'b0}; 
        else if (current_read_index > 10'd895) 
            // 淡出: (1023-index) * 2
            phase_fade_factor = {~current_read_index[6:0], 1'b0}; 
        else 
            phase_fade_factor = 9'd256; 
    end

    // 5.2 第二层：帧窗 (Frame Window) - 消除鼓点与哒哒声
    // 缩小范围至 32 (0~31 淡入, 992~1023 淡出)
    // 之前是128，导致明显的音量塌陷(哒哒声)。32点足够消除爆音且不可闻。
    always @(*) begin
        if (cnt2 < 10'd32) 
            // 淡入: cnt2 * 8
            frame_fade_factor = {cnt2[4:0], 3'b0}; 
        else if (cnt2 > 10'd991) 
            // 淡出: (1023-cnt2) * 8
            frame_fade_factor = {~cnt2[4:0], 3'b0};
        else 
            frame_fade_factor = 9'd256; 
    end

    // 5.3 级联应用
    assign mult_temp_1 = interpolated_data * $signed({1'b0, phase_fade_factor});
    assign data_stage_1 = mult_temp_1[39:8]; 

    assign mult_temp_2 = data_stage_1 * $signed({1'b0, frame_fade_factor});
    assign final_data = mult_temp_2[39:8];   

    // ============================================================

    // 6. FIFO 写逻辑
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) wr_en_fifo <= 1'b0;
        else if (pose_flag | nege_flag) wr_en_fifo <= 1'b1;
        else if (cnt2 == 10'd1023) wr_en_fifo <= 1'b0;
    end

    // 7. FIFO 写入计数器
    always @(posedge clk or negedge rst_n) begin
        if(~rst_n) cnt2 <= 10'd0;
        else if(wr_en_fifo == 1'b0) cnt2 <= 10'd0;
        else cnt2 <= cnt2 + 1'b1;
    end

    // 实例化
    voice_change_ram voice_change_ram_inst1 (
        .clka(sck), .wea(wr_en_ram1 & data_valid), .addra(cnt1), .dia(ldata_in), .cea(1'b1), .rsta(1'b0),
        .clkb(clk), .addrb(rd_addr_ram), .dob(rd_data_ram1), .ceb(1'b1), .oceb(1'b1), .web(1'b0), .dib(32'b0), .rstb(1'b0)
    );

    voice_change_ram voice_change_ram_inst2 (
        .clka(sck), .wea(wr_en_ram2 & data_valid), .addra(cnt1), .dia(ldata_in), .cea(1'b1), .rsta(1'b0),
        .clkb(clk), .addrb(rd_addr_ram), .dob(rd_data_ram2), .ceb(1'b1), .oceb(1'b1), .web(1'b0), .dib(32'b0), .rstb(1'b0)
    );

    voice_change_fifo the_instance_name (
        .clkw(clk), .rst(rst_n_low), .we(wr_en_fifo & ~wr_full_fifo), 
        
        .di(final_data), 
        
        .full_flag(wr_full_fifo), .clkr(sck), .re(rst_n & ~rd_empty_fifo & data_valid), 
        .do(rd_data_fifo), .empty_flag(rd_empty_fifo)
    );

endmodule