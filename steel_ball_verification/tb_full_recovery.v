`timescale 1ns/1ps
module tb_full_recovery;
reg clk=0,rst=0;
always #4.444 clk=~clk;
reg [95:0] rgb=0;
reg valid=0,sof=0,last=0;
wire [127:0] packed_rgb;
wire pv,pu,ball,done,hit,fault;
wire [1:0] error_code;
data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),
 .I_96b_frame_start(sof),.I_96b_valid(valid),.I_96b_data(rgb),
 .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_rgb));
steel_ball_detect #(.CONFIRM_FRAMES(1)) dut(.I_clk(clk),.I_rst_n(rst),
 .S_AXIS_tdata(packed_rgb),.S_AXIS_tvalid(pv),.S_AXIS_tuser(pu),.S_AXIS_tlast(last),
 .M_AXIS_tdata(),.M_AXIS_tvalid(),.M_AXIS_tuser(),.M_AXIS_tlast(),
 .O_ball_detected(ball),.O_frame_done(done),.O_frame_hit(hit),.O_fault(fault),
 .O_bright(),.O_error_code(error_code));
integer y,g,k,x,cycles=0;
reg recovering=0;
always @(posedge clk) begin
 cycles=cycles+1;
 if(recovering && fault) $fatal(1,"overflow in sparse recovered frame");
 if(cycles>9000000) $fatal(1,"timeout");
end
task start_frame;
 begin
  sof=1;@(negedge clk);sof=0;
  repeat(600) @(negedge clk);
 end
endtask
initial begin
 repeat(5) @(negedge clk);rst=1;
 start_frame;
 // Same line rate and real packer as the camera, but a broad bright field.
 for(y=0;y<64;y=y+1) begin
  for(g=0;g<480;g=g+1) begin
   @(negedge clk);valid=1;last=(g==479);rgb={96{1'b1}};
  end
  @(negedge clk);valid=0;last=0;
  repeat(2819) @(negedge clk);
 end
 if(!fault || error_code!=1 || ball) $fatal(1,"dense 1080p input should expose FIFO limit");
 start_frame;
 recovering=1;
 for(y=0;y<1080;y=y+1) begin
  for(g=0;g<480;g=g+1) begin
   @(negedge clk);valid=1;last=(g==479);
   for(k=0;k<4;k=k+1) begin
    x=g*4+k;
    rgb[95-k*24 -:24]=((x-1800)*(x-1800)+(y-1040)*(y-1040)<=900)?24'hffffff:0;
   end
  end
  @(negedge clk);valid=0;last=0;
  repeat(2819) @(negedge clk);
 end
 repeat(100000) @(negedge clk);
 sof=1;@(negedge clk);sof=0;
 wait(done);#1;
 if(!ball || !hit || dut.lines!=1080 || error_code!=1) $fatal(1,"1080p recovery failed");
 if(dut.stats[1][89:68]!=2821 || dut.stats[1][67:44]!=244) $fatal(1,"recovered geometry corrupted");
 $display("PASS production FIFO4096: dense 1080p lines overflow; next sparse full frame recovers without reset, area=2821 perimeter=244");
 $finish;
end
endmodule
