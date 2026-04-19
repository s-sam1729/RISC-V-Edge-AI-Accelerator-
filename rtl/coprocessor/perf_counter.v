`timescale 1ns / 1ps

module perf_counter (
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire done,
    output reg  [31:0] cycle_count
);

    reg counting;

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 32'd0;
            counting    <= 1'b0;
        end else begin
            if (start) begin
                cycle_count <= 32'd0;
                counting    <= 1'b1;
            end else if (done) begin
                counting    <= 1'b0;
            end else if (counting) begin
                cycle_count <= cycle_count + 1;
            end
        end
    end

endmodule