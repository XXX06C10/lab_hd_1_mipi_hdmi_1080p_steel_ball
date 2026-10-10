`timescale 1ns/1ps

module tb_ae_buttons;
reg clk = 0;
reg rst = 1;
reg [3:0] btn = 4'hf;
wire req;
wire [15:0] ae;
wire [15:0] ag;
integer req_count = 0;

always #5 clk = ~clk;
always @(posedge clk) if (req) req_count = req_count + 1;

ae_set dut (
    .I_clk(clk),
    .I_rst(rst),
    .I_btn(btn),
    .I_ae_cfg_done(1'b1),
    .I_cam_cfg_done(1'b1),
    .O_ae_req(req),
    .O_ae(ae),
    .O_ag(ag)
);

task press;
    input integer key;
    begin
        @(negedge clk);
        btn[key] = 0;
        repeat (8) @(negedge clk);
        btn[key] = 1;
        repeat (8) @(negedge clk);
    end
endtask

task check;
    input [15:0] expected_ae;
    input [15:0] expected_ag;
    begin
        if (ae !== expected_ae || ag !== expected_ag) begin
            $display("FAIL ae=%0d ag=%0d expected ae=%0d ag=%0d", ae, ag, expected_ae, expected_ag);
            $fatal(1);
        end
    end
endtask

initial begin
    repeat (4) @(negedge clk);
    rst = 0;
    repeat (4) @(negedge clk);
    check(2246, 80);
    press(0);
    check(2245, 80);
    press(1);
    check(2246, 80);
    press(2);
    check(2246, 79);
    press(3);
    check(2246, 80);
    if (req_count !== 4) $fatal(1, "FAIL req_count=%0d", req_count);
    @(negedge clk);
    dut.r_ag_set = 142;
    repeat (8) @(negedge clk);
    check(2246, 142);
    press(3);
    check(2246, 143);
    press(3);
    check(2246, 143);
    $display("PASS tb_ae_buttons");
    $finish;
end
endmodule
