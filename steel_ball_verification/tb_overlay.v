`timescale 1ns/1ps
module tb_overlay;
reg clk=0; always #5 clk=~clk;
reg rst_n=0;
reg [127:0] d;
reg v,tuser,tlast;
wire [127:0] md; wire mv,mtuser,mtlast;

steel_ball_detect #(
    .IMG_WIDTH(16), .IMG_HEIGHT(5), .CONFIRM_FRAMES(1), .LABEL_BITS(4), .FIFO_BITS(4),
    .COLOR_MODE(1), .COLOR_MIN(60), .COLOR_RATIO_LOG2(1), .COLOR_HIGHLIGHT_FILL(0),
    .OVERLAY_EN(1)
) dut(
    .I_clk(clk), .I_rst_n(rst_n),
    .S_AXIS_tdata(d), .S_AXIS_tvalid(v), .S_AXIS_tuser(tuser), .S_AXIS_tlast(tlast),
    .M_AXIS_tdata(md), .M_AXIS_tvalid(mv), .M_AXIS_tuser(mtuser), .M_AXIS_tlast(mtlast),
    .O_ball_detected(), .O_frame_done(), .O_frame_hit(), .O_fault(), .O_bright(), .O_error_code()
);

// ALL pixels red (0xC83C3C) so every mask bit should fire.
localparam [127:0] w0 = 128'hC83C3CC83C3CC83C3CC83C3CC83C3CC8;
localparam [127:0] w1 = 128'h3C3CC83C3CC83C3CC83C3CC83C3CC83C;
localparam [127:0] w2 = 128'h3CC83C3CC83C3CC83C3CC83C3CC83C3C;
// expected recolored: every byte magenta (FF,00,FF repeating from R byte):
localparam [127:0] e0 = 128'hFF00FFFF00FFFF00FFFF00FFFF00FFFF;
localparam [127:0] e1 = 128'h00FFFF00FFFF00FFFF00FFFF00FFFF00;
localparam [127:0] e2 = 128'hFFFF00FFFF00FFFF00FFFF00FFFF00FF;
localparam [127:0] s0 = 128'hC83C3CFFFFFFC83C3C203040C83C3CC8;
localparam [127:0] s1 = 128'h3C3C203040203040FFFFFFC83C3CC83C;
localparam [127:0] s2 = 128'h3C203040203040203040FFFFFFC83C3C;
localparam [127:0] f0 = 128'hFF00FFFFFFFFFF00FF203040FF00FFFF;
localparam [127:0] f1 = 128'h00FF203040203040FFFFFFFF00FFFF00;
localparam [127:0] f2 = 128'hFF203040203040203040FFFFFFFF00FF;

integer any_mask=0;
integer fails=0;
reg [127:0] cap[0:5];
integer capn=0;
reg [127:0] cadd[0:5];
reg [5:0] capmr[0:5];
reg [1:0] capp[0:5];
reg capb[0:5];
reg [5:0] capm0, capm1, capm2;
reg c0,c1,c2;
always @(posedge clk) begin
    #1;
    if(dut.mask2 != 0) any_mask = 1;
    if(mv && capn < 6) begin
        if(mtuser !== (capn==0 || capn==3) || mtlast !== (capn==2 || capn==5)) begin
            $display("FAIL sideband word%0d user=%b last=%b", capn, mtuser, mtlast);
            fails=fails+1;
        end
        cap[capn] = md;
        cadd[capn] = dut.dd2;
        capmr[capn] = dut.mask2_reg;
        capp[capn] = dut.pdp3;
        capb[capn] = dut.mask2[0];
        capn = capn + 1;
    end
    if(dut.dd2==w0) begin capm0=dut.mask2_reg; c0=1; end
    if(dut.dd2==w1) begin capm1=dut.mask2_reg; c1=1; end
    if(dut.dd2==w2) begin capm2=dut.mask2_reg; c2=1; end
end

integer i;
integer b;
function [7:0] byteof;
    input [127:0] w;
    input integer kk;
    begin byteof = w[8*kk +: 8]; end
endfunction
initial begin
    $dumpfile("overlay.vcd");
    $dumpvars(0, tb_overlay);
    rst_n=0; d=0; v=0; tuser=0; tlast=0;
    repeat(3) @(negedge clk);
    rst_n=1;
    @(negedge clk);
    d=w0; v=1; tuser=1; tlast=0; @(negedge clk);
    d=w1; v=1; tuser=0; tlast=0; @(negedge clk);
    d=w2; v=1; tuser=0; tlast=1; @(negedge clk);
    d=0; v=0; tuser=0; tlast=0;
    repeat(3) @(negedge clk);
    d=s0; v=1; tuser=1; tlast=0; @(negedge clk);
    d=s1; v=1; tuser=0; tlast=0; @(negedge clk);
    d=s2; v=1; tuser=0; tlast=1; @(negedge clk);
    d=0; v=0; tuser=0; tlast=0;
    repeat(40) @(negedge clk);
    $display("any_mask2=%0d capn=%0d", any_mask, capn);
    for(i=0;i<6;i=i+1)
        $display("cap%0d md=%h dd2=%h mask2reg=%b ph=%0b mb0=%0b", i, cap[i], cadd[i], capmr[i], capp[i], capb[i]);
    $display("mask2reg w0=%b w1=%b w2=%b (c=%0d,%0d,%0d)", capm0, capm1, capm2, c0, c1, c2);
    if(any_mask==0) begin $display("FAIL: mask2 never fired"); fails=fails+1; end
    if(capn<6) begin $display("FAIL: captured only %0d output words", capn); fails=fails+1; end
    else begin
        for(i=0;i<6;i=i+1) begin
            if(cap[i] !== (i==0 ? e0 : i==1 ? e1 : i==2 ? e2 : i==3 ? f0 : i==4 ? f1 : f2)) begin
                $display("FAIL word%0d got=%h",i,cap[i]);
                fails=fails+1;
            end
            if(i<3) for(b=0;b<16;b=b+1) begin
                if(byteof(cap[i],b)!==8'h00 && byteof(cap[i],b)!==8'hFF) begin
                    $display("FAIL word%0d byte%0d = %h (not magenta)", i, b, byteof(cap[i],b));
                    fails=fails+1;
                end
            end
        end
        if(fails==0) for(i=0;i<6;i=i+1) $display("OK word%0d: %h", i, cap[i]);
    end
    if(fails==0) $display("OVERLAY ALL PASS"); else $display("OVERLAY FAIL count=%0d", fails);
    $finish;
end
endmodule
