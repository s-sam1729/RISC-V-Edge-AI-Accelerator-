`timescale 1ns / 1ps

module led_controller (
    input  wire signed [31:0] max_score,
    output reg  [15:0] led_out
);

    reg [4:0] scaled_count;

    always @(*) begin
        if (max_score <= 0) begin
            scaled_count = 0;
        end else begin
            // Shift the score down to a 0-16 scale. 
            // 12 is chosen as a heuristic for the L2 logit range.
            scaled_count = max_score[12:8]; 
            
            if (scaled_count > 16) begin
                scaled_count = 16;
            end
        end
        
        led_out = ~(16'hFFFF << scaled_count);
    end

endmodule
