`timescale 1ns / 1ps

module seven_seg_controller #(
    parameter REFRESH_COUNT = 100_000 
)(
    input  wire clk,
    input  wire rst,
    input  wire [3:0] digit,         
    output reg  [7:0] seg_anode,      
    output reg  [6:0] seg_cathode   
);

    reg [16:0] refresh_counter;
    reg [2:0]  active_digit; // 8 digits (0-7)

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

    always @(*) begin
        seg_anode = 8'hFF;
        seg_cathode = pattern_blank;
        case (active_digit)
            3'd0: begin seg_anode = 8'b11111110; seg_cathode = pattern_num;   end // Rightmost
            3'd1: begin seg_anode = 8'b11111101; seg_cathode = pattern_blank; end 
            3'd2: begin seg_anode = 8'b11111011; seg_cathode = pattern_blank; end 
            3'd3: begin seg_anode = 8'b11110111; seg_cathode = pattern_blank; end 
            3'd4: begin seg_anode = 8'b11101111; seg_cathode = pattern_blank; end 
            3'd5: begin seg_anode = 8'b11011111; seg_cathode = pattern_blank; end 
            3'd6: begin seg_anode = 8'b10111111; seg_cathode = pattern_blank; end 
            3'd7: begin seg_anode = 8'b01111111; seg_cathode = pattern_d;     end // Leftmost
        endcase
    end

endmodule
