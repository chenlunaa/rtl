`timescale 1ns / 1ps

// 寄存器堆 输入RS1, RS2, RD, 写使能，写数据
module RF (
    input  wire         clk,

    input  wire [ 4:0]  rR1,
    input  wire [ 4:0]  rR2,
    input  wire         we,
    input  wire [ 4:0]  wR,
    input  wire [31:0]  wD,
    
    output wire [31:0]  rD1,
    output wire [31:0]  rD2
);
    
    reg [31:0] regs [1:31]; // 这个就是32个寄存器堆

    // 读寄存器堆组合逻辑
    assign rD1 = (rR1 == 0) ? 0 : regs[rR1];
    assign rD2 = (rR2 == 0) ? 0 : regs[rR2];
    
    // 写寄存器堆时序逻辑， 时钟上升沿写入
    always @(posedge clk) begin
        if (we && (wR != 5'h0)) regs[wR] <= wD;
    end
    
endmodule
