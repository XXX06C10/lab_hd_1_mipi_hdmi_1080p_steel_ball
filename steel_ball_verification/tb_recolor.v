`timescale 1ns/1ps
module tb_recolor;
    localparam [127:0] OV_MAG = 128'hFF00FFFF_00FF00FF_00FF00FF_00FF00FF;
    function [127:0] ov_recolor;
        input [127:0] d;
        input [1:0] ph;
        input [5:0] ma;
        input mb0;
        reg [15:0] bm;
        reg [127:0] sel;
        integer i;
        begin
            case(ph)
                2'd0: bm = {mb0,ma[4],ma[4],ma[4],ma[3],ma[3],ma[3],ma[2],ma[2],ma[2],ma[1],ma[1],ma[1],ma[0],ma[0],ma[0]};
                2'd1: bm = {mb0,mb0,ma[4],ma[4],ma[4],ma[3],ma[3],ma[3],ma[2],ma[2],ma[2],ma[1],ma[1],ma[1],ma[0],ma[0]};
                default: bm = {ma[5],ma[5],ma[5],ma[4],ma[4],ma[4],ma[3],ma[3],ma[3],ma[2],ma[2],ma[2],ma[1],ma[1],ma[1],ma[0]};
            endcase
            sel = 128'd0;
            for(i=0;i<16;i=i+1) sel[8*i +: 8] = {8{bm[i]}};
            ov_recolor = (d & ~sel) | (OV_MAG & sel);
        end
    endfunction
    localparam [127:0] w0 = 128'hC83C3CC83C3CC83C3CC83C3CC83C3CC8;
    initial begin
        $display("case1 w0 ph0 ma=111110 mb0=1 -> %h", ov_recolor(w0, 2'd0, 6'b111110, 1'b1));
        $display("case2 w0 ph0 ma=000001 mb0=0 -> %h", ov_recolor(w0, 2'd0, 6'b000001, 1'b0));
        $display("expected all-magenta word0 -> FF00FFFF00FF00FF00FF00FF00FF00FF00");
        $finish;
    end
endmodule
