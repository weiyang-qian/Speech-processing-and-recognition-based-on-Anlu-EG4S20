// SD卡顶层控制模块 (已修改为 8-bit 接口)
// 功能：实现SD卡在SPI模式下的初始化、扇区读写操作
// 特点：支持低速和高速两种SPI时钟模式，提供 8 位数据接口
module sd_card_top
#(
    parameter  SPI_LOW_SPEED_DIV = 248,         // SD卡低速模式分频参数
    parameter  SPI_HIGH_SPEED_DIV = 0           // SD卡高速模式分频参数
)
(
    // 系统信号
    input            clk,                       // 系统时钟输入
    input            rst,                       // 系统复位信号，高电平有效
    
    // SD卡SPI物理接口
    output           SD_nCS,                    // SD卡片选信号（SPI模式），低电平有效
    output           SD_DCLK,                   // SD卡时钟信号
    output           SD_MOSI,                   // SD卡主出从入数据线（控制器输出）
    input            SD_MISO,                   // SD卡主入从出数据线（控制器输入）
    
    // SD卡状态指示
    output           sd_init_done,              // SD卡初始化完成标志
    
    // 扇区读取接口 (*** 修改：变为 8-bit ***)
    input            sd_sec_read,               // 扇区读取请求信号
    input[31:0]      sd_sec_read_addr,          // 扇区读取地址（32位LBA地址）
    output[7:0]      sd_sec_read_data,          // 扇区读取数据输出 (8-bit)
    output           sd_sec_read_data_valid,    // 扇区读取数据有效标志
    output           sd_sec_read_end,           // 扇区读取结束标志
    
    // 扇区写入接口 (*** 修改：变为 8-bit ***)
    input            sd_sec_write,              // 扇区写入请求信号
    input[31:0]      sd_sec_write_addr,         // 扇区写入地址（32位LBA地址）
    input[7:0]       sd_sec_write_data,         // 扇区写入数据输入 (8-bit)
    output           sd_sec_write_data_req,     // 扇区写入数据请求信号
    output           sd_sec_write_end           // 扇区写入结束标志
);

// 内部信号定义 (与原版一致)
wire[15:0]           spi_clk_div;           // SPI模块时钟分频参数
wire                 cmd_req;               // SD卡命令发送请求
wire                 cmd_req_ack;           // SD卡命令请求应答
wire                 cmd_req_error;         // SD卡命令请求错误标志
wire[47:0]           cmd;                   // SD卡命令
wire[7:0]            cmd_r1;                // SD卡期望响应类型
wire[15:0]           cmd_data_len;          // SD卡命令数据长度
wire                 block_read_req;        // SD卡块数据读取请求
wire                 block_read_valid;      // SD卡块数据读取有效标志
wire[7:0]            block_read_data;       // SD卡块数据读取数据（8位）
wire                 block_read_req_ack;    // SD卡块数据读取请求应答
wire                 block_write_req;       // SD卡块数据写入请求
wire[7:0]            block_write_data;      // SD卡块数据写入数据（8位）
wire                 block_write_data_rd;   // SD卡块数据写入数据读取使能
wire                 block_write_req_ack;   // SD卡块数据写入请求应答
wire                 nCS_ctrl;              // SPI模块片选控制信号
wire                 spi_wr_req;            // SPI模块数据发送请求
wire                 spi_wr_ack;            // SPI模块数据发送请求应答
wire[7:0]            spi_data_in;           // SPI模块发送数据
wire[7:0]            spi_data_out;          // SPI模块接收数据
wire[15:0]           clk_div;               // SPI时钟分频系数

// *** 移除：所有 32-bit <-> 8-bit 数据宽度转换逻辑 ***
//

// =============================================================================
// 输出信号分配 (*** 修改：改为 8-bit 直通 ***)
// =============================================================================

// 读取相关输出 (直接连接内部 8-bit 信号)
assign sd_sec_read_data       = block_read_data;        //
assign sd_sec_read_data_valid = block_read_valid;       //

