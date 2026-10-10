`timescale 1ns/1ps
`include "vector_config.vh"
module tb_steel_ball;
reg clk=0,rst=0;
always #5 clk=~clk;
reg [127:0] data=0;
reg valid=0,user=0,last=0;
wire [127:0] md;
wire mv,mu,ml,ball,done,hit,fault;
steel_ball_detect #(.IMG_WIDTH(64),.IMG_HEIGHT(48),.MIN_AREA(20),.MAX_AREA(2000)) dut(
 .I_clk(clk),.I_rst_n(rst),.S_AXIS_tdata(data),.S_AXIS_tvalid(valid),
 .S_AXIS_tuser(user),.S_AXIS_tlast(last),.M_AXIS_tdata(md),.M_AXIS_tvalid(mv),
 .M_AXIS_tuser(mu),.M_AXIS_tlast(ml),.O_ball_detected(ball),
 .O_frame_done(done),.O_frame_hit(hit),.O_fault(fault));
reg [130:0] vectors[0:`NCLOCKS-1];
reg [3:0] gold[0:`NFRAMES-1];
reg [89:0] expected[0:`NFRAMES*64-1];
integer i,f=0,j,k,n,m;
reg found;
always @(negedge clk) if(rst && done) begin
 if(f>=`NFRAMES) $fatal(1,"extra frame");
 if({hit,ball,1'b0}!==gold[f][2:0] || fault) $fatal(1,"frame %0d result hit=%b ball=%b fault=%b expected=%x bad=%b lines=%d",f,hit,ball,fault,gold[f],dut.bad_frame,dut.lines);
 if(!gold[f][3]) begin
  n=0;m=0;
  for(j=1;j<64;j=j+1) if(j<dut.next_label && dut.parent[j]==j) begin
   n=n+1;found=0;
   for(k=0;k<64;k=k+1) if(dut.stats[j]===expected[f*64+k]) found=1;
   if(!found) $fatal(1,"frame %0d unexpected stats label %0d: %h",f,j,dut.stats[j]);
  end
  for(k=0;k<64;k=k+1) if(expected[f*64+k]!=0) m=m+1;
  if(n!=m) $fatal(1,"frame %0d component count %0d expected %0d",f,n,m);
 end
 $display("PASS frame %0d hit=%b LED=%b components=%0d",f,hit,ball,n);
 f=f+1;
end
initial begin
 $readmemh("vectors.hex",vectors);$readmemh("golden.hex",gold);$readmemh("stats.hex",expected);
 repeat(4) @(negedge clk); rst=1;
 for(i=0;i<`NCLOCKS;i=i+1) begin
  @(negedge clk); {data,valid,user,last}=vectors[i];
  #1;
  if({md,mv,mu,ml}!=={data,valid,user,last}) $fatal(1,"mirror altered at clock %0d",i);
 end
 if(f!=`NFRAMES) $fatal(1,"missing frames: %0d",f);
 rst=0;#1;
 if(ball!==0) $fatal(1,"asynchronous reset");
 $display("ALL PASS: packed RGB, grayscale, exact CCL area/perimeter/bbox, merge, borders, debounce, overflow, mirror, reset");
 $finish;
end
endmodule
