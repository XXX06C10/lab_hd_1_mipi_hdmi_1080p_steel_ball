`timescale 1ns/1ps
// Feed 4 known pixels per 96-bit word through the REAL ISP packer,
// print the 128-bit output words so we can see the exact byte layout.
module tb_packer;
reg clk=0; always #5 clk=~clk;
reg rst_n=0;
reg [95:0] w96;
reg v96, fs;
wire [127:0] o128;
wire ov128, ofs128;
data_96bit_to_128bit pk(
    .I_clk(clk), .I_rst_n(rst_n),
    .I_96b_frame_start(fs), .I_96b_valid(v96), .I_96b_data(w96),
    .O_128b_frame_start(ofs128), .O_128b_valid(ov128), .O_128b_data(o128)
);
// pixels: p0=R0,G0,B0 ... each 24-bit {R,G,B}
localparam [23:0] P0 = 24'h010203; // R=01 G=02 B=03
localparam [23:0] P1 = 24'h040506;
localparam [23:0] P2 = 24'h070809;
localparam [23:0] P3 = 24'h0A0B0C;
localparam [23:0] P4 = 24'h0D0E0F;
localparam [23:0] P5 = 24'h101112;
localparam [23:0] P6 = 24'h131415;
localparam [23:0] P7 = 24'h161718;
localparam [23:0] P8 = 24'h191A1B;
localparam [23:0] P9 = 24'h1C1D1E;
localparam [23:0] P10= 24'h1F2021;
localparam [23:0] P11= 24'h222324;
localparam [23:0] P12= 24'h252627;
localparam [23:0] P13= 24'h28292A;
localparam [23:0] P14= 24'h2B2C2D;
localparam [23:0] P15= 24'h2E2F30;
// 96-bit words, assume pixel0 = HIGH 24 bits first
reg [95:0] w0 = {P0,P1,P2,P3};
reg [95:0] w1 = {P4,P5,P6,P7};
reg [95:0] w2 = {P8,P9,P10,P11};
reg [95:0] w3 = {P12,P13,P14,P15};
initial begin
    rst_n=0; w96=0; v96=0; fs=0;
    repeat(3) @(posedge clk);
    rst_n=1; @(posedge clk);
    fs=1; w96=w0; v96=1; @(posedge clk);
    fs=0; w96=w1; v96=1; @(posedge clk);
    w96=w2; @(posedge clk);
    w96=w3; @(posedge clk);
    w96=0; v96=0;
    repeat(8) @(posedge clk);
    $finish;
end
always @(posedge clk) begin
    if(ov128) $display("t=%0t packer out = %h", $time, o128);
end
endmodule
