`timescale 1ns / 1ps

module tb_vec_mac_engine;

    // Inputs
    reg clk;
    reg rst;
    reg start;
    reg [31:0] vec_a; // 4 lanes * 8 bits
    reg [31:0] vec_b;
    reg signed [31:0] bias;
    reg [15:0] n_elements;

    // Outputs
    wire signed [31:0] result;
    wire done;
    wire busy;

    // Instantiate the Unit Under Test (UUT)
    vec_mac_engine #(.LANES(4)) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .vec_a(vec_a),
        .vec_b(vec_b),
        .bias(bias),
        .n_elements(n_elements),
        .result(result),
        .done(done),
        .busy(busy)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 1;
        start = 0;
        vec_a = 0;
        vec_b = 0;
        bias = 0;
        n_elements = 8; // We will process 8 elements total (takes 2 cycles)

        // Wait 100 ns for global reset to finish
        #100;
        rst = 0;
        #20;

        // --- TEST CASE 1: Positive Accumulation ---
        // Cycle 1: Feed first 4 elements
        // a = [1, 2, 3, 4], b = [2, 2, 2, 2] -> Dot = 2+4+6+8 = 20
        vec_a = {8'd4, 8'd3, 8'd2, 8'd1};
        vec_b = {8'd2, 8'd2, 8'd2, 8'd2};
        bias = 32'd5;
        start = 1;
        #10 start = 0; // De-assert start
        
        // Cycle 2: Feed next 4 elements
        // a = [-1, 0, 1, 1], b = [1, 1, 1, 1] -> Dot = -1+0+1+1 = 1
        vec_a = {8'd1, 8'd1, 8'd0, -8'd1};
        vec_b = {8'd1, 8'd1, 8'd1, 8'd1};
        
        // Wait for computation to finish
        wait(done == 1'b1);
        
        // Expected Result: 20 + 1 + 5 (bias) = 26
        if (result === 32'd26)
            $display("Test 1 Passed: Result = %d", result);
        else
            $display("Test 1 FAILED: Expected 26, Got %d", result);

        #20;

        // --- TEST CASE 2: ReLU Clamping (Negative Result) ---
        vec_a = {-8'd10, -8'd10, -8'd10, -8'd10}; // -40
        vec_b = {8'd1, 8'd1, 8'd1, 8'd1};
        bias = -32'd5;
        n_elements = 4; // Only 1 cycle needed
        start = 1;
        #10 start = 0;
        
        wait(done == 1'b1);
        
        // Expected Result: -40 - 5 = -45. Clamped by ReLU to 0.
        if (result === 32'd0)
            $display("Test 2 Passed (ReLU Clamp): Result = %d", result);
        else
            $display("Test 2 FAILED: Expected 0, Got %d", result);

        #50;
        $finish;
    end

endmodule