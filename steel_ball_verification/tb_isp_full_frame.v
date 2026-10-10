`timescale 1ns/1ps
module tb_isp_full_frame;
reg clk=0,rst=0;
always #4.444 clk=~clk;
reg [95:0] rgb=0;
reg valid=0,sof=0,last=0;
wire [127:0] packed_rgb;
wire pv,pu,ball,done,hit,fault;
data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),
 .I_96b_frame_start(sof),.I_96b_valid(valid),.I_96b_data(rgb),
 .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_rgb));
steel_ball_detect #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.CONFIRM_FRAMES(1)) dut(.I_clk(clk),.I_rst_n(rst),
 .S_AXIS_tdata(packed_rgb),.S_AXIS_tvalid(pv),.S_AXIS_tuser(pu),.S_AXIS_tlast(last),
 .M_AXIS_tdata(),.M_AXIS_tvalid(),.M_AXIS_tuser(),.M_AXIS_tlast(),
 .O_ball_detected(ball),.O_frame_done(done),.O_frame_hit(hit),.O_fault(fault));
integer y,g,k,x,cycles=0,peak=0;
wire [12:0] occupancy=dut.wp-dut.rp;
always @(posedge clk) begin
 cycles=cycles+1;
 if(occupancy>peak) peak=occupancy;
 if(fault) $fatal(1,"FIFO overflow at cycle %0d",cycles);
 if(cycles>9000000) $fatal(1,"timeout");
end
initial begin
 repeat(5) @(negedge clk);rst=1;sof=1;
 @(negedge clk);sof=0;
 repeat(60) @(negedge clk);
 for(y=0;y<1080;y=y+1) begin
  for(g=0;g<480;g=g+1) begin
   @(negedge clk); valid=1;last=(g==479);
   for(k=0;k<4;k=k+1) begin
    x=g*4+k;
    rgb[95-k*24 -: 24]=((x-1800)*(x-1800)+(y-1040)*(y-1040)<=900)?24'hffffff:24'h000000;
   end
  end
  @(negedge clk);valid=0;last=0;
  repeat(2819) @(negedge clk); // 3300 clocks/line; 112.5 MHz / (3300*1127) is about 30.25 fps
 end
 repeat(100000) @(negedge clk);
 sof=1;@(negedge clk);sof=0;
 wait(done);#1;
 if(!ball || !hit || dut.bad_frame || dut.lines!=1080) $fatal(1,"full frame failed hit=%b bad=%b lines=%0d",hit,dut.bad_frame,dut.lines);
 if(dut.stats[1][89:68]!=2821 || dut.stats[1][67:44]!=244) $fatal(1,"incorrect full-frame geometry %h",dut.stats[1]);
 if(!dut.box_valid || dut.box_left!=1767 || dut.box_right!=1833 || dut.box_top!=1007 || dut.box_bottom!=1073)
  $fatal(1,"incorrect box valid=%b bounds=%0d,%0d,%0d,%0d",dut.box_valid,dut.box_left,dut.box_right,dut.box_top,dut.box_bottom);
 $display("PASS actual ISP packer 1920x1080: area=2821 perimeter=244, center=(1800,1040); peak FIFO=%0d/4096, cycles=%0d",peak,cycles);
 $finish;
end
endmodule
