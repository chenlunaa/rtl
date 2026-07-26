`timescale 1ns / 1ps

`include "defines.vh"

// ============================================================================
// ID/EX 流水寄存器: ID阶段 -> EX阶段
// ============================================================================
module ID_EX_Reg (
    input  wire         clk,
    input  wire         rst,
    input  wire         stall,
    input  wire         flush,
    input  wire         bubble,

    // 控制信号
    input  wire [ 4:0]  id_alu_op,
    input  wire         id_alua_sel,
    input  wire         id_alub_sel,

    // NPC 控制 (用于分支预测失败检测)
    input  wire [ 1:0]  id_npc_op,

    // 访存控制 (传递到EX, 再经MEM到访存单元)
    input  wire [ 2:0]  id_ram_rop,
    input  wire [ 3:0]  id_ram_wop,

    // 乘除法标志 (用于 done 检测)
    input  wire         id_is_mul,
    input  wire         id_is_div,

    // 写回信号 (传递到EX, 再经MEM到WB)
    input  wire         id_rf_we,
    input  wire [ 1:0]  id_rf_wsel,
    input  wire [ 4:0]  id_rf_wR,

    // 数据信号
    input  wire [31:0]  id_pc,
    input  wire [31:0]  id_pc4,
    input  wire [31:0]  id_rf_rd1,
    input  wire [31:0]  id_rf_rd2,
    input  wire [31:0]  id_ext,

    // --- EX阶段输出 ---
    output reg  [ 4:0]  ex_alu_op,
    output reg          ex_alua_sel,
    output reg          ex_alub_sel,

    output reg  [ 1:0]  ex_npc_op,

    output reg  [ 2:0]  ex_ram_rop,
    output reg  [ 3:0]  ex_ram_wop,

    output reg          ex_is_mul,
    output reg          ex_is_div,

    output reg          ex_rf_we,
    output reg  [ 1:0]  ex_rf_wsel,
    output reg  [ 4:0]  ex_rf_wR,

    output reg  [31:0]  ex_pc,
    output reg  [31:0]  ex_pc4,
    output reg  [31:0]  ex_rf_rd1,
    output reg  [31:0]  ex_rf_rd2,
    output reg  [31:0]  ex_ext
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_alu_op   <= `ALU_ADD;
            ex_alua_sel <= `ALU_A_RS1;
            ex_alub_sel <= `ALU_B_RS2;

            ex_npc_op   <= `NPC_PC4;

            ex_ram_rop  <= `RAM_EXT_N;
            ex_ram_wop  <= `RAM_WE_N;

            ex_is_mul   <= 1'b0;
            ex_is_div   <= 1'b0;

            ex_rf_we    <= 1'b0;
            ex_rf_wsel  <= `WB_ALU;
            ex_rf_wR    <= 5'h0;

            ex_pc       <= 32'h0;
            ex_pc4      <= 32'h0;
            ex_rf_rd1   <= 32'h0;
            ex_rf_rd2   <= 32'h0;
            ex_ext      <= 32'h0;
        end else if (flush) begin
            ex_alu_op   <= `ALU_ADD;
            ex_alua_sel <= `ALU_A_RS1;
            ex_alub_sel <= `ALU_B_RS2;

            ex_npc_op   <= `NPC_PC4;

            ex_ram_rop  <= `RAM_EXT_N;
            ex_ram_wop  <= `RAM_WE_N;

            ex_is_mul   <= 1'b0;
            ex_is_div   <= 1'b0;

            ex_rf_we    <= 1'b0;
            ex_rf_wsel  <= `WB_ALU;
            ex_rf_wR    <= 5'h0;

            ex_pc       <= 32'h0;
            ex_pc4      <= 32'h0;
            ex_rf_rd1   <= 32'h0;
            ex_rf_rd2   <= 32'h0;
            ex_ext      <= 32'h0;
        end else if (bubble) begin
            // 1. 控制信号清零（变成 NOP，不写寄存器、不写内存）
            ex_alu_op   <= `ALU_ADD;
            ex_alua_sel <= `ALU_A_RS1;
            ex_alub_sel <= `ALU_B_RS2;
            ex_npc_op   <= `NPC_PC4;
            ex_ram_rop  <= `RAM_EXT_N;
            ex_ram_wop  <= `RAM_WE_N;
            ex_is_mul   <= 1'b0;
            ex_is_div   <= 1'b0;
            ex_rf_we    <= 1'b0;   
            ex_rf_wsel  <= `WB_ALU;
            ex_rf_wR    <= 5'h0;    

            // 2. PC 和数据信号正常向下传递（保证 PC 不丢失！）
            ex_pc       <= id_pc;   
            ex_pc4      <= id_pc4;  
            ex_rf_rd1   <= id_rf_rd1;
            ex_rf_rd2   <= id_rf_rd2;
            ex_ext      <= id_ext;
        end else if (stall) begin
            ex_alu_op   <= ex_alu_op;
            ex_alua_sel <= ex_alua_sel;
            ex_alub_sel <= ex_alub_sel;

            ex_npc_op   <= ex_npc_op;

            ex_ram_rop  <= ex_ram_rop;
            ex_ram_wop  <= ex_ram_wop;

            ex_is_mul   <= ex_is_mul;
            ex_is_div   <= ex_is_div;

            ex_rf_we    <= ex_rf_we;
            ex_rf_wsel  <= ex_rf_wsel;
            ex_rf_wR    <= ex_rf_wR;

            ex_pc       <= ex_pc;
            ex_pc4      <= ex_pc4;
            ex_rf_rd1   <= ex_rf_rd1;
            ex_rf_rd2   <= ex_rf_rd2;
            ex_ext      <= ex_ext;
        end else begin
            ex_alu_op   <= id_alu_op;
            ex_alua_sel <= id_alua_sel;
            ex_alub_sel <= id_alub_sel;

            ex_npc_op   <= id_npc_op;

            ex_ram_rop  <= id_ram_rop;
            ex_ram_wop  <= id_ram_wop;

            ex_is_mul   <= id_is_mul;
            ex_is_div   <= id_is_div;

            ex_rf_we    <= id_rf_we;
            ex_rf_wsel  <= id_rf_wsel;
            ex_rf_wR    <= id_rf_wR;

            ex_pc       <= id_pc;
            ex_pc4      <= id_pc4;
            ex_rf_rd1   <= id_rf_rd1;
            ex_rf_rd2   <= id_rf_rd2;
            ex_ext      <= id_ext;
        end
    end

endmodule
