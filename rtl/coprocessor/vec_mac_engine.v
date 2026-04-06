`timescale 1ns / 1ps

module vec_mac_engine #(
    parameter LANES = 8
) (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire [8*LANES-1:0] vec_a,     // 8 packed INT8 activations
    input  wire [8*LANES-1:0] vec_b,     // 8 packed INT8 weights
    input  wire signed [31:0] bias,      // INT32 bias
    input  wire [15:0] n_elements,       // Total vector length (must be multiple of LANES)
    
    output reg  signed [31:0] result,
    output reg  done,
    output reg  busy
);

    // --------------------------------------------------------
    // 1. Unpacking the wide buses into signed INT8 arrays
    // --------------------------------------------------------
    wire signed [7:0] a_unpacked [0:LANES-1];
    wire signed [7:0] b_unpacked [0:LANES-1];
    
    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : UNPACK_BLOCK
            // Extract each 8-bit chunk and cast as signed
            assign a_unpacked[i] = $signed(vec_a[(i*8) +: 8]);
            assign b_unpacked[i] = $signed(vec_b[(i*8) +: 8]);
        end
    endgenerate

    // --------------------------------------------------------
    // 2. Combinational Sum of Products (8 lanes)
    // --------------------------------------------------------
    reg signed [31:0] sum_of_products;
    integer j;
    
    always @(*) begin
        sum_of_products = 0;
        // Vivado will map this loop to a parallel DSP tree
        for (j = 0; j < LANES; j = j + 1) begin
            sum_of_products = sum_of_products + (a_unpacked[j] * b_unpacked[j]);
        end
    end

    // --------------------------------------------------------
    // 3. Finite State Machine & Accumulator
    // --------------------------------------------------------
    localparam STATE_IDLE      = 2'b00;
    localparam STATE_COMPUTE   = 2'b01;
    localparam STATE_BIAS_RELU = 2'b10;
    localparam STATE_DONE      = 2'b11;

    reg [1:0] state, next_state;
    reg signed [31:0] acc;
    reg [15:0] count;
    reg signed [31:0] final_biased_val;

    // FSM Sequential Logic
    always @(posedge clk) begin
        if (rst) begin
            state   <= STATE_IDLE;
            acc     <= 32'd0;
            count   <= 16'd0;
            result  <= 32'd0;
            done    <= 1'b0;
            busy    <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy  <= 1'b1;
                        acc   <= 32'd0;
                        count <= 16'd0;
                        state <= STATE_COMPUTE;
                    end
                end

                STATE_COMPUTE: begin
                    acc   <= acc + sum_of_products;
                    count <= count + LANES;
                    
                    // Check if we have processed all elements
                    // (Assumes n_elements is a multiple of LANES)
                    if ((count + LANES) >= n_elements) begin
                        state <= STATE_BIAS_RELU;
                    end
                end

                STATE_BIAS_RELU: begin
                    // Fused Bias Addition
                    final_biased_val = acc + bias;
                    
                    // Fused ReLU Activation: if val < 0, clamp to 0
                    if (final_biased_val < 0) begin
                        result <= 32'd0;
                    end else begin
                        result <= final_biased_val;
                    end
                    
                    state <= STATE_DONE;
                end

                STATE_DONE: begin
                    done  <= 1'b1;
                    busy  <= 1'b0;
                    state <= STATE_IDLE;
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule