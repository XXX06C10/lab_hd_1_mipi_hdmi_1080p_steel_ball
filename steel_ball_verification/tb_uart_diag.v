`timescale 1ns/1ps
module tb_uart_diag;
reg clk=0,rst=0,done=0;
always #5 clk=~clk;
wire tx;
steel_ball_uart_diag #(.CLK_HZ(1000000),.BAUD(100000)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_frame_done(done),
 .I_red_pixels(22'd1234),.I_largest_area(22'd2000),
 .I_largest_perimeter(24'd400),
 .I_xmin(11'd100),.I_xmax(11'd300),.I_ymin(11'd200),.I_ymax(11'd400),
 .I_geometry(4'hf),.I_labels(9'd128),.I_fifo_peak(17'd2500),
 .I_input_words(22'd388800),.I_input_lines(12'd1080),
 .I_detect_frames(16'd7),.I_detect_lines(12'd1080),
 .I_bright(1'b1),.I_frame_hit(1'b1),.I_box_valid(1'b1),.I_ball(1'b1),
 .I_bad_frame(1'b0),.I_label_exhausted(1'b0),.I_fault(1'b0),
 .I_error_code(2'd0),
 .I_ball_x(11'd1234),.I_ball_y(11'd867),
 .I_candidate(1'b1),.I_confirmed(1'b1),.I_confidence(4'hf),
 .O_tx(tx));
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
reg [1039:0] line;
integer i;
initial begin
 repeat(4) @(negedge clk);rst=1;
 repeat(4) @(negedge clk);done=1;
 @(negedge clk);done=0;
end
initial begin
 line=0;
 for(i=0;i<130;i=i+1) begin
  receive_byte(ch);
  line={line[1031:0],ch};
 end
 if(line!=={"F=0000 R=0004D2 A=0007D0 P=000190 X=064-12C Y=0C8-190 G=F N=080 Q=009C4 S=0F E=0 V=05EEC0 T=438 D=0007 L=438 B=4D2-363 C=03 F=0F",8'h0d,8'h0a}) begin
  $display("got=%h",line);
  $display("expected=%h",{"F=0000 R=0004D2 A=0007D0 P=000190 X=064-12C Y=0C8-190 G=F N=080 Q=009C4 S=0F E=0 V=05EEC0 T=438 D=0007 L=438 B=4D2-363 C=03 F=0F",8'h0d,8'h0a});
  $fatal(1,"UART line mismatch");
 end
 $display("PASS UART diagnostic line: %s",line);
 $finish;
end
endmodule
