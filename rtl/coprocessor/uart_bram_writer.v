`timescale 1ns / 1ps

module uart_bram_writer (
    input  wire clk,
    input  wire rst,
    
    // Interface from uart_rx
    input  wire [7:0] byte_in,
    input  wire       byte_valid,
    
    // Interface to input_bram
    output reg  [7:0]  bram_waddr,
    output reg  [31:0] bram_wdata,
    output reg         bram_we,
    
    // Signal to main FSM / CPU that a full image is ready
    output reg         transfer_complete
);

    // 784 bytes total = 196 words (since 196 * 4 = 784)
    localparam MAX_WORDS = 8'd196; 

    reg [1:0] byte_cnt; // Tracks 0, 1, 2, 3 for packing

    always @(posedge clk) begin
        if (rst) begin
            bram_waddr        <= 8'd0;
            bram_wdata        <= 32'd0;
            bram_we           <= 1'b0;
            transfer_complete <= 1'b0;
            byte_cnt          <= 2'd0;
        end else begin
            // Default to not writing unless a full word is packed
            bram_we           <= 1'b0;
            transfer_complete <= 1'b0;

            if (byte_valid) begin
                // Pack bytes in Little-Endian order
                case (byte_cnt)
                    2'd0: bram_wdata[7:0]   <= byte_in;
                    2'd1: bram_wdata[15:8]  <= byte_in;
                    2'd2: bram_wdata[23:16] <= byte_in;
                    2'd3: bram_wdata[31:24] <= byte_in;
                endcase
                
                if (byte_cnt == 2'd3) begin
                    // We have a full 32-bit word, write it to BRAM
                    bram_we <= 1'b1;
                    byte_cnt <= 2'd0;
                    
                    if (bram_waddr == (MAX_WORDS - 1)) begin
                        // Full image received
                        bram_waddr <= 8'd0; // Reset for the next image
                        transfer_complete <= 1'b1;
                    end else begin
                        bram_waddr <= bram_waddr + 1;
                    end
                end else begin
                    byte_cnt <= byte_cnt + 1;
                end
            end
        end
    end

endmodule