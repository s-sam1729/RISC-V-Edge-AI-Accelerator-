`timescale 1ns / 1ps

module coprocessor_top (
    input  wire clk,
    input  wire rst,

    // CPU MMIO Interface (from top_fpga.v)
    // Note: cop_addr is now 24 bits to allow addressing large BRAMs
    input  wire [23:0] cop_addr,    
    input  wire [31:0] cop_wdata,
    input  wire        cop_we,
    input  wire        cop_re,
    output reg  [31:0] cop_rdata,
    output wire        cop_busy,
    output reg         cop_done,

    // UART Direct BRAM Write Path (for live demo)
    input  wire [7:0]  uart_byte,
    input  wire        uart_byte_valid,

    // Display Outputs
    output wire [3:0]  class_index,
    output wire [31:0] logit_scores [0:9] // Flattened in actual implementation if needed
);

    // =========================================================================
    // 1. Internal Memory Map Decoding (Offset from 0xC000_0000)
    // =========================================================================
    // 0x00_0000 - 0x00_00FF : Control Registers
    // 0x01_0000 - 0x01_FFFF : Weight BRAM
    // 0x02_0000 - 0x02_0FFF : Input BRAM
    // 0x03_0000 - 0x03_0FFF : Output BRAM
    // 0x04_0000 - 0x04_0FFF : Bias BRAM

    wire is_csr    = (cop_addr[23:16] == 8'h00);
    wire is_weight = (cop_addr[23:16] == 8'h01);
    wire is_input  = (cop_addr[23:16] == 8'h02);
    wire is_output = (cop_addr[23:16] == 8'h03);
    wire is_bias   = (cop_addr[23:16] == 8'h04);

    // =========================================================================
    // 2. Control Registers (CSRs)
    // =========================================================================
    reg [31:0] in_base, wt_base, out_base, bias_base;
    reg [31:0] layer_rows, layer_cols;
    reg        start_reg;
    wire [31:0] cycle_count; // From perf_counter module

    // CSR Write Logic
    always @(posedge clk) begin
        if (rst) begin
            start_reg  <= 1'b0;
            in_base    <= 0;
            wt_base    <= 0;
            out_base   <= 0;
            bias_base  <= 0;
            layer_rows <= 0;
            layer_cols <= 0;
        end else begin
            start_reg <= 1'b0; // Auto-clears after 1 cycle
            
            if (cop_we && is_csr) begin
                case (cop_addr[7:0])
                    8'h00: start_reg  <= cop_wdata[0];
                    8'h08: in_base    <= cop_wdata;
                    8'h0C: wt_base    <= cop_wdata;
                    8'h10: out_base   <= cop_wdata;
                    8'h14: layer_rows <= cop_wdata;
                    8'h18: layer_cols <= cop_wdata;
                    8'h1C: bias_base  <= cop_wdata;
                endcase
            end
        end
    end

    // CSR Read Logic (Multiplexer back to CPU)
    always @(*) begin
        cop_rdata = 32'd0;
        if (is_csr) begin
            case (cop_addr[7:0])
                8'h00: cop_rdata = {31'd0, start_reg};
                8'h04: cop_rdata = {30'd0, cop_done, cop_busy};
                8'h08: cop_rdata = in_base;
                8'h0C: cop_rdata = wt_base;
                8'h10: cop_rdata = out_base;
                8'h14: cop_rdata = layer_rows;
                8'h18: cop_rdata = layer_cols;
                8'h1C: cop_rdata = bias_base;
                8'h20: cop_rdata = cycle_count;
            endcase
        end 
        // Note: Add BRAM read routing here later if CPU needs to read BRAMs directly
    end

    // =========================================================================
    // 3. Sub-Module Instantiations (Placeholders to wire up)
    // =========================================================================
    
    wire mac_start, mac_done, mac_busy;
    wire [63:0] vec_a_bus, vec_b_bus; // 8 lanes * 8 bits
    wire signed [31:0] mac_bias, mac_result;

    vec_mac_engine #(.LANES(8)) u_mac (
        .clk(clk),
        .rst(rst),
        .start(mac_start),
        .vec_a(vec_a_bus),
        .vec_b(vec_b_bus),
        .bias(mac_bias),
        .n_elements(layer_cols[15:0]),
        .result(mac_result),
        .done(mac_done),
        .busy(mac_busy)
    );

    // TODO: Instantiate weight_bram, input_bram, output_bram, bias_bram here
    // TODO: Instantiate perf_counter here
    // TODO: Instantiate argmax_tree here (reading from output_bram)

    // =========================================================================
    // 4. Coprocessor Master FSM
    // =========================================================================
    // This FSM sequences the vec_mac_engine across the 'layer_rows' (neurons).
    // For a 128-neuron layer, this FSM will trigger the mac_engine 128 times,
    // feeding it the correct addresses for BRAM reads every cycle.
    
    localparam S_IDLE       = 3'd0;
    localparam S_INIT_MAC   = 3'd1;
    localparam S_FEED_MAC   = 3'd2;
    localparam S_WAIT_MAC   = 3'd3;
    localparam S_STORE_OUT  = 3'd4;
    localparam S_DONE       = 3'd5;

    reg [2:0] state;
    reg [31:0] current_row;

    assign cop_busy = (state != S_IDLE);
    assign mac_start = (state == S_INIT_MAC);

    always @(posedge clk) begin
        if (rst) begin
            state <= S_IDLE;
            cop_done <= 1'b0;
            current_row <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    cop_done <= 1'b0;
                    if (start_reg) begin
                        current_row <= 0;
                        state <= S_INIT_MAC;
                    end
                end

                S_INIT_MAC: begin
                    // mac_start pulses high this cycle
                    // Set up BRAM read pointers for the new row here
                    state <= S_FEED_MAC;
                end

                S_FEED_MAC: begin
                    // Every cycle, increment BRAM read addresses to feed 
                    // vec_a_bus and vec_b_bus.
                    // When BRAM pointers reach layer_cols, move to WAIT
                    // (Implementation depends on BRAM latency)
                    state <= S_WAIT_MAC; // Placeholder transition
                end

                S_WAIT_MAC: begin
                    if (mac_done) begin
                        state <= S_STORE_OUT;
                    end
                end

                S_STORE_OUT: begin
                    // Write mac_result into output_bram[out_base + current_row]
                    current_row <= current_row + 1;
                    
                    if (current_row + 1 >= layer_rows) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_INIT_MAC; // Process next neuron
                    end
                end

                S_DONE: begin
                    cop_done <= 1'b1;
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule