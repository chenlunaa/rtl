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

    reg [WIDTH-1:0] quotient;
    reg [CNT_W-1:0] count;
    reg sign_q;
    reg sign_r;
    reg [WIDTH-1:0] divisor;
    reg [2*WIDTH-1:0] partial;
    reg [WIDTH-1:0] quotient_work;
    reg [WIDTH:0] subtraction;
    reg [2*WIDTH-1:0] partial_next;
    reg [WIDTH-1:0] quotient_next;

    assign z = quotient;

    always @(*) begin
        subtraction = {1'b0, partial[2*WIDTH-1:WIDTH]} - {1'b0, divisor};
        quotient_next = {quotient_work[WIDTH-2:0], !subtraction[WIDTH]};

        if (count == 1) begin
            if (subtraction[WIDTH])
                partial_next = partial;
            else
                partial_next = {subtraction[WIDTH-1:0], partial[WIDTH-1:0]};
        end else if (subtraction[WIDTH]) begin
            partial_next = {partial[2*WIDTH-2:0], 1'b0};
        end else begin
            partial_next = {subtraction[WIDTH-2:0], partial[WIDTH-1:0], 1'b0};
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            busy <= 1'b0;
        else if (start && !busy)
            busy <= 1'b1;
        else if (count == 1 && busy)
            busy <= 1'b0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            count <= 0;
        else if (start && !busy)
            count <= WIDTH + 1;
        else if (busy)
            count <= count - 1'b1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sign_q <= 1'b0;
            sign_r <= 1'b0;
        end else if (start && !busy) begin
            sign_q <= x[WIDTH-1] ^ y[WIDTH-1];
            sign_r <= x[WIDTH-1];
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst)
            divisor <= 0;
        else if (start && !busy)
            divisor <= {1'b0, y[WIDTH-2:0]};
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            partial <= 0;
            quotient_work <= 0;
        end else if (start && !busy) begin
            partial <= {{WIDTH{1'b0}}, 1'b0, x[WIDTH-2:0]};
            quotient_work <= 0;
        end else if (busy) begin
            partial <= partial_next;
            quotient_work <= quotient_next;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            quotient <= 0;
            r <= 0;
        end else if (count == 1 && busy) begin
            quotient <= sign_q
                      ? {sign_q, ~quotient_next[WIDTH-2:0]} + 1'b1
                      : {sign_q, quotient_next[WIDTH-2:0]};
            r <= sign_r
               ? {sign_r, ~partial_next[2*WIDTH-2:WIDTH]} + 1'b1
               : {sign_r, partial_next[2*WIDTH-2:WIDTH]};
        end
    end
endmodule
