`timescale 1ns/1ps
module tb_red_box_1080p;
reg clk=0,rst=0;
always #4.444 clk=~clk;
reg [95:0] rgb=0;
reg valid=0,sof=0,last=0;
wire [127:0] packed_rgb;
wire pv,pu,ball,done,hit,fault,box_video_valid;
wire [127:0] box_video;
data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),
 .I_96b_frame_start(sof),.I_96b_valid(valid),.I_96b_data(rgb),
 .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_rgb));
steel_ball_detect #(.IMG_WIDTH(1920),.IMG_HEIGHT(1080),.CONFIRM_FRAMES(1),
 .COLOR_MODE(1),.COLOR_MIN(60),.COLOR_RATIO_LOG2(1),
 .OVERLAY_EN(1),.OVERLAY_BOX(1),.BOX_COLOR(24'h00ff00),
 .BOX_MARGIN(3),.BOX_THICKNESS(2)) dut(.I_clk(clk),.I_rst_n(rst),
 .S_AXIS_tdata(packed_rgb),.S_AXIS_tvalid(pv),.S_AXIS_tuser(pu),.S_AXIS_tlast(last),
 .M_AXIS_tdata(box_video),.M_AXIS_tvalid(box_video_valid),.M_AXIS_tuser(),.M_AXIS_tlast(),
 .O_ball_detected(ball),.O_frame_done(done),.O_frame_hit(hit),.O_fault(fault),
 .O_bright(),.O_error_code());
integer y,g,k,x,cycles=0;
always @(posedge clk) begin
 cycles=cycles+1;
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
    rgb[95-k*24 -: 24]=((x-960)*(x-960)+(y-540)*(y-540)<=900)?24'hc81e1e:24'h101820;
   end
  end
  @(negedge clk);valid=0;last=0;
  repeat(2819) @(negedge clk);
 end
 repeat(100000) @(negedge clk);
 sof=1;@(negedge clk);sof=0;
 wait(done);#1;
 if(!ball || !hit || dut.bad_frame || dut.lines!=1080) $fatal(1,"red frame failed hit=%b bad=%b lines=%0d",hit,dut.bad_frame,dut.lines);
 if(!dut.box_valid || dut.box_left!=927 || dut.box_right!=993 || dut.box_top!=507 || dut.box_bottom!=573)
  $fatal(1,"red box failed valid=%b bounds=%0d,%0d,%0d,%0d",dut.box_valid,dut.box_left,dut.box_right,dut.box_top,dut.box_bottom);
 $display("PASS 1080p red ball box bounds=%0d,%0d,%0d,%0d",dut.box_left,dut.box_right,dut.box_top,dut.box_bottom);
 $finish;
end
endmodule
