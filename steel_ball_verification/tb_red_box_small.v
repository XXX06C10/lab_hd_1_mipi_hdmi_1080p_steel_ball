`timescale 1ns/1ps
module tb_red_box_small;
reg clk=0,rst=0;
always #5 clk=~clk;
reg [95:0] rgb=0;
reg valid=0,sof=0,last=0;
wire [127:0] packed_rgb;
wire pv,pu,ball,done,hit,fault;
wire [127:0] box_video;
wire box_video_valid;
wire [21:0] red_pixels,largest_area;
wire [23:0] largest_perimeter;
wire [10:0] xmin,xmax,ymin,ymax;
wire [3:0] geometry;
wire [11:0] lines;
wire bad_frame,label_exhausted,box_valid;
data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),
 .I_96b_frame_start(sof),.I_96b_valid(valid),.I_96b_data(rgb),
 .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_rgb));
steel_ball_detect #(.IMG_WIDTH(64),.IMG_HEIGHT(48),.MIN_AREA(20),.MAX_AREA(2000),
 .CONFIRM_FRAMES(1),.COLOR_MODE(1),.COLOR_MIN(60),.COLOR_RATIO_LOG2(1),
 .OVERLAY_EN(1),.OVERLAY_BOX(1),.BOX_MARGIN(3),.BOX_THICKNESS(2)) dut(
 .I_clk(clk),.I_rst_n(rst),.S_AXIS_tdata(packed_rgb),.S_AXIS_tvalid(pv),
 .S_AXIS_tuser(pu),.S_AXIS_tlast(last),.M_AXIS_tdata(box_video),.M_AXIS_tvalid(box_video_valid),
 .M_AXIS_tuser(),.M_AXIS_tlast(),.O_ball_detected(ball),.O_frame_done(done),
 .O_frame_hit(hit),.O_fault(fault),.O_bright(),.O_error_code(),
 .O_diag_red_pixels(red_pixels),.O_diag_largest_area(largest_area),
 .O_diag_largest_perimeter(largest_perimeter),
 .O_diag_xmin(xmin),.O_diag_xmax(xmax),.O_diag_ymin(ymin),.O_diag_ymax(ymax),
 .O_diag_geometry(geometry),.O_diag_fifo_peak(),.O_diag_lines(lines),
 .O_diag_labels(),.O_diag_bad_frame(bad_frame),
 .O_diag_label_exhausted(label_exhausted),.O_diag_box_valid(box_valid));
integer y,g,k,x,bi,green_hits=0;
always @(posedge clk) begin
 #1;
 if(box_video_valid) for(bi=0;bi<14;bi=bi+1)
  if(box_video[bi*8 +: 24]===24'h00ff00) green_hits=green_hits+1;
end
initial begin
 repeat(5) @(negedge clk);rst=1;sof=1;
 @(negedge clk);sof=0;
 repeat(60) @(negedge clk);
 for(y=0;y<48;y=y+1) begin
  for(g=0;g<16;g=g+1) begin
   @(negedge clk);valid=1;last=(g==15);
   for(k=0;k<4;k=k+1) begin
    x=g*4+k;
    rgb[95-k*24 -: 24]=((x-32)*(x-32)+(y-24)*(y-24)<=100)?24'hc81e1e:24'h101820;
   end
  end
  @(negedge clk);valid=0;last=0;
  repeat(850) @(negedge clk);
 end
 repeat(5000) @(negedge clk);
 sof=1;@(negedge clk);sof=0;
 wait(done);#1;
 if(!hit || !dut.box_valid || fault || dut.box_left!=19 || dut.box_right!=45 ||
    dut.box_top!=11 || dut.box_bottom!=37) $fatal(1,"red box missing or misplaced");
 if(red_pixels!=317 || largest_area!=317 || largest_perimeter!=84 ||
    xmin!=22 || xmax!=42 || ymin!=14 || ymax!=34 || geometry!=4'hf ||
    lines!=48 || bad_frame || label_exhausted || !box_valid)
  $fatal(1,"diagnostic snapshot mismatch R=%0d A=%0d P=%0d G=%h",red_pixels,largest_area,largest_perimeter,geometry);
 for(y=0;y<40;y=y+1) begin
  for(g=0;g<16;g=g+1) begin
   @(negedge clk);valid=1;last=(g==15);rgb=96'h101820101820101820101820;
  end
  @(negedge clk);valid=0;last=0;
  repeat(850) @(negedge clk);
 end
 repeat(20) @(negedge clk);
 if(green_hits==0) $fatal(1,"HDMI stream has no green box pixels");
 $display("PASS small red box");
 $finish;
end
endmodule
