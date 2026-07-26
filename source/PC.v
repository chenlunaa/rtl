`timescale 1ns / 1ps

module PC (
    input  wire         clk,
    input  wire         rst,
    
    input  wire [31:0]  npc,
    input  wire         fetch,
    input  wire         stall,
    output reg  [31:0]  pc
);

    always @(posedge clk or posedge rst) begin
        if (rst)        pc <= 32'h0;
        else if (stall) pc <= pc;
        else            pc <= fetch ? npc : pc;
    end
    
endmodule
