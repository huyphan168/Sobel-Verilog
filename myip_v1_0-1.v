
/*
-------------------------------------------------------------------------------
--
-- Definition of Ports
-- ACLK              : Synchronous clock
-- ARESETN           : System reset, active low
-- S_AXIS_TREADY  : Ready to accept data in
-- S_AXIS_TDATA   :  Data in 
-- S_AXIS_TLAST   : Optional data in qualifier
-- S_AXIS_TVALID  : Data in is valid
-- M_AXIS_TVALID  :  Data out is valid
-- M_AXIS_TDATA   : Data Out
-- M_AXIS_TLAST   : Optional data out qualifier
-- M_AXIS_TREADY  : Connected slave device is ready to accept data out
--
-------------------------------------------------------------------------------
*/

module myip_v1_0 
	(
		// DO NOT EDIT BELOW THIS LINE ////////////////////
		ACLK,
		ARESETN,
		S_AXIS_TREADY,
		S_AXIS_TDATA,
		S_AXIS_TLAST,
		S_AXIS_TVALID,
		M_AXIS_TVALID,
		M_AXIS_TDATA,
		M_AXIS_TLAST,
		M_AXIS_TREADY
		// DO NOT EDIT ABOVE THIS LINE ////////////////////
	);

input                          ACLK;    // Synchronous clock
input                          ARESETN; // System reset, active low
// slave in interface
output                         S_AXIS_TREADY;  // Ready to accept data in
input      [31 : 0]            S_AXIS_TDATA;   // Data in
input                          S_AXIS_TLAST;   // Optional data in qualifier
input                          S_AXIS_TVALID;  // Data in is valid
// master out interface
output                         M_AXIS_TVALID;  // Data out is valid
output     [31 : 0]            M_AXIS_TDATA;   // Data Out
output                         M_AXIS_TLAST;   // Optional data out qualifier
input                          M_AXIS_TREADY;  // Connected slave device is ready to accept data out

//----------------------------------------
// Implementation Section
//----------------------------------------
// In this section, we povide an example implementation of MODULE myip_v1_0
// that does the following:
//
// 1. Read all inputs
// 2. Add each input to the contents of register 'sum' which
//    acts as an accumulator
// 3. After all the inputs have been read, write out the
//    content of 'sum' into the output stream NUMBER_OF_OUTPUT_WORDS times
//
// You will need to modify this example for
// MODULE myip_v1_0 to implement your coprocessor


// RAM parameters for the Sobel Edge IP
	localparam A_depth_bits = 14;  	// 128x128 elements (A is a 128x128 matrix)
	localparam GX_depth_bits = 14;	// 126x126 elements (Assume same elements as the inputs, may change as needed)
	localparam GY_depth_bits = 14;	// 126x126 elements (Assume same elements as the inputs, may change as needed)
	localparam width = 8;			// all 8-bit data
	
