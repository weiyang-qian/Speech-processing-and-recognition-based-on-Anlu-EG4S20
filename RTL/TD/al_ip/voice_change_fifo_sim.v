// Verilog netlist created by Tang Dynasty v5.6.71036
// Mon Nov  3 21:50:03 2025

`timescale 1ns / 1ps
module voice_change_fifo  // voice_change_fifo.v(14)
  (
  clkr,
  clkw,
  di,
  re,
  rst,
  we,
  do,
  empty_flag,
  full_flag
  );

  input clkr;  // voice_change_fifo.v(25)
  input clkw;  // voice_change_fifo.v(24)
  input [31:0] di;  // voice_change_fifo.v(23)
  input re;  // voice_change_fifo.v(25)
  input rst;  // voice_change_fifo.v(22)
  input we;  // voice_change_fifo.v(24)
  output [31:0] do;  // voice_change_fifo.v(27)
  output empty_flag;  // voice_change_fifo.v(28)
  output full_flag;  // voice_change_fifo.v(29)

  wire empty_flag_syn_2;  // voice_change_fifo.v(28)
  wire full_flag_syn_2;  // voice_change_fifo.v(29)

  EG_PHY_CONFIG #(
    .DONE_PERSISTN("ENABLE"),
    .INIT_PERSISTN("ENABLE"),
    .JTAG_PERSISTN("DISABLE"),
    .PROGRAMN_PERSISTN("DISABLE"))
    config_inst ();
  not empty_flag_syn_1 (empty_flag_syn_2, empty_flag);  // voice_change_fifo.v(28)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000000110000),
    .AEP1(32'b00000000000000000000000000111000),
    .AF(32'b00000000000000000001111111010000),
    .AFM1(32'b00000000000000000001111111001000),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("9"),
    .DATA_WIDTH_B("9"),
    .E(32'b00000000000000000000000000000000),
    .EP1(32'b00000000000000000000000000001000),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111000),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_5 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia(di[8:0]),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .dob(do[8:0]),
    .empty_flag(empty_flag),
    .full_flag(full_flag));  // voice_change_fifo.v(41)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000000110000),
    .AEP1(32'b00000000000000000000000000111000),
    .AF(32'b00000000000000000001111111010000),
    .AFM1(32'b00000000000000000001111111001000),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("9"),
    .DATA_WIDTH_B("9"),
    .E(32'b00000000000000000000000000000000),
    .EP1(32'b00000000000000000000000000001000),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111000),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_6 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia(di[17:9]),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .dob(do[17:9]));  // voice_change_fifo.v(41)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000000110000),
    .AEP1(32'b00000000000000000000000000111000),
    .AF(32'b00000000000000000001111111010000),
    .AFM1(32'b00000000000000000001111111001000),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("9"),
    .DATA_WIDTH_B("9"),
    .E(32'b00000000000000000000000000000000),
    .EP1(32'b00000000000000000000000000001000),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111000),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_7 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia(di[26:18]),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .dob(do[26:18]));  // voice_change_fifo.v(41)
  EG_PHY_FIFO #(
    .AE(32'b00000000000000000000000000110000),
    .AEP1(32'b00000000000000000000000000111000),
    .AF(32'b00000000000000000001111111010000),
    .AFM1(32'b00000000000000000001111111001000),
    .ASYNC_RESET_RELEASE("SYNC"),
    .DATA_WIDTH_A("9"),
    .DATA_WIDTH_B("9"),
    .E(32'b00000000000000000000000000000000),
    .EP1(32'b00000000000000000000000000001000),
    .F(32'b00000000000000000010000000000000),
    .FM1(32'b00000000000000000001111111111000),
    .GSR("DISABLE"),
    .MODE("FIFO8K"),
    .REGMODE_A("NOREG"),
    .REGMODE_B("NOREG"),
    .RESETMODE("ASYNC"))
    fifo_inst_syn_8 (
    .clkr(clkr),
    .clkw(clkw),
    .csr({2'b11,empty_flag_syn_2}),
    .csw({2'b11,full_flag_syn_2}),
    .dia({open_n111,open_n112,open_n113,open_n114,di[31:27]}),
    .orea(1'b0),
    .oreb(1'b0),
    .re(re),
    .rprst(rst),
    .rst(rst),
    .we(we),
    .dob({open_n135,open_n136,open_n137,open_n138,do[31:27]}));  // voice_change_fifo.v(41)
  not full_flag_syn_1 (full_flag_syn_2, full_flag);  // voice_change_fifo.v(29)

endmodule 

