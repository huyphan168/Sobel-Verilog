`timescale 1ns / 1ps

module tb_myip_v1_0(

    );
    
    reg                          ACLK = 0;    // Synchronous clock
    reg                          ARESETN; // System reset, active low
    // slave in interface
    wire                         S_AXIS_TREADY;  // Ready to accept data in
    reg      [31 : 0]            S_AXIS_TDATA;   // Data in
    reg                          S_AXIS_TLAST;   // Optional data in qualifier
    reg                          S_AXIS_TVALID;  // Data in is valid
    // master out interface
    wire                         M_AXIS_TVALID;  // Data out is valid
    wire     [31 : 0]            M_AXIS_TDATA;   // Data out
    wire                         M_AXIS_TLAST;   // Optional data out qualifier
    reg                          M_AXIS_TREADY;  // Connected slave device is ready to accept data out
    
    myip_v1_0 U1 ( 
                .ACLK(ACLK),
                .ARESETN(ARESETN),
                .S_AXIS_TREADY(S_AXIS_TREADY),
                .S_AXIS_TDATA(S_AXIS_TDATA),
                .S_AXIS_TLAST(S_AXIS_TLAST),
                .S_AXIS_TVALID(S_AXIS_TVALID),
                .M_AXIS_TVALID(M_AXIS_TVALID),
                .M_AXIS_TDATA(M_AXIS_TDATA),
                .M_AXIS_TLAST(M_AXIS_TLAST),
                .M_AXIS_TREADY(M_AXIS_TREADY)
	);
	
	localparam NUMBER_OF_INPUT_WORDS  = 16384;  // length of an input vector
	localparam NUMBER_OF_OUTPUT_WORDS  = 15876;  // length of an input vector
	localparam width  = 8;  // width of an input vector
           
	reg [width-1:0] test_input_memory [0:NUMBER_OF_INPUT_WORDS-1]; // 4 inputs * 2
	reg [width-1:0] test_result_expected_memory [0:2*NUMBER_OF_OUTPUT_WORDS-1]; // 4 outputs *2
	reg [width-1:0] result_memory [0:2*NUMBER_OF_OUTPUT_WORDS-1]; // same size as test_result_expected_memory
	
	integer word_cnt;
	reg success = 1'b1;
	reg M_AXIS_TLAST_prev = 1'b0;
	
	always@(posedge ACLK)
		M_AXIS_TLAST_prev <= M_AXIS_TLAST;
           
	always
		#50 ACLK = ~ACLK;
             
           initial
           begin
               	$display("Loading Memory.");
        		$readmemh("test_input.mem", test_input_memory); // v2: add the .mem file to the project or specify the complete path
        		$readmemh("test_result_expected.mem", test_result_expected_memory); // v2 : add the .mem file to the project or specify the complete path
        		#25						//just so that the input data changes at a time which is not a clock edge, to avoid confision
               	ARESETN = 1'b0; 		// apply reset (active low)
               	S_AXIS_TVALID = 1'b0;   // no valid data placed on the S_AXIS_TDATA yet
               	S_AXIS_TLAST = 1'b0; 	// not required unless we are dealing with an unknown number of inputs. Ignored by the coprocessor. We will be asserting it correctly anyway
               	M_AXIS_TREADY = 1'b0;	// not ready to receive data from the co-processor yet.   

               	#100 					// hold reset for 100 ns.
               	ARESETN = 1'b1;			// release reset

               	//// Input 
				word_cnt=0;
				S_AXIS_TVALID = 1'b1;   // data is ready at the input of the coprocessor.
				while(word_cnt < NUMBER_OF_INPUT_WORDS)
				begin
					if(S_AXIS_TREADY)	// S_AXIS_TREADY is asserted by the coprocessor in response to S_AXIS_TVALID
					begin
						S_AXIS_TDATA = test_input_memory[word_cnt]; // set the next data ready
						if(word_cnt == NUMBER_OF_INPUT_WORDS-1)
							S_AXIS_TLAST = 1'b1; 
						else
							S_AXIS_TLAST = 1'b0;
						word_cnt=word_cnt+1;
					end
					#100;			// wait for one clock cycle before for co-processor to capture data (if S_AXIS_TREADY was set) 
													// or before checking S_AXIS_TREADY again (if S_AXIS_TREADY was not set)
				end
				S_AXIS_TVALID = 1'b0;	// we no longer give any data to the co-processor
				S_AXIS_TLAST = 1'b0;
				
				/// Output
				word_cnt = 0;
				M_AXIS_TREADY = 1'b1;	// we are now ready to receive data
				while(M_AXIS_TLAST | ~M_AXIS_TLAST_prev) // receive data until the falling edge of M_AXIS_TLAST
				begin
					if(M_AXIS_TVALID)
					begin
						result_memory[word_cnt] = M_AXIS_TDATA;
						word_cnt = word_cnt+1;
					end
					#100;
				end						// receive loop
				M_AXIS_TREADY = 1'b0;	// not ready to receive data from the co-processor anymore.				
				
				// checking correctness of results
				for(word_cnt=0; word_cnt < 2*NUMBER_OF_OUTPUT_WORDS; word_cnt=word_cnt+1)
						success = success & (result_memory[word_cnt] == test_result_expected_memory[word_cnt]);
				if(success)
					$display("Test Passed.");
				else
					$display("Test Failed.");
               	
               $finish;       	
           end 

endmodule