// 写入相关输出 (直接连接内部 8-bit 信号)
assign sd_sec_write_data_req  = block_write_data_rd;    //
assign block_write_data       = sd_sec_write_data;      //

// =============================================================================
// 模块实例化 (与原版一致)
// =============================================================================

// SD卡扇区读写控制模块实例化
sd_card_sec_read_write
#(
    .SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
    .SPI_HIGH_SPEED_DIV(SPI_HIGH_SPEED_DIV)
)
sd_card_sec_read_write_m0(
    .clk                            (clk                    ),
    .rst                            (rst                    ),
    .sd_init_done                   (sd_init_done           ),
    .sd_sec_read                    (sd_sec_read            ),
    .sd_sec_read_addr               (sd_sec_read_addr       ),
    .sd_sec_read_data               ( ),                      // (内部 8-bit 接口在下面)
    .sd_sec_read_data_valid         ( ),
    .sd_sec_read_end                (sd_sec_read_end        ),
    .sd_sec_write                   (sd_sec_write           ),
    .sd_sec_write_addr              (sd_sec_write_addr      ),
    .sd_sec_write_data              ( ),                      // (内部 8-bit 接口在下面)
    .sd_sec_write_data_req          ( ),
    .sd_sec_write_end               (sd_sec_write_end       ),
    .spi_clk_div                    (spi_clk_div            ),
    .cmd_req                        (cmd_req                ),
    .cmd_req_ack                    (cmd_req_ack            ),
    .cmd_req_error                  (cmd_req_error          ),
    .cmd                            (cmd                    ),
    .cmd_r1                         (cmd_r1                 ),
    .cmd_data_len                   (cmd_data_len           ),
    .block_read_req                 (block_read_req         ),
    .block_read_valid               (block_read_valid       ),
    .block_read_data                (block_read_data        ),
    .block_read_req_ack             (block_read_req_ack     ),
    .block_write_req                (block_write_req        ),
    .block_write_data               (block_write_data       ),
    .block_write_data_rd            (block_write_data_rd    ),
    .block_write_req_ack            (block_write_req_ack    )
);

// SD卡命令处理模块实例化
sd_card_cmd sd_card_cmd_m0(
    .sys_clk                        (clk                    ),
    .rst                            (rst                    ),
    .spi_clk_div                    (spi_clk_div            ),
    .cmd_req                        (cmd_req                ),
    .cmd_req_ack                    (cmd_req_ack            ),
    .cmd_req_error                  (cmd_req_error          ),
    .cmd                            (cmd                    ),
    .cmd_r1                         (cmd_r1                 ),
    .cmd_data_len                   (cmd_data_len           ),
    .block_read_req                 (block_read_req         ),
    .block_read_req_ack             (block_read_req_ack     ),
    .block_read_data                (block_read_data        ),
    .block_read_valid               (block_read_valid       ),
    .block_write_req                (block_write_req        ),
    .block_write_data               (block_write_data       ),
    .block_write_data_rd            (block_write_data_rd    ),
    .block_write_req_ack            (block_write_req_ack    ),
    .nCS_ctrl                       (nCS_ctrl               ),
    .clk_div                        (clk_div                ),
    .spi_wr_req                     (spi_wr_req             ),
    .spi_wr_ack                     (spi_wr_ack             ),
    .spi_data_in                    (spi_data_in            ),
    .spi_data_out                   (spi_data_out           )
);

// SPI主控制器模块实例化
spi_master spi_master_m0(
    .sys_clk                        (clk                    ),
    .rst                            (rst                    ),
    .nCS                            (SD_nCS                 ),
    .DCLK                           (SD_DCLK                ),
    .MOSI                           (SD_MOSI                ),
    .MISO                           (SD_MISO                ),
    .clk_div                        (clk_div                ),
    .CPOL                           (1'b1                   ),
    .CPHA                           (1'b1                   ),
    .nCS_ctrl                       (nCS_ctrl               ),
    .wr_req                         (spi_wr_req             ),
    .wr_ack                         (spi_wr_ack             ),
    .data_in                        (spi_data_in            ),
    .data_out                       (spi_data_out           )
);

endmodule