`timescale 1ns / 1ps

module argmax_tree (
    input  wire clk,
    input  wire rst,
    input  wire [319:0] packed_scores, 
    
    output reg  [3:0]  class_index,
    output reg  signed [31:0] max_score
);

    wire signed [31:0] s [0:9];
    genvar i;
    generate
        for (i = 0; i < 10; i = i + 1) begin : UNPACK
            assign s[i] = $signed(packed_scores[(i*32) +: 32]);
        end
    endgenerate

    // --- PIPELINE STAGE 1 ---
    reg signed [31:0] w1_01, w1_23, w1_45, w1_67, w1_89;
    reg [3:0] i1_01, i1_23, i1_45, i1_67, i1_89;

    always @(posedge clk) begin
        if (rst) begin
            w1_01 <= 0; i1_01 <= 0; w1_23 <= 0; i1_23 <= 0;
            w1_45 <= 0; i1_45 <= 0; w1_67 <= 0; i1_67 <= 0;
            w1_89 <= 0; i1_89 <= 0;
        end else begin
            if (s[0] >= s[1]) begin w1_01 <= s[0]; i1_01 <= 4'd0; end else begin w1_01 <= s[1]; i1_01 <= 4'd1; end
            if (s[2] >= s[3]) begin w1_23 <= s[2]; i1_23 <= 4'd2; end else begin w1_23 <= s[3]; i1_23 <= 4'd3; end
            if (s[4] >= s[5]) begin w1_45 <= s[4]; i1_45 <= 4'd4; end else begin w1_45 <= s[5]; i1_45 <= 4'd5; end
            if (s[6] >= s[7]) begin w1_67 <= s[6]; i1_67 <= 4'd6; end else begin w1_67 <= s[7]; i1_67 <= 4'd7; end
            if (s[8] >= s[9]) begin w1_89 <= s[8]; i1_89 <= 4'd8; end else begin w1_89 <= s[9]; i1_89 <= 4'd9; end
        end
    end

    // --- PIPELINE STAGE 2 ---
    reg signed [31:0] w2_03, w2_47;
    reg [3:0] i2_03, i2_47;
    reg signed [31:0] w2_89;
    reg [3:0] i2_89;

    always @(posedge clk) begin
        if (rst) begin
            w2_03 <= 0; i2_03 <= 0; w2_47 <= 0; i2_47 <= 0; w2_89 <= 0; i2_89 <= 0;
        end else begin
            if (w1_01 >= w1_23) begin w2_03 <= w1_01; i2_03 <= i1_01; end else begin w2_03 <= w1_23; i2_03 <= i1_23; end
            if (w1_45 >= w1_67) begin w2_47 <= w1_45; i2_47 <= i1_45; end else begin w2_47 <= w1_67; i2_47 <= i1_67; end
            w2_89 <= w1_89; i2_89 <= i1_89;
        end
    end

    // --- PIPELINE STAGE 3 ---
    reg signed [31:0] w3_07;
    reg [3:0] i3_07;
    reg signed [31:0] w3_89;
    reg [3:0] i3_89;

    always @(posedge clk) begin
        if (rst) begin
            w3_07 <= 0; i3_07 <= 0; w3_89 <= 0; i3_89 <= 0;
        end else begin
            if (w2_03 >= w2_47) begin w3_07 <= w2_03; i3_07 <= i2_03; end else begin w3_07 <= w2_47; i3_07 <= i2_47; end
            w3_89 <= w2_89; i3_89 <= i2_89;
        end
    end

    // --- FINAL STAGE ---
    always @(posedge clk) begin
        if (rst) begin
            max_score <= 0;
            class_index <= 0;
        end else begin
            if (w3_07 >= w3_89) begin 
                max_score <= w3_07; 
                class_index <= i3_07; 
            end else begin 
                max_score <= w3_89; 
                class_index <= i3_89; 
            end
        end
    end

endmodule
