`timescale 1ns/1ps
module tb_stream_wide_ball;
    localparam W=512, H=384;
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
    integer yy, group_index, phase, p, px, count;
    reg [5:0] token_mask;

    steel_ball_stream_bbox #(
        .IMG_WIDTH(W), .IMG_HEIGHT(H),
        .MIN_AREA(40), .MAX_AREA(200000), .CONFIRM_FRAMES(2),
        .DOMINANCE_PERCENT(40), .ASPECT_PERCENT(50),
        .CLUSTER_RADIUS(16), .MAX_JUMP(220), .EDGE_MARGIN(4), .MAX_DIM(400),
        .MARK_AUTO(1), .MARK_MIN_HALF(64), .MARK_MAX_HALF(192), .MARK_MARGIN(8)
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

    task pulse_sof;
        begin
            @(negedge clk); mask=0; meta=5'b10000;
            @(negedge clk); meta=0;
        end
    endtask

    task stream_frame;
        input red_on;
        begin
            for(yy=0;yy<H;yy=yy+1)
                for(group_index=0;group_index<W/16;group_index=group_index+1)
                    for(phase=0;phase<3;phase=phase+1) begin
                        count=phase==2 ? 6 : 5;
                        token_mask=0;
                        for(p=0;p<count;p=p+1) begin
                            px=group_index*16+(phase==0 ? 0 : phase==1 ? 5 : 10)+p;
                            if(red_on && px>=100 && px<=420 && yy>=50 && yy<=330 &&
                               (px-100)%8==0 && (yy-50)%8==0 &&
                               (px-260)*(px-260)+(yy-190)*(yy-190)<=22500) token_mask[p]=1;
                        end
                        @(negedge clk); mask=token_mask;
                        meta={1'b0,(group_index==W/16-1 && phase==2),count[2:0]};
                    end
        end
    endtask

    task wait_done;
        begin
            wait(frame_done); #1;
        end
    endtask

    initial begin
        repeat(4) @(negedge clk); rst_n=1;
        pulse_sof();
        stream_frame(1); pulse_sof(); wait_done();
        if(!box_valid || ball || !frame_hit || geometry!=4'hf || area<1000 || area>1100 ||
           ball_x<257 || ball_x>263 || ball_y<187 || ball_y>193 ||
           box_right-box_left<280 || box_bottom-box_top<280)
            $fatal(1,"wide frame1 area=%0d geom=%h center=(%0d,%0d) box=(%0d,%0d)-(%0d,%0d)",
                   area,geometry,ball_x,ball_y,box_left,box_top,box_right,box_bottom);
        stream_frame(1); pulse_sof(); wait_done();
        if(!ball || !box_valid || geometry!=4'hf || confidence!=4'hf ||
           xmax-xmin<256 || ymax-ymin<256 ||
           box_right-box_left<280 || box_bottom-box_top<280)
            $fatal(1,"wide frame2 hit=%b area=%0d geom=%h center=(%0d,%0d)",ball,area,geometry,ball_x,ball_y);
        stream_frame(0); pulse_sof(); wait_done();
        if(box_valid || ball || area!=0 || ball_x!=0 || ball_y!=0)
            $fatal(1,"blank frame retained box");
        $display("PASS wide sparse red ball: over-256px target confirmed, adaptive large box, blank clears");
        $finish;
    end
endmodule
