`timescale 1ns / 1ps

`include "defines.vh"

// ============================================================================
// EX/MEM 流水寄存器: EX阶段 -> MEM阶段
// ============================================================================
module EX_MEM_Reg (
    input  wire         clk,
    input  wire         rst,
    input  wire         stall,

    // ALU结果
    input  wire [31:0]  ex_alu_c,

    // 访存控制
    input  wire [ 2:0]  ex_ram_rop,
    input  wire [ 3:0]  ex_ram_wop,

    // 写回信号
    input  wire         ex_rf_we,
    input  wire [ 1:0]  ex_rf_wsel,
    input  wire [ 4:0]  ex_rf_wR,

    // store数据 & PC+4 & PC & ext (LUI用)
    input  wire [31:0]  ex_rf_rd2,
    input  wire [31:0]  ex_pc4,
    input  wire [31:0]  ex_pc,
    input  wire [31:0]  ex_ext,

    // --- MEM阶段输出 ---
    output reg  [31:0]  mem_alu_c,

    output reg  [ 2:0]  mem_ram_rop,
    output reg  [ 3:0]  mem_ram_wop,

    output reg          mem_rf_we,
    output reg  [ 1:0]  mem_rf_wsel,
    output reg  [ 4:0]  mem_rf_wR,

    output reg  [31:0]  mem_rf_rd2,
    output reg  [31:0]  mem_pc4,
    output reg  [31:0]  mem_pc,
    output reg  [31:0]  mem_ext
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_alu_c   <= 32'h0;

            mem_ram_rop <= `RAM_EXT_N;
            mem_ram_wop <= `RAM_WE_N;

            mem_rf_we   <= 1'b0;
            mem_rf_wsel <= `WB_ALU;
            mem_rf_wR   <= 5'h0;

            mem_rf_rd2  <= 32'h0;
            mem_pc4     <= 32'h0;
            mem_pc      <= 32'h0;
            mem_ext     <= 32'h0;
        end else if (stall) begin
            mem_alu_c   <= mem_alu_c;

            mem_ram_rop <= mem_ram_rop;
            mem_ram_wop <= mem_ram_wop;

            mem_rf_we   <= mem_rf_we;
            mem_rf_wsel <= mem_rf_wsel;
            mem_rf_wR   <= mem_rf_wR;

            mem_rf_rd2  <= mem_rf_rd2;
            mem_pc4     <= mem_pc4;
            mem_pc      <= mem_pc;
            mem_ext     <= mem_ext;
        end else begin
            mem_alu_c   <= ex_alu_c;

            mem_ram_rop <= ex_ram_rop;
            mem_ram_wop <= ex_ram_wop;

            mem_rf_we   <= ex_rf_we;
            mem_rf_wsel <= ex_rf_wsel;
            mem_rf_wR   <= ex_rf_wR;

            mem_rf_rd2  <= ex_rf_rd2;
            mem_pc4     <= ex_pc4;
            mem_pc      <= ex_pc;
            mem_ext     <= ex_ext;
        end
    end

endmodule