// wires (or regs) to connect to RAMs and matrix_multiply_0 for assignment 1
// those which are assigned in an always block of myip_v1_0 shoud be changes to reg.
	reg		A_write_en;								// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg.
	reg		[A_depth_bits-1:0] A_write_address;		// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg. 
	reg		[width-1:0] A_write_data_in;			// myip_v1_0 -> A_RAM. To be assigned within myip_v1_0. Possibly reg.
	wire	A_read_en;								// sobel_0 -> A_RAM.
	wire	[A_depth_bits-1:0] A_read_address;		// sobel_0 -> A_RAM.
	wire	[width-1:0] A_read_data_out;			// A_RAM -> sobel_0.
	wire	GX_write_en;							// sobel_0 -> GX_RAM.
	wire	[GX_depth_bits-1:0] GX_write_address;	// sobel_0 -> GX_RAM.
	wire	[width-1:0] GX_write_data_in;			// sobel_0 -> GX_RAM.
	reg		GX_read_en;  							// GX_RAM->myip_v1_0 To be assigned within myip_v1_0. Possibly reg.
	reg		[GX_depth_bits-1:0] GX_read_address;	// GX_RAM->myip_v1_0. To be assigned within myip_v1_0. Possibly reg.
	wire	[width-1:0] GX_read_data_out;			// GX_RAM -> myip_v1_0
	
	wire	GY_write_en;							// sobel_0 -> GY_RAM.
	wire	[GY_depth_bits-1:0] GY_write_address;	// sobel_0 -> GY_RAM.
	wire	[width-1:0] GY_write_data_in;			// sobel_0 -> GY_RAM.
	reg		GY_read_en;  							// GY_RAM->myip_v1_0 To be assigned within myip_v1_0. Possibly reg.
	reg		[GY_depth_bits-1:0] GY_read_address;	// GY_RAM->myip_v1_0. To be assigned within myip_v1_0. Possibly reg.
	wire	[width-1:0] GY_read_data_out;			// GY_RAM -> myip_v1_0
	// wires (or regs) to connect to matrix_multiply for assignment 1
	reg	Start; 								// myip_v1_0 -> sobel_0. To be assigned within myip_v1_0. Possibly reg.
	wire Done;								// sobel_0 -> myip_v1_0. 
			
				
   // Total number of input data.
   localparam NUMBER_OF_INPUT_WORDS  =  16384; // 2**A_depth_bits = 16,384 for our example

   // Total number of output data
   localparam NUMBER_OF_OUTPUT_WORDS = 15876; // 2**GX_depth_bits = 16,384 for our example image

   // Define the states of state machine (one hot encoding)
   localparam Idle  = 4'b1000;
   localparam Read_Inputs = 4'b0100;
   localparam Compute = 4'b0010;		// currently unused, but needed for our project
   localparam Write_Outputs  = 4'b0001;

   reg [3:0] state;

   // Accumulator to hold sum of inputs read at any point in time
//    reg [31:0] sum; // to do : We dont need this for Sobel application

   // Counters to store the number inputs read & outputs written
   reg [A_depth_bits - 1:0] nr_of_reads;   // to do : change it as necessary
   reg [GX_depth_bits -1:0] nr_of_writes; 
   reg counter_gradient; //register to detect which memory (GX or GY) shoud be read out AXIS_TDATA
   reg [width-1:0] temp; //register to store the data read from the RAMs
   // CAUTION:
   // The sequence in which data are read in should be
   // consistent with the sequence they are written
