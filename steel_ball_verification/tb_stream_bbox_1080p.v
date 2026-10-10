`timescale 1ns/1ps
module tb_stream_bbox_1080p;
    reg clk=0, rst_n=0;
    reg [5:0] mask=0;
    reg [4:0] meta=0;
    always #5 clk=~clk;
    wire frame_done, frame_hit, ball, bright, box_valid, bad_frame;
    wire [10:0] box_left, box_right, box_top, box_bottom;
    wire [21:0] red_pixels, area;
    wire [23:0] perimeter;
    wire [10:0] xmin, xmax, ymin, ymax, ball_x, ball_y;
    wire [3:0] geometry, confidence;
    wire [11:0] lines;
    wire [2:0] clusters;
    wire [1:0] error_code;
    integer y, group_index, phase, p, px, count, fr;
    reg [5:0] token_mask;

    steel_ball_stream_bbox #(
        .IMG_WIDTH(1920), .IMG_HEIGHT(1080),
        .MIN_AREA(80), .MAX_AREA(200000), .CONFIRM_FRAMES(2),
        .FILL_MIN_PERCENT(15), .FILL_MAX_PERCENT(100),
        .DOMINANCE_PERCENT(50), .ASPECT_PERCENT(50),
        .CLUSTER_RADIUS(16), .MAX_JUMP(220), .EDGE_MARGIN(4), .MAX_DIM(400),
        .MARK_HALF(14), .MARK_AUTO(1), .MARK_MIN_HALF(64),
        .MARK_MAX_HALF(192), .MARK_MARGIN(8)
    ) dut (
        .I_clk(clk), .I_rst_n(rst_n), .I_mask(mask), .I_meta(meta),
        .O_frame_done(frame_done), .O_frame_hit(frame_hit),
        .O_ball_detected(ball), .O_bright(bright), .O_box_valid(box_valid),
        .O_box_left(box_left), .O_box_right(box_right),
        .O_box_top(box_top), .O_box_bottom(box_bottom),
        .O_red_pixels(red_pixels), .O_area(area), .O_perimeter(perimeter),
        .O_xmin(xmin), .O_xmax(xmax), .O_ymin(ymin), .O_ymax(ymax),
        .O_geometry(geometry), .O_lines(lines),
        .O_bad_frame(bad_frame), .O_error_code(error_code),
        .O_ball_x(ball_x), .O_ball_y(ball_y),
        .O_confidence(confidence), .O_cluster_count(clusters)
    );
    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        @(negedge clk); meta=5'b10000;
        for(fr=0;fr<2;fr=fr+1) begin
            for(y=0;y<1080;y=y+1) begin
                for(group_index=0;group_index<120;group_index=group_index+1) begin
                    for(phase=0;phase<3;phase=phase+1) begin
                        count=phase==2 ? 6 : 5;
                        token_mask=0;
                        for(p=0;p<count;p=p+1) begin
                            px=group_index*16+(phase==0 ? 0 : phase==1 ? 5 : 10)+p;
                            if((px-1800)*(px-1800)+(y-1040)*(y-1040)<=900)
                                token_mask[p]=1;
                        end
                        @(negedge clk);
                        mask=token_mask;
                        meta={1'b0,(group_index==119 && phase==2),count[2:0]};
                    end
                end
            end
            @(negedge clk); mask=0; meta=5'b10000;
            @(negedge clk); meta=0;
            wait(frame_done); #1;
            if(fr==0) begin
                if(!frame_hit || !box_valid || ball || red_pixels!=2821 || area!=2821 ||
                   geometry!=4'hf || bad_frame || error_code!=0)
                    $fatal(1,"1080p frame1 mismatch red=%0d area=%0d geom=%h box=%b bad=%b",red_pixels,area,geometry,box_valid,bad_frame);
                $display("PASS 1080p frame1 candidate area=%0d",area);
            end
        end
        if(!frame_hit || !box_valid || !ball ||
           red_pixels!=2821 || area!=2821 || perimeter!=244 ||
           xmin!=1770 || xmax!=1830 || ymin!=1010 || ymax!=1070 ||
           box_left!=1736 || box_right!=1864 || box_top!=976 || box_bottom!=1079 ||
           ball_x!=1800 || ball_y!=1040 || clusters!=1 ||
           geometry!=4'hf || bad_frame || error_code!=0)
            $fatal(1,"1080p frame2 mismatch red=%0d area=%0d perim=%0d geom=%h ball=%b box=%b center=(%0d,%0d)",red_pixels,area,perimeter,geometry,ball,box_valid,ball_x,ball_y);
        $display("PASS full-rate 1080p two-frame cluster: red=2821 center=(1800,1040) bbox=(1770,1010)-(1830,1070)");
        $finish;
    end
endmodule
