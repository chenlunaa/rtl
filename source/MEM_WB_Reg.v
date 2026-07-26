`timescale 1ns / 1ps

`include "defines.vh"

// ============================================================================
// MEM/WB 流水寄存器: MEM阶段 -> WB阶段
// ============================================================================
module MEM_WB_Reg (
    input  wire         clk,
    input  wire         rst,
    input  wire         stall,

    // 访存读取数据
    input  wire [31:0]  mem_ram_ext,

    // ALU结果
    input  wire [31:0]  mem_alu_c,

    // 写回信号
    input  wire         mem_rf_we,
    input  wire [ 1:0]  mem_rf_wsel,
    input  wire [ 4:0]  mem_rf_wR,

    // PC+4 (JAL/JALR写回用) & PC & ext (LUI用)
    input  wire [31:0]  mem_pc4,
    input  wire [31:0]  mem_pc,
    input  wire [31:0]  mem_ext,

    // --- WB阶段输出 ---
    output reg  [31:0]  wb_ram_ext,
    output reg  [31:0]  wb_alu_c,

    output reg          wb_rf_we,
    output reg  [ 1:0]  wb_rf_wsel,
    output reg  [ 4:0]  wb_rf_wR,

    output reg  [31:0]  wb_pc4,
    output reg  [31:0]  wb_pc,
    output reg  [31:0]  wb_ext
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_ram_ext  <= 32'h0;
            wb_alu_c    <= 32'h0;

            wb_rf_we    <= 1'b0;
            wb_rf_wsel  <= `WB_ALU;
            wb_rf_wR    <= 5'h0;

            wb_pc4      <= 32'h0;
            wb_pc       <= 32'h0;
            wb_ext      <= 32'h0;
        end else if (stall) begin
            wb_ram_ext  <= wb_ram_ext;
            wb_alu_c    <= wb_alu_c;

            wb_rf_we    <= wb_rf_we;
            wb_rf_wsel  <= wb_rf_wsel;
            wb_rf_wR    <= wb_rf_wR;

            wb_pc4      <= wb_pc4;
            wb_pc       <= wb_pc;
            wb_ext      <= wb_ext;
        end else begin
            wb_ram_ext  <= mem_ram_ext;
            wb_alu_c    <= mem_alu_c;

            wb_rf_we    <= mem_rf_we;
            wb_rf_wsel  <= mem_rf_wsel;
            wb_rf_wR    <= mem_rf_wR;

            wb_pc4      <= mem_pc4;
            wb_pc       <= mem_pc;
            wb_ext      <= mem_ext;
        end
    end

endmodule
