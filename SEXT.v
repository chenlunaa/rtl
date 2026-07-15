`timescale 1ns / 1ps
`include "defines.vh"

// 立即数提取器，根据不同的指令类型来提取指令中的立即数并且进行位扩展到32位
module SEXT (
    input  wire [ 2:0]  op,
    input  wire [31:7]  imm,
    output reg  [31:0]  ext
);

    always @(*) begin
        case (op)
            `EXT_I : ext = {{20{imm[31]}}, imm[31:20]}; // {20{imm[31]}}表示符号位扩展20位
            `EXT_B : ext = {{19{imm[31]}}, imm[31], imm[7], imm[30:25], imm[11:8], 1'b0}; // B型跳转指令二字节对齐
            `EXT_U : ext = {imm[31:12], 12'h0};
            `EXT_J : ext = {{11{imm[31]}}, imm[31], imm[19:12], imm[20], imm[30:21], 1'b0};
            default: ext = 32'h0;
        endcase
    end
    
endmodule
