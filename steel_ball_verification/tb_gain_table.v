`timescale 1ns/1ps

module tb_gain_table;
reg clk = 0;
reg [6:0] index = 0;
wire [15:0] code;
integer n;
reg [7:0] high_byte;
reg [7:0] low_byte;
reg [15:0] expected;

always #5 clk = ~clk;

SC500GainTbl dut (
    .I_clk(clk),
    .I_rstn(1'b1),
    .I(index),
    .O(code)
);

initial begin
    for (n = 0; n < 128; n = n + 1) begin
        @(negedge clk);
        index = n;
        case (n / 32)
            0: high_byte = 8'h03;
            1: high_byte = 8'h07;
            2: high_byte = 8'h0f;
            3: high_byte = 8'h1f;
        endcase
        low_byte = 8'h20 + (n % 32);
        expected = {high_byte, low_byte};
        @(posedge clk);
        #1;
        if (code !== expected) $fatal(1, "FAIL index=%0d code=%h expected=%h", n, code, expected);
    end
    $display("PASS tb_gain_table");
    $finish;
end
endmodule
