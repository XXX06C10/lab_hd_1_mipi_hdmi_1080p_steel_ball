`timescale 1ns/1ps
module tb_stream_bbox;
    reg clk=0, rst_n=0;
    reg [5:0] mask=0;
    reg [4:0] meta=0;
    always #5 clk=~clk;
    wire frame_done, frame_hit, ball, bright, box_valid, bad_frame;
    wire [10:0] box_left, box_right, box_top, box_bottom;
    wire [21:0] red_pixels, area;
    wire [23:0] perimeter;
    wire [10:0] xmin, xmax, ymin, ymax;
    wire [3:0] geometry;
    wire [11:0] lines;
    wire [1:0] error_code;
    integer done_count=0;
    always @(posedge clk) if(frame_done) done_count=done_count+1;

    steel_ball_stream_bbox #(
        .IMG_WIDTH(16), .IMG_HEIGHT(8), .MIN_AREA(8), .MAX_AREA(40),
        .CONFIRM_FRAMES(2), .BOX_MARGIN(1)
    ) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_mask(mask), .I_meta(meta),
        .O_frame_done(frame_done), .O_frame_hit(frame_hit),
        .O_ball_detected(ball), .O_bright(bright), .O_box_valid(box_valid),
        .O_box_left(box_left), .O_box_right(box_right),
        .O_box_top(box_top), .O_box_bottom(box_bottom),
        .O_red_pixels(red_pixels), .O_area(area), .O_perimeter(perimeter),
        .O_xmin(xmin), .O_xmax(xmax), .O_ymin(ymin), .O_ymax(ymax),
        .O_geometry(geometry), .O_lines(lines),
        .O_bad_frame(bad_frame), .O_error_code(error_code)
    );

    task send_word;
        input [5:0] m;
        input [2:0] count;
        input eol;
        begin
            @(negedge clk); mask=m; meta={1'b0,eol,count};
            @(negedge clk); mask=0; meta=0;
        end
    endtask
    task send_sof;
        begin
            @(negedge clk); mask=0; meta=5'b10000;
            @(negedge clk); meta=0;
        end
    endtask
    task send_frame;
        integer yy, ph, p, xx, count;
        reg [5:0] m;
        begin
            for(yy=0;yy<8;yy=yy+1) begin
                for(ph=0;ph<3;ph=ph+1) begin
                    count=ph==2 ? 6 : 5;
                    m=0;
                    for(p=0;p<count;p=p+1) begin
                        xx=ph==0 ? p : ph==1 ? 5+p : 10+p;
                        if(xx>=4 && xx<=7 && yy>=2 && yy<=5 &&
                           !((xx==4 || xx==7) && (yy==2 || yy==5))) m[p]=1;
                    end
                    send_word(m,count,ph==2);
                end
            end
        end
    endtask
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        send_sof(); send_frame(); send_sof();
        repeat(8) @(negedge clk);
        if(done_count!=1 || !frame_hit || !box_valid || ball ||
           red_pixels!=12 || area!=12 || geometry!=4'hf ||
           xmin!=4 || xmax!=7 || ymin!=2 || ymax!=5 ||
           box_left!=3 || box_right!=8 || box_top!=1 || box_bottom!=6 ||
           bad_frame || error_code!=0)
            $fatal(1,"first frame failed done=%0d hit=%b box=%b ball=%b red=%0d geom=%h bounds=%0d-%0d %0d-%0d",done_count,frame_hit,box_valid,ball,red_pixels,geometry,xmin,xmax,ymin,ymax);
        send_frame(); send_sof();
        repeat(8) @(negedge clk);
        if(done_count!=2 || !ball || !box_valid) $fatal(1,"confirmation failed");
        $display("PASS streaming red bbox: 16 pixels per group, frame geometry, box and confirmation");
        $finish;
    end
endmodule
