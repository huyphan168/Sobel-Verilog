`timescale 1ns / 1ps


// those outputs which are assigned in an always block of sobel shoud be changes to reg (such as output reg Done).

module sobel
	#( // kernel size of the covolution filter. In this case, we have sobel kernel
		parameter width = 8, 			// width is the number of bits per location
		parameter A_depth_bits = 14, 	// depth is the number of locations (2^number of address bits) (need to change)
		parameter GX_depth_bits = 14, 
		parameter GY_depth_bits = 14
	) 
	(
		input clk,										
		input Start,									// myip_v1_0 -> sobel_0.
		output reg Done = 1'b0,										// sobel_0 -> my3ip_v1_0. Possibly reg.
		
		output reg A_read_en,  								// sobel_0 -> A_RAM. Possibly reg.
		output reg [A_depth_bits-1:0] A_read_address, 		// sobel_0 -> A_RAM. Possibly reg.
		input [width-1:0] A_read_data_out,				// A_RAM -> sobel_0.
		
		output reg GX_write_en, 							// sobel_0 -> GX_RAM. Possibly reg.
		output reg [GX_depth_bits-1:0] GX_write_address, 	// sobel_0 -> GX_RAM. Possibly reg.
		output reg [width-1:0] GX_write_data_in, 			// sobel_0 -> GX_RAM. Possibly reg.

		output reg GY_write_en, 							// sobel_0 -> GX_RAM. Possibly reg.
		output reg [GY_depth_bits-1:0] GY_write_address, 	// sobel_0 -> GX_RAM. Possibly reg.
		output reg [width-1:0] GY_write_data_in 			// sobel_0 -> GX_RAM. Possibly reg.
	);
	localparam kernel_area = kernel_size**2;
	localparam NUMBER_OF_OUTPUT_WORDS = 15876;
	localparam START_IDX = 16128;
	localparam image_size = 128;
	localparam kernel_size = 3;
	// State Machine 
	localparam Idle = 4'b1000;
	localparam Read = 4'b0100;
	localparam Compute = 4'b0010;
	localparam Complete = 4'b0001;
	reg [3:0] state;
	integer i;

	// implement the logic to read A_RAM, do the sobel operation and write the results to GX_RAM, GY RAM
	// Note: A_RAM are to be read synchronously.

	wire [width-1:0] Gx_kernel [0:kernel_area-1]; 
	wire [width-1:0] Gy_kernel [0:kernel_area-1];
	
	assign Gx_kernel[0] = -1;
	assign Gx_kernel[1] = 0;
	assign Gx_kernel[2] = 1;
	assign Gx_kernel[3] = -2;
	assign Gx_kernel[4] = 0;
	assign Gx_kernel[5] = 2;
	assign Gx_kernel[6] = -1;
	assign Gx_kernel[7] = 0;
	assign Gx_kernel[8] = 1;

	assign Gy_kernel[0] = -1;
	assign Gy_kernel[1] = -2;
	assign Gy_kernel[2] = -1;
	assign Gy_kernel[3] = 0;
	assign Gy_kernel[4] = 0;
	assign Gy_kernel[5] = 0;
	assign Gy_kernel[6] = 1;
	assign Gy_kernel[7] = 2;
	assign Gy_kernel[8] = 1;



	reg [width-1:0] A_data [0:kernel_size**2-1];  //buffer to store the data read from A_RAM
	reg [width-1:0] GX_data;
	reg [width-1:0] GY_data;
	reg [3:0] kernel_counter;
	reg [A_depth_bits-1:0] output_counter;
	reg [A_depth_bits-1:0] input_counter;
		
	always @(posedge clk) 
	begin
		if (!Start) 
			begin
				state <= Idle;
				kernel_counter <= kernel_area-1;
				output_counter <= NUMBER_OF_OUTPUT_WORDS-1;
				input_counter <= START_IDX-1;
				Done <= 0;
				GY_write_en <= 0;
				GX_write_en <= 0;
				A_read_en <= 0;
				GX_data <= 0;
				GY_data <= 0;
			end
		else
			case (state)
				Idle: begin
					// start the process
					state <= Read;
					A_read_en <= 1;
					A_read_address <= input_counter;
				end

				Read: begin
					if (kernel_counter == 0) begin
						state <= Compute;
						kernel_counter <= kernel_area-1;
						if (output_counter % (image_size-kernel_size+1) == 0)
							input_counter <= input_counter - kernel_size;
						else 
							input_counter <= input_counter - 1;
					end
					else 
					begin
						case (kernel_counter)
							4'b1000: A_read_address <= input_counter + image_size + 1;
							4'b0111: A_read_address <= input_counter + image_size;
							4'b0110: A_read_address <= input_counter + image_size - 1;
							4'b0101: A_read_address <= input_counter + 1;
							4'b0100: A_read_address <= input_counter;
							4'b0011: A_read_address <= input_counter - 1;
							4'b0010: A_read_address <= input_counter - image_size + 1;
							4'b0001: A_read_address <= input_counter - image_size;
							4'b0000: A_read_address <= input_counter - image_size - 1;
						endcase
						A_data[kernel_counter] <= A_read_data_out;
						state <= Read;
						kernel_counter <= kernel_counter - 1;
					end
				end

				Compute: begin
					for (i = 0; i < kernel_area; i=i+1) begin
						GX_data <= GX_data + A_data[kernel_area-i] * Gx_kernel[i];
						GY_data <= GY_data + A_data[kernel_area-i] * Gy_kernel[i];
					end
					if (GX_data[width-1] == 1) begin
						GX_data <= -GX_data;
					end
					if (GY_data[width-1] == 1) begin
						GY_data <= -GY_data;
					end
					state <= Complete;
					GX_write_en <= 1;
					GX_write_address <= output_counter;
					GX_write_data_in <= GX_data;
					GY_write_en <= 1;
					GY_write_address <= output_counter;
					GY_write_data_in <= GY_data;
				end

				Complete: begin
					output_counter <= output_counter -1;
					GX_data <= 0;
					GY_data <= 0;
					if (output_counter == 0) begin
						state <= Idle;
						Done <= 1;
					end
					else state <= Read;
				end
			endcase
	end

endmodule


