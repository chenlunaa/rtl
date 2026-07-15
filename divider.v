`timescale 1ns / 1ps

module divider #(
    parameter WIDTH = 32
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [WIDTH-1:0] x,
    input  wire [WIDTH-1:0] y,
    input  wire       start,
    output wire [WIDTH-1:0] z,
    output reg  [WIDTH-1:0] r,
    output reg        busy     
);
    localparam CNT_W = $clog2(WIDTH+1);
    // TODO

    reg [WIDTH-1:0] quotient;  // 商
    assign z = quotient;

    reg [CNT_W-1:0] count;

    reg sign_q;           // 商的符号
    reg sign_r;           // 余数的符号

    reg [WIDTH-1:0] divisor;    // 除数（绝对值）
    reg [WIDTH-1:0] dividend;   // 被除数（绝对值）

    // 恢复余数法内部寄存器
    reg [2*WIDTH-1:0]  R;         // 部分余数：高8位=当前余数，低8位=被除数左移缓冲区
    reg [WIDTH-1:0]   Q;         // 部分商（8位）
    reg [WIDTH:0]   R_sub;     // R[15:8] - divisor 的9位结果（最高位=借位标志）
    reg [2*WIDTH-1:0]  R_next;    // 下一拍的部分余数
    reg [WIDTH-1:0]   Q_next;    // 下一拍的部分商

    always @(*) begin
        R_sub = {1'b0, R[2*WIDTH+1:WIDTH]} - {1'b0, divisor}; // R[15:8] - divisor
        // R_sub[8] == 0 表示够减（无借位），R_sub[8] == 1 表示不够减
        if (!R_sub[WIDTH]) begin
            // 够减：商上1
            Q_next = {Q[WIDTH-2:0], 1'b1};
            if (count == 1) begin
                // 最后一轮：不需要左移，余数 = 减法结果（高8位），低8位保持
                R_next = {R_sub[WIDTH-1:0], R[WIDTH-1:0]};
            end
            else begin
                // 非最后一轮：余数 = (减法结果, 低8位) 左移1位
                R_next = {R_sub[WIDTH-2:0], R[WIDTH-1:0], 1'b0};
            end
        end
        else begin
            // 不够减：商上0
            Q_next = {Q[WIDTH-2:0], 1'b0};
            if (count == 1) begin
                // 最后一轮：恢复余数 = R[15:8]（不减），不左移
                R_next = R;
            end
            else begin
                // 非最后一轮：恢复余数（保持R[15:8]不变），整体左移1位
                R_next = {R[2*WIDTH:0], 1'b0};
            end
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            busy <= 1'b0;
        end
        else if (start && !busy) begin
            busy <= 1'b1;
        end
        else if (count == 1 && busy) begin
            busy <= 1'b0;
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 0;
        end
        else if (start && !busy) begin
            count <= WIDTH+1;
        end
        else if (busy) begin
            count <= count - 1'b1;
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_q <= 1'b0;
            sign_r <= 1'b0;
        end
        else if (start && !busy) begin
            sign_q <= x[WIDTH-1] ^ y[WIDTH-1];   // 商符号：同号为正
            sign_r <= x[WIDTH-1];           // 余数符号：与被除数同号
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            divisor  <= 0;
            dividend <= 0;
        end
        else if (start && !busy) begin
            divisor  <= {1'b0, y[WIDTH-2:0]};
            dividend <= {1'b0, x[WIDTH-2:0]};
        end
    end


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            R <= 0;
            Q <= 0;
        end
        else if (start && !busy) begin
            // 初始化：被除数绝对值放入 R 低8位，高8位清零；Q 清零
            R <= {{(WIDTH-1){1'b0}}, 1'b0, x[WIDTH-2:0]};
            Q <= 0;
        end
        else if (busy) begin
            // 组合逻辑已经完成左移+试商，直接更新
            R <= R_next;
            Q <= Q_next;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            quotient  <= 0;
            r <= 0;
        end
        else if (count == 1 && busy) begin
            // 最后一轮迭代在 count==1 时完成，此时 R/Q 已更新为最终值
            quotient  <= {sign_q, Q_next[WIDTH-2:0]};
            r <= {sign_r, R_next[2*WIDTH-2:WIDTH]};
        end
    end
	
endmodule
