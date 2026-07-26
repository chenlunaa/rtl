`timescale 1ns / 1ps

`include "defines.vh"

// ============================================================================
// IF/ID 流水寄存器: IF阶段 -> ID阶段
// ============================================================================
module IF_ID_Reg (
    input  wire         clk,
    input  wire         rst,
    input  wire         ifetch_valid,
    input  wire         stall,
    input  wire         flush,

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
            id_inst <= 32'h13;

        end else begin
            if (flush) begin
                id_pc   <= 32'h0;
                id_pc4  <= 32'h0;
                id_inst <= 32'h13;
            end else if (ifetch_valid) begin
                id_pc   <= if_pc;
                id_pc4  <= if_pc4;
                id_inst <= if_inst;
            end
            else if (stall) begin
                id_pc   <= id_pc;
                id_pc4  <= id_pc4;
                id_inst <= id_inst;
            end
            else begin
                id_pc   <= if_pc;
                id_pc4  <= if_pc4;
                id_inst <= if_inst;
            end
        end
    end
endmodule
