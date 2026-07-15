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

    // TODO
	reg [WIDTH:0] M; // multiplicand_copy
	reg [CNT_W-1:0] count;

	reg busy_r;
	assign busy = busy_r;
	reg [WIDTH:0] A_calc;
	reg [O_WID + 1:0] booth;
	reg [O_WID + 1:0] booth_next;
	
	always @(*)begin
		case({booth[1:0]})

			2'b01: A_calc = booth[O_WID + 1:WIDTH + 1] + M;
			2'b10: A_calc = booth[O_WID + 1:WIDTH + 1] - M;
			default: A_calc = booth[O_WID + 1:WIDTH + 1];
		endcase

		 booth_next = {
                    A_calc[WIDTH],
                    A_calc,
                    booth[WIDTH:1]
                 };
	end


	always @(posedge clk or posedge rst) begin

		if (rst) begin
			M <= 0;
		end

		else if(start && !busy_r)begin
			M <= {x[WIDTH - 1], x};
		end
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			booth <= 0;
		end

		else if(start && !busy_r)begin
			booth[O_WID + 1:WIDTH + 1] <= 0;
			booth[WIDTH:1] <= y;
			booth[0] <= 0;
		end
		else if(busy_r)begin
			booth <= booth_next;
		end
	end

    
	always @(posedge clk or posedge rst) begin

		if (rst) begin
			count <= 0;
		end

		else if(start && !busy_r)begin
			count <= WIDTH;
		end
		else if(busy_r)begin
			count <= count - 1;
		end
	end


	always @(posedge clk or posedge rst) begin
		if (rst) begin
			busy_r <= 0;
		end

		else if(start && !busy_r)begin
			busy_r <= 1;
		end

		else if(count == 1 && busy_r)begin
			busy_r <= 0;
		end
	end

	always @(posedge clk or posedge rst) begin
		if (rst) begin
			z <= 0;
		end

		else if(count == 1 && busy_r)begin
			z <= booth_next[O_WID:1];
		end
	end
endmodule
