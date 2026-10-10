`timescale 1ns/1ps
module tb_box_overlay;
reg clk=0; always #5 clk=~clk;
reg rst_n=0;
reg [127:0] d=0;
reg v=0,tuser=0,tlast=0;
wire [127:0] md;
wire mv,mtuser,mtlast;
localparam [383:0] src={16{24'h203040}};
reg [383:0] row;
reg [127:0] expected[0:17];
integer x,y,capn=0,fails=0;

steel_ball_detect #(
    .IMG_WIDTH(16), .IMG_HEIGHT(6), .LABEL_BITS(4), .FIFO_BITS(4),
    .COLOR_MODE(1), .OVERLAY_EN(1), .OVERLAY_BOX(1),
    .BOX_COLOR(24'h00FF00), .BOX_MARGIN(0), .BOX_THICKNESS(1)
) dut(
    .I_clk(clk), .I_rst_n(rst_n),
    .S_AXIS_tdata(d), .S_AXIS_tvalid(v), .S_AXIS_tuser(tuser), .S_AXIS_tlast(tlast),
    .I_box_confirmed(1'b1),
    .M_AXIS_tdata(md), .M_AXIS_tvalid(mv), .M_AXIS_tuser(mtuser), .M_AXIS_tlast(mtlast),
    .O_ball_detected(), .O_frame_done(), .O_frame_hit(), .O_fault(), .O_bright(), .O_error_code()
);

always @(posedge clk) begin
    #1;
    if(mv) begin
        if(capn>=18) begin $display("FAIL extra word"); fails=fails+1; end
        else begin
            if(md!==expected[capn]) begin
                $display("FAIL word%0d got=%h expected=%h",capn,md,expected[capn]);
                fails=fails+1;
            end
            if(mtuser!==(capn==0) || mtlast!==(capn%3==2)) begin
                $display("FAIL sideband word%0d user=%b last=%b",capn,mtuser,mtlast);
                fails=fails+1;
            end
        end
        capn=capn+1;
    end
end

initial begin
    $dumpfile("box_overlay.vcd");
    $dumpvars(0,tb_box_overlay);
    for(y=0;y<6;y=y+1) begin
        row=src;
        for(x=0;x<16;x=x+1)
            if(x>=5 && x<=10 && y>=1 && y<=4 &&
               (x==5 || x==10 || y==1 || y==4))
                row[383-x*24 -:24]=24'h00FF00;
        expected[3*y]=row[383:256];
        expected[3*y+1]=row[255:128];
        expected[3*y+2]=row[127:0];
    end
    repeat(3) @(negedge clk);
    rst_n=1;
    force dut.box_valid=1'b1;
    force dut.box_left=11'd5;
    force dut.box_right=11'd10;
    force dut.box_top=11'd1;
    force dut.box_bottom=11'd4;
    @(negedge clk);
    for(y=0;y<6;y=y+1) begin
        d=src[383:256]; v=1; tuser=(y==0); tlast=0; @(negedge clk);
        d=src[255:128]; tuser=0; @(negedge clk);
        d=src[127:0]; tlast=1; @(negedge clk);
        d=0; v=0; tlast=0;
        repeat(2) @(negedge clk);
    end
    repeat(10) @(negedge clk);
    if(capn!=18) begin $display("FAIL captured %0d words",capn); fails=fails+1; end
    if(fails==0) $display("BOX OVERLAY ALL PASS");
    else $fatal(1,"BOX OVERLAY FAIL count=%0d",fails);
    $finish;
end
endmodule
