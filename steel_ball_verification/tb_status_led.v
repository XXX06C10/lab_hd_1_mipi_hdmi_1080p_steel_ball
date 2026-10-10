`timescale 1ns/1ps
module tb_status_led;
reg clk=0,rst=0,sof=0;
reg [1:0] code=0;
wire heartbeat,error_led;
always #5 clk=~clk;
steel_ball_status_led #(.TICK_CYCLES(2),.HEARTBEAT_FRAMES(3)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_sof(sof),.I_error_code(code),
 .O_heartbeat(heartbeat),.O_error_led(error_led));
integer i,j,highs;
initial begin
 repeat(3) @(negedge clk);rst=1;
 for(i=0;i<3;i=i+1) begin
  sof=1;repeat(5) @(negedge clk);sof=0;repeat(5) @(negedge clk);
  if(heartbeat!==(i==2)) $fatal(1,"SOF edge count failed");
 end
 for(i=0;i<4;i=i+1) begin
  code=i;
  repeat(80) @(negedge clk);
  highs=0;
  for(j=0;j<40;j=j+1) begin @(negedge clk);highs=highs+error_led; end
  if(highs!=i*2) $fatal(1,"error blink count %d != %d",highs,i*2);
 end
 rst=0;#1;if(heartbeat || error_led) $fatal(1,"LED reset failed");
 $display("PASS heartbeat SOF edge count, all 4 error codes and reset");$finish;
end
endmodule
