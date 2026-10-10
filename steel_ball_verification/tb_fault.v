`timescale 1ns/1ps
module tb_fault;
reg clk=0,rst=0,valid=0,user=0,last=0;
reg [127:0] data=0;
always #5 clk=~clk;
wire fault,ball,done,hit,bright;
wire [1:0] error_code;
steel_ball_detect #(.FIFO_BITS(3),.IMG_WIDTH(64),.IMG_HEIGHT(48),
 .MIN_AREA(20),.CONFIRM_FRAMES(2)) dut(
 .I_clk(clk),.I_rst_n(rst),.S_AXIS_tdata(data),
 .S_AXIS_tvalid(valid),.S_AXIS_tuser(user),.S_AXIS_tlast(last),
 .M_AXIS_tdata(),.M_AXIS_tvalid(),.M_AXIS_tuser(),.M_AXIS_tlast(),
 .O_ball_detected(ball),.O_frame_done(done),.O_frame_hit(hit),.O_fault(fault),
 .O_bright(bright),.O_error_code(error_code));
integer y,x,b,words;
reg [1535:0] row;
task reset_dut;
 begin
  @(negedge clk);rst=0;valid=0;user=0;last=0;
  repeat(5) @(negedge clk);rst=1;
 end
endtask
task sof;
 begin
  @(negedge clk);user=1;
  @(negedge clk);user=0;
  repeat(600) @(negedge clk);
 end
endtask
// 0 blank, 1 circle, 2 isolated bright noise, 3 short first line.
task frame;
 input integer scene;
 begin
  if(scene!=4) sof;
  for(y=0;y<48;y=y+1) begin
   row=0;
   for(x=0;x<64;x=x+1) begin
    if(((scene==1 || scene==4) && (x-32)*(x-32)+(y-24)*(y-24)<=100) ||
       (scene==2 && x%4==0 && y%4==0)) row[1535-x*24 -:24]=24'hffffff;
   end
   words=(scene==3 && y==0)?3:12;
   for(b=0;b<words;b=b+1) begin
    @(negedge clk);data=row[1535-b*128 -:128];valid=1;user=(scene==4 && y==0 && b==0);
    @(negedge clk);valid=0;user=0;
    repeat(62) @(negedge clk);
   end
   last=1;@(negedge clk);last=0;
   repeat(80) @(negedge clk);
  end
 end
endtask
task overflow;
 begin
  @(negedge clk);user=1;valid=1;data={128{1'b1}};
  @(negedge clk);user=0;
  repeat(100) @(negedge clk);
  if(!fault || ball || error_code!=1) $fatal(1,"overflow must fail closed and report code 1");
  valid=0;repeat(100) @(negedge clk);
  if(!fault || done) $fatal(1,"wait for a new SOF after overflow");
 end
endtask
initial begin
 reset_dut;
 overflow;
 frame(4); // SOF coincident with valid must preserve those first five pixels
 if(fault || ball) $fatal(1,"automatic SOF recovery failed");
 frame(1);
 if(ball || !hit || !bright) $fatal(1,"first recovered frame must not complete confirmation");
 sof;
 if(!ball || !hit || fault || error_code!=1) $fatal(1,"recovered circle/confirmation/history failed");
 overflow;
 frame(0);sof;
 if(ball || hit || fault || bright) $fatal(1,"blank after overflow retained stale evidence");
 reset_dut;
 frame(2);sof;
 if(error_code!=2 || ball || !bright) $fatal(1,"label exhaustion diagnostic failed: %d",error_code);
 reset_dut;
 frame(3);sof;
 if(error_code!=3 || ball || bright) $fatal(1,"geometry diagnostic failed: %d",error_code);
 reset_dut;
 if(error_code || ball || fault || bright) $fatal(1,"reset failed");
 $display("PASS overflow -> SOF recovery without reset, fresh confirmation, repeated overflow, blank recovery, brightness, label/geometry diagnostics, reset");
 $finish;
end
initial begin #20000000; $fatal(1,"timeout"); end
endmodule
