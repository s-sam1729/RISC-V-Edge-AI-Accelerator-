`timescale 1ns / 1ps

module seven_seg_controller #(
    // Assuming 100MHz input clock. 100,000 cycles = 1ms (1kHz refresh)
    parameter REFRESH_COUNT = 100_000 
)(
    input  wire clk,
    input  wire rst,
    input  wire [3:0] digit,         // The winning class (0-9)
    output reg  [6:0] seg_cathode,   // Active LOW typically
    output reg  [3:0] seg_anode      // Active LOW typically
);

    reg [16:0] refresh_counter;
    reg [1:0]  active_digit;

    // Refresh Counter
    always @(posedge clk) begin
        if (rst) begin
            refresh_counter <= 0;
            active_digit <= 0;
        end else begin
            if (refresh_counter >= REFRESH_COUNT - 1) begin
                refresh_counter <= 0;
                active_digit <= active_digit + 1;
            end else begin
                refresh_counter <= refresh_counter + 1;
            end
        end
    end

    // Cathode patterns (Active Low for standard Common Anode displays)
    // Pattern: {g, f, e, d, c, b, a}
    wire [6:0] pattern_d = 7'b0100001; // Letter 'd'
    wire [6:0] pattern_blank = 7'b1111111; // All OFF
    reg  [6:0] pattern_num;

    always @(*) begin
        case (digit)
            4'd0: pattern_num = 7'b1000000;
            4'd1: pattern_num = 7'b1111001;
            4'd2: pattern_num = 7'b0100100;
            4'd3: pattern_num = 7'b0110000;
            4'd4: pattern_num = 7'b0011001;
            4'd5: pattern_num = 7'b0010010;
            4'd6: pattern_num = 7'b0000010;
            4'd7: pattern_num = 7'b1111000;
            4'd8: pattern_num = 7'b0000000;
            4'd9: pattern_num = 7'b0010000;
            default: pattern_num = 7'b1111111;
        endcase
    end

    // Multiplexer
    always @(*) begin
        case (active_digit)
            2'b00: begin seg_anode = 4'b0111; seg_cathode = pattern_d;     end // Leftmost: 'd'
            2'b01: begin seg_anode = 4'b1011; seg_cathode = pattern_blank; end // Blank
            2'b10: begin seg_anode = 4'b1101; seg_cathode = pattern_blank; end // Blank
            2'b11: begin seg_anode = 4'b1110; seg_cathode = pattern_num;   end // Rightmost: Number
        endcase
    end

endmodule