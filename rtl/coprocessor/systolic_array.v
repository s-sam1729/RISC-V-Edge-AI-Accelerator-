`timescale 1ns / 1ps

module systolic_array #(
    parameter N_ROWS = 8,  // Number of neurons processing at once
    parameter N_COLS = 8   // Number of vector elements processed at once
)(
    input  wire clk,
    input  wire rst,
    
    // Flat packed inputs from BRAMs
    input  wire [8*N_ROWS-1:0] vec_a, // Activations
    input  wire [8*N_COLS-1:0] vec_b, // Weights
    
    // Flat packed outputs (bottom of the columns)
    output wire [32*N_COLS-1:0] result_vector
);

    // -------------------------------------------------------------
    // 1. Unpacking and Skewing (Delaying) Inputs
    // -------------------------------------------------------------
    // In a systolic array, row 'i' must be delayed by 'i' cycles.
    // Col 'j' must be delayed by 'j' cycles.
    
    wire signed [7:0] a_skewed [0:N_ROWS-1];
    wire signed [7:0] b_skewed [0:N_COLS-1];
    
    genvar i, j;
    generate
        // Skew Activations (Rows)
        for (i = 0; i < N_ROWS; i = i + 1) begin : A_SKEW
            reg signed [7:0] a_delay [0:i]; 
            integer d;
            always @(posedge clk) begin
                a_delay[0] <= $signed(vec_a[(i*8) +: 8]);
                for (d = 1; d <= i; d = d + 1) begin
                    a_delay[d] <= a_delay[d-1];
                end
            end
            assign a_skewed[i] = (i == 0) ? $signed(vec_a[(i*8) +: 8]) : a_delay[i-1];
        end
        
        // Skew Weights (Cols)
        for (j = 0; j < N_COLS; j = j + 1) begin : B_SKEW
            reg signed [7:0] b_delay [0:j];
            integer d;
            always @(posedge clk) begin
                b_delay[0] <= $signed(vec_b[(j*8) +: 8]);
                for (d = 1; d <= j; d = d + 1) begin
                    b_delay[d] <= b_delay[d-1];
                end
            end
            assign b_skewed[j] = (j == 0) ? $signed(vec_b[(j*8) +: 8]) : b_delay[j-1];
        end
    endgenerate

    // -------------------------------------------------------------
    // 2. The PE Grid Generation
    // -------------------------------------------------------------
    wire signed [7:0]  a_wire [0:N_ROWS-1][0:N_COLS];   // [row][col]
    wire signed [7:0]  b_wire [0:N_ROWS][0:N_COLS-1];   // [row][col]
    wire signed [31:0] acc_wire [0:N_ROWS][0:N_COLS-1]; // [row][col]

    generate
        for (i = 0; i < N_ROWS; i = i + 1) begin : ROW
            // Map the skewed inputs to the edges of the grid
            assign a_wire[i][0] = a_skewed[i];
            
            for (j = 0; j < N_COLS; j = j + 1) begin : COL
                // Map the skewed weights and initial zero accumulators to the top
                if (i == 0) begin
                    assign b_wire[0][j] = b_skewed[j];
                    assign acc_wire[0][j] = 32'd0;
                end
                
                pe u_pe (
                    .clk    (clk),
                    .rst    (rst),
                    .a_in   (a_wire[i][j]),       // Comes from left
                    .b_in   (b_wire[i][j]),       // Comes from top
                    .acc_in (acc_wire[i][j]),     // Comes from top
                    
                    .a_out  (a_wire[i][j+1]),     // Goes right
                    .b_out  (b_wire[i+1][j]),     // Goes down
                    .acc_out(acc_wire[i+1][j])    // Goes down
                );
            end
        end
    endgenerate

    // -------------------------------------------------------------
    // 3. Packing the Output
    // -------------------------------------------------------------
    generate
        for (j = 0; j < N_COLS; j = j + 1) begin : PACK_OUT
            // The final results emerge from the bottom of the array
            assign result_vector[(j*32) +: 32] = acc_wire[N_ROWS][j];
        end
    endgenerate

endmodule