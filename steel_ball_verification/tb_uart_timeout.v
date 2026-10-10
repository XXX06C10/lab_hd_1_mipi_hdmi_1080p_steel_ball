`timescale 1ns/1ps
module tb_uart_timeout;
reg clk=0,rst=0;
always #5 clk=~clk;
wire tx;
steel_ball_uart_diag #(.CLK_HZ(10000),.BAUD(1000)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_frame_done(1'b0),
 .I_red_pixels(22'd0),.I_largest_area(22'd0),.I_largest_perimeter(24'd0),
 .I_xmin(11'd0),.I_xmax(11'd0),.I_ymin(11'd0),.I_ymax(11'd0),
 .I_geometry(4'd0),.I_labels(9'd0),.I_fifo_peak(17'd0),
 .I_input_words(22'd0),.I_input_lines(12'd0),
 .I_detect_frames(16'd0),.I_detect_lines(12'd0),
 .I_bright(1'b0),.I_frame_hit(1'b0),.I_box_valid(1'b0),.I_ball(1'b0),
 .I_bad_frame(1'b0),.I_label_exhausted(1'b0),.I_fault(1'b0),
 .I_error_code(2'd0),.O_tx(tx));
task receive_byte;
 output reg [7:0] value;
 integer j;
 begin
  @(negedge tx);
  repeat(15) @(posedge clk);
  for(j=0;j<8;j=j+1) begin
   value[j]=tx;
   repeat(10) @(posedge clk);
  end
  if(tx!==1'b1) $fatal(1,"UART stop bit missing");
 end
endtask
reg [7:0] ch;
reg [879:0] line;
integer i;
initial begin
 repeat(4) @(negedge clk);rst=1;
end
initial begin
 line=0;
 for(i=0;i<110;i=i+1) begin
  receive_byte(ch);
  line={line[871:0],ch};
 end
 if(line!=={"F=0000 R=000000 A=000000 P=000000 X=000-000 Y=000-000 G=0 N=000 Q=00000 S=80 E=0 V=000000 T=000 D=0000 L=000",8'h0d,8'h0a})
  $fatal(1,"timeout status missing: %s",line);
 $display("PASS UART no-frame heartbeat: %s",line);
 $finish;
end
endmodule
