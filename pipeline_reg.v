`timescale 1ns / 1ps

`include "defines.vh"

// ============================================================================
// 五级理想流水线寄存器模块
// 理想流水线: 无停顿、无冲刷、无数据相关处理、无分支跳转/访存/乘除法
// 阶段: IF -> ID -> EX -> MEM -> WB
// ============================================================================

// ============================================================================
// IF/ID 流水寄存器: IF阶段 -> ID阶段
// ============================================================================
module IF_ID_Reg (
    input  wire         clk,
    input  wire         rst,

    input  wire [31:0]  if_pc,
    input  wire [31:0]  if_pc4,
    input  wire [31:0]  if_inst,

    output reg  [31:0]  id_pc,
    output reg  [31:0]  id_pc4,
    output reg  [31:0]  id_inst
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            id_pc   <= 32'h0;
            id_pc4  <= 32'h0;
            id_inst <= 32'h13;          // NOP (addi x0, x0, 0)
        end else begin
            id_pc   <= if_pc;
            id_pc4  <= if_pc4;
            id_inst <= if_inst;
        end
    end

endmodule

// ============================================================================
// ID/EX 流水寄存器: ID阶段 -> EX阶段
// ============================================================================
module ID_EX_Reg (
    input  wire         clk,
    input  wire         rst,

    // 控制信号
    input  wire [ 4:0]  id_alu_op,
    input  wire         id_alua_sel,
    input  wire         id_alub_sel,

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

            ex_rf_we    <= 1'b0;
            ex_rf_wsel  <= `WB_ALU;
            ex_rf_wR    <= 5'h0;

            ex_pc       <= 32'h0;
            ex_pc4      <= 32'h0;
            ex_rf_rd1   <= 32'h0;
            ex_rf_rd2   <= 32'h0;
            ex_ext      <= 32'h0;
        end else begin
            ex_alu_op   <= id_alu_op;
            ex_alua_sel <= id_alua_sel;
            ex_alub_sel <= id_alub_sel;

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

// ============================================================================
// EX/MEM 流水寄存器: EX阶段 -> MEM阶段
// ============================================================================
module EX_MEM_Reg (
    input  wire         clk,
    input  wire         rst,

    // ALU结果
    input  wire [31:0]  ex_alu_c,

    // 访存控制 (理想流水线暂不使用, 但保留接口)
    input  wire [ 2:0]  ex_ram_rop,
    input  wire [ 3:0]  ex_ram_wop,

    // 写回信号
    input  wire         ex_rf_we,
    input  wire [ 1:0]  ex_rf_wsel,
    input  wire [ 4:0]  ex_rf_wR,

    // store数据 & PC+4
    input  wire [31:0]  ex_rf_rd2,
    input  wire [31:0]  ex_pc4,

    // --- MEM阶段输出 ---
    output reg  [31:0]  mem_alu_c,

    output reg  [ 2:0]  mem_ram_rop,
    output reg  [ 3:0]  mem_ram_wop,

    output reg          mem_rf_we,
    output reg  [ 1:0]  mem_rf_wsel,
    output reg  [ 4:0]  mem_rf_wR,

    output reg  [31:0]  mem_rf_rd2,
    output reg  [31:0]  mem_pc4
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
        end else begin
            mem_alu_c   <= ex_alu_c;

            mem_ram_rop <= ex_ram_rop;
            mem_ram_wop <= ex_ram_wop;

            mem_rf_we   <= ex_rf_we;
            mem_rf_wsel <= ex_rf_wsel;
            mem_rf_wR   <= ex_rf_wR;

            mem_rf_rd2  <= ex_rf_rd2;
            mem_pc4     <= ex_pc4;
        end
    end

endmodule

// ============================================================================
// MEM/WB 流水寄存器: MEM阶段 -> WB阶段
// ============================================================================
module MEM_WB_Reg (
    input  wire         clk,
    input  wire         rst,

    // 访存读取数据
    input  wire [31:0]  mem_ram_ext,

    // ALU结果
    input  wire [31:0]  mem_alu_c,

    // 写回信号
    input  wire         mem_rf_we,
    input  wire [ 1:0]  mem_rf_wsel,
    input  wire [ 4:0]  mem_rf_wR,

    // PC+4 (JAL/JALR写回用)
    input  wire [31:0]  mem_pc4,

    // --- WB阶段输出 ---
    output reg  [31:0]  wb_ram_ext,
    output reg  [31:0]  wb_alu_c,

    output reg          wb_rf_we,
    output reg  [ 1:0]  wb_rf_wsel,
    output reg  [ 4:0]  wb_rf_wR,

    output reg  [31:0]  wb_pc4
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_ram_ext  <= 32'h0;
            wb_alu_c    <= 32'h0;

            wb_rf_we    <= 1'b0;
            wb_rf_wsel  <= `WB_ALU;
            wb_rf_wR    <= 5'h0;

            wb_pc4      <= 32'h0;
        end else begin
            wb_ram_ext  <= mem_ram_ext;
            wb_alu_c    <= mem_alu_c;

            wb_rf_we    <= mem_rf_we;
            wb_rf_wsel  <= mem_rf_wsel;
            wb_rf_wR    <= mem_rf_wR;

            wb_pc4      <= mem_pc4;
        end
    end

endmodule
