`timescale 1ns / 1ps

module multiplier #(
    parameter WIDTH = 32
)(
    input  wire        clk,
	input  wire        rst,
	input  wire [WIDTH-1:0] x,
	input  wire [WIDTH-1:0] y,
	input  wire        start,
	output reg  [2*WIDTH-1:0] z,
	output wire        busy 
);

	localparam O_WID = 2*WIDTH;
	localparam CNT_W = $clog2(WIDTH+1);

	reg [WIDTH:0] multiplicand;
	reg [CNT_W-1:0] count;
	reg busy_r;
	reg [WIDTH:0] accumulator;
	reg [O_WID+1:0] booth;
	reg [O_WID+1:0] booth_next;

	assign busy = busy_r;

	always @(*) begin
		case (booth[1:0])
			2'b01: accumulator = booth[O_WID+1:WIDTH+1] + multiplicand;
			2'b10: accumulator = booth[O_WID+1:WIDTH+1] - multiplicand;
			default: accumulator = booth[O_WID+1:WIDTH+1];
		endcase

		booth_next = {
			accumulator[WIDTH],
			accumulator,
			booth[WIDTH:1]
		};
	end

	always @(posedge clk or posedge rst) begin
		if (rst)
			multiplicand <= 0;
		else if (start && !busy_r)
			multiplicand <= {x[WIDTH-1], x};
	end

	always @(posedge clk or posedge rst) begin
		if (rst)
			booth <= 0;
		else if (start && !busy_r) begin
			booth[O_WID+1:WIDTH+1] <= 0;
			booth[WIDTH:1] <= y;
			booth[0] <= 0;
		end else if (busy_r)
			booth <= booth_next;
	end

	always @(posedge clk or posedge rst) begin
		if (rst)
			count <= 0;
		else if (start && !busy_r)
			count <= WIDTH;
		else if (busy_r)
			count <= count - 1'b1;
	end

	always @(posedge clk or posedge rst) begin
		if (rst)
			busy_r <= 1'b0;
		else if (start && !busy_r)
			busy_r <= 1'b1;
		else if (count == 1 && busy_r)
			busy_r <= 1'b0;
	end

	always @(posedge clk or posedge rst) begin
		if (rst)
			z <= 0;
		else if (count == 1 && busy_r)
			z <= booth_next[O_WID:1];
	end
endmodule
