`timescale 1ns / 1ps

`include "defines.vh"

module ALU (
    input  wire         rst,
    input  wire         clk,
    input  wire [ 4:0]  op,
    input  wire [31:0]  a,
    input  wire [31:0]  b,
    
    output reg  [31:0]  c,
    output reg          br,
    output wire         busy
);

    wire        mul_flag, mulu_flag;
    wire [63:0] mul_res;
    wire [65:0] mulu_res;
    wire        mul_busy, mulu_busy;
    wire        div_flag, divu_flag;
    wire [32:0] div_quo;
    wire [32:0] divu_quo;
    wire [32:0] div_rem;
    wire [32:0] divu_rem;
    wire        div_busy, divu_busy;
    wire [31:0] div_abs_a = a[31] ? ~a + 1'b1 : a;
    wire [31:0] div_abs_b = b[31] ? ~b + 1'b1 : b;
    reg  [ 4:0] op_r;
    reg         div_zero_r;
    reg  [31:0] dividend_r;

    always @(*) begin
        c = 32'h0;  // 默认值, 防止 X 态
        case (op_r != 5'h0 ? op_r : op)
            `ALU_ADD  : c = a + b;
            `ALU_SUB  : c = a - b;
            `ALU_XOR  : c = a ^ b;
            `ALU_OR   : c = a | b;
            `ALU_AND  : c = a & b;
            `ALU_SLL  : c = a << b[4:0];
            `ALU_SRL  : c = a >> b[4:0];
            `ALU_SRA  : c = $signed(a) >>> b[4:0];
            `ALU_SLT  : c = $signed(a) < $signed(b) ? 32'h1 : 32'h0;
            `ALU_SLTU : c = a < b ? 32'h1 : 32'h0;
            `ALU_MUL  : c = mul_res[31:0];
            `ALU_MULH : c = mul_res[63:32];
            `ALU_MULHU: c = mulu_res[63:32];
            `ALU_DIV  : c = div_zero_r ? 32'hffff_ffff : div_quo[31:0];
            `ALU_DIVU : c = div_zero_r ? 32'hffff_ffff : divu_quo[31:0];
            `ALU_REM  : c = div_zero_r ? dividend_r : div_rem[31:0];
            `ALU_REMU : c = div_zero_r ? dividend_r : divu_rem[31:0];
            default   : ;
        endcase
    end

    always @(*) begin
        br = 1'b0;  // 默认值, 防止 X 态
        case (op)
            `ALU_EQ  : br = a == b;
            `ALU_NE  : br = a != b;
            `ALU_SLT : br = $signed(a) < $signed(b);
            `ALU_SLTU: br = a < b;
            `ALU_BGE : br = $signed(a) >= $signed(b);
            `ALU_BGEU: br = a >= b;
            default  : ;
        endcase
    end

    assign mul_flag  = (op == `ALU_MUL) | (op == `ALU_MULH);
    assign mulu_flag = op == `ALU_MULHU;
    assign div_flag  = (op == `ALU_DIV) | (op == `ALU_REM);
    assign divu_flag = (op == `ALU_DIVU) | (op == `ALU_REMU);
    assign busy      = mul_busy | mulu_busy | div_busy | divu_busy;

    always @(posedge clk or posedge rst) begin
        if (rst)
            op_r <= 5'h0;
        else if (mul_flag | mulu_flag | div_flag | divu_flag)
            op_r <= op;
        else if (!busy)
            op_r <= 5'h0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            div_zero_r <= 1'b0;
            dividend_r <= 32'h0;
        end else if (div_flag | divu_flag) begin
            div_zero_r <= b == 32'h0;
            dividend_r <= a;
        end
    end

    multiplier #(32) U_mul (
        .clk    (clk),
        .rst    (rst),
        .x      (a),
        .y      (b),
        .start  (mul_flag),
        .z      (mul_res),
        .busy   (mul_busy)
    );

    multiplier #(33) U_mulu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (mulu_flag),
        .z      (mulu_res),
        .busy   (mulu_busy)
    );

    divider #(33) U_div (
        .clk    (clk),
        .rst    (rst),
        .x      ({a[31], div_abs_a}),
        .y      ({b[31], div_abs_b}),
        .start  (div_flag),
        .z      (div_quo),
        .r      (div_rem),
        .busy   (div_busy)
    );

    divider #(33) U_divu (
        .clk    (clk),
        .rst    (rst),
        .x      ({1'b0, a}),
        .y      ({1'b0, b}),
        .start  (divu_flag),
        .z      (divu_quo),
        .r      (divu_rem),
        .busy   (divu_busy)
    );

endmodule