//    reg [31:0] temp;

   assign S_AXIS_TREADY = (state == Read_Inputs);
   assign M_AXIS_TVALID = (state == Write_Outputs);
   assign M_AXIS_TLAST = (state == Write_Outputs) & (nr_of_writes == 0) & (counter_gradient == 0);
   assign M_AXIS_TDATA = temp; //assigning the data to be sent out

   always @(posedge ACLK) 
   begin

      /****** Synchronous reset (active low) ******/
      if (!ARESETN)
        begin
           // CAUTION: make sure your reset polarity is consistent with the
           // system reset polarity
           state        <= Idle;
           nr_of_reads  <= 0;
           nr_of_writes <= 0;
		   counter_gradient <= 1;
        end
      /************** state machine **************/
      else
        case (state)

          Idle:
            if (S_AXIS_TVALID == 1)
            begin
              state       <= Read_Inputs;
              nr_of_reads <= NUMBER_OF_INPUT_WORDS - 1;
			  Start <= 0;
			  counter_gradient <= 1;

            end

          Read_Inputs:
            if (S_AXIS_TVALID == 1) 
            begin
			  A_write_en <= 1;
			  A_write_address <= nr_of_reads;
			  A_write_data_in <= S_AXIS_TDATA;
              if (nr_of_reads == 0)
                begin
                  state        <= Compute;
				  Start <= 1;
                  nr_of_writes <= NUMBER_OF_OUTPUT_WORDS - 1;
                end
              else
                nr_of_reads <= nr_of_reads - 1;
            end
            
          Compute:				
				if (Done == 1)
				begin
					Start <= 0;
					state <= Write_Outputs;
				end
				else
					Start <= 1;
				
          Write_Outputs:
            if (M_AXIS_TREADY == 1) 
            begin
              if (nr_of_writes == 0 && counter_gradient == 0)
                state <= Idle;
              else
			  	if (counter_gradient == 1)
				begin	
					GX_read_en <= 1;
					GX_read_address <= nr_of_writes;
					// temp <= GX_read_data_out;
					if (nr_of_writes == 0) 
					begin
						nr_of_writes <= NUMBER_OF_OUTPUT_WORDS-1;
						counter_gradient <= 0;
					end
					else
					begin
						nr_of_writes <= nr_of_writes - 1;
						temp <= GX_read_data_out;
					end
				end
				else
				begin
					GY_read_en <= 1;
					GY_read_address <= nr_of_writes;
					// temp <= GY_read_data_out;
					nr_of_writes <= nr_of_writes - 1;
					temp <= GY_read_data_out;
				end

            end
        endcase
   end
	   
	// Connection to sub-modules / components 
	
	memory_RAM 
	#(
		.width(width), 
		.depth_bits(A_depth_bits)
	) A_RAM 
	(
		.clk(ACLK),
		.write_en(A_write_en),
		.write_address(A_write_address),
		.write_data_in(A_write_data_in),
		.read_en(A_read_en),    
		.read_address(A_read_address),
		.read_data_out(A_read_data_out)
	);

	memory_RAM									
	#(
		.width(width), 
		.depth_bits(GX_depth_bits)
	) GX_RAM 
	(
		.clk(ACLK),
		.write_en(GX_write_en),
		.write_address(GX_write_address),
		.write_data_in(GX_write_data_in),
		.read_en(GX_read_en),    
		.read_address(GX_read_address),
		.read_data_out(GX_read_data_out)
	);

  memory_RAM
	#(
		.width(width), 
		.depth_bits(GY_depth_bits)
	) GY_RAM 
	(
		.clk(ACLK),
		.write_en(GY_write_en),
		.write_address(GY_write_address),
		.write_data_in(GY_write_data_in),
		.read_en(GY_read_en),    
		.read_address(GY_read_address),
		.read_data_out(GY_read_data_out)
	);

										
	sobel 
	#(
		.width(width), 
		.A_depth_bits(A_depth_bits), 
		.GX_depth_bits(GX_depth_bits),
		.GY_depth_bits(GY_depth_bits)
	) sobel_0
	(									
		.clk(ACLK),
		.Start(Start),
		.Done(Done),
		
		.A_read_en(A_read_en),
		.A_read_address(A_read_address),
		.A_read_data_out(A_read_data_out),
		
		.GX_write_en(GX_write_en),
		.GX_write_address(GX_write_address),
		.GX_write_data_in(GX_write_data_in),

		.GY_write_en(GY_write_en),
		.GY_write_address(GY_write_address),
		.GY_write_data_in(GY_write_data_in)
	);

endmodule






/*
------------------------------------------------------------------------------
-- Naming Conventions:
--   active low signals:                    "*_n"
--   clock signals:                         "clk", "clk_div#", "clk_#x"
--   reset signals:                         "rst", "rst_n"
--   generics:                              "C_*"
--   user defined types:                    "*_TYPE"
--   state machine next state:              "*_ns"
--   state machine current state:           "*_cs"
--   combinatorial signals:                 "*_com"
--   pipelined or register delay signals:   "*_d#"
--   counter signals:                       "*cnt*"
--   clock enable signals:                  "*_ce"
--   internal version of output port:       "*_i"
--   device pins:                           "*_pin"
--   ports:                                 "- Names begin with Uppercase"
--   processes:                             "*_PROCESS"
--   component instantiations:              "<ENTITY_>I_<#|FUNC>"
------------------------------------------------------------------------------

-------------------------------------------------------------------------------------
*/