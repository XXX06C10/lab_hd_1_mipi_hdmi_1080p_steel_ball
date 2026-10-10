`timescale 1ns/1ps
module tb_stream_box_overlay;
    reg clk=0, rst=0;
    always #5 clk=~clk;
    reg [95:0] rgb=0;
    reg valid=0, sof=0, last=0;
    wire [127:0] packed_rgb, box_video;
    wire pv, pu, box_video_valid;
    wire [5:0] color_mask;
    wire [4:0] color_meta;
    wire frame_done, frame_hit, ball, bright, box_valid;
    wire [10:0] box_left, box_right, box_top, box_bottom;
    wire [21:0] red_pixels, area;
    wire [23:0] perimeter;
    wire [10:0] xmin, xmax, ymin, ymax, ball_x, ball_y;
    wire [3:0] geometry, confidence;
    wire [11:0] lines;
    wire [2:0] clusters;
    wire bad_frame;
    wire [1:0] error_code;
    integer y, g, k, x, bi, green_hits=0;

    data_96bit_to_128bit packer(
        .I_clk(clk), .I_rst_n(rst),
        .I_96b_frame_start(sof), .I_96b_valid(valid), .I_96b_data(rgb),
        .O_128b_frame_start(pu), .O_128b_valid(pv), .O_128b_data(packed_rgb)
    );
    steel_ball_detect #(
        .IMG_WIDTH(64), .IMG_HEIGHT(48), .MIN_AREA(20), .MAX_AREA(2000),
        .COLOR_MODE(1), .COLOR_MIN(60), .COLOR_RATIO_LOG2(1),
        .OVERLAY_EN(1), .OVERLAY_BOX(1), .EXTERNAL_BOX(1),
        .BOX_MARGIN(3), .BOX_THICKNESS(2), .FIFO_BITS(8)
    ) video (
        .I_clk(clk), .I_rst_n(rst),
        .S_AXIS_tdata(packed_rgb), .S_AXIS_tvalid(pv),
        .S_AXIS_tuser(pu), .S_AXIS_tlast(last),
        .I_box_valid(box_valid),
        .I_box_left(box_left), .I_box_right(box_right),
        .I_box_top(box_top), .I_box_bottom(box_bottom),
        .I_box_confirmed(ball),
        .O_color_mask(color_mask), .O_color_meta(color_meta),
        .M_AXIS_tdata(box_video), .M_AXIS_tvalid(box_video_valid),
        .M_AXIS_tuser(), .M_AXIS_tlast(),
        .O_ball_detected(), .O_frame_done(), .O_frame_hit(),
        .O_fault(), .O_bright(), .O_error_code(),
        .O_diag_red_pixels(), .O_diag_largest_area(),
        .O_diag_largest_perimeter(), .O_diag_xmin(), .O_diag_xmax(),
        .O_diag_ymin(), .O_diag_ymax(), .O_diag_geometry(),
        .O_diag_fifo_peak(), .O_diag_lines(), .O_diag_labels(),
        .O_diag_bad_frame(), .O_diag_label_exhausted(), .O_diag_box_valid()
    );
    steel_ball_stream_bbox #(
        .IMG_WIDTH(64), .IMG_HEIGHT(48), .MIN_AREA(20), .MAX_AREA(2000),
        .CONFIRM_FRAMES(1), .FILL_MIN_PERCENT(15), .FILL_MAX_PERCENT(100),
        .DOMINANCE_PERCENT(50), .ASPECT_PERCENT(50), .CLUSTER_RADIUS(16),
        .MAX_JUMP(40), .EDGE_MARGIN(1), .MAX_DIM(40), .MARK_HALF(14)
    ) detector (
        .I_clk(clk), .I_rst_n(rst), .I_mask(color_mask), .I_meta(color_meta),
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
    always @(posedge clk) begin
        #1;
        if(box_video_valid)
            for(bi=0;bi<14;bi=bi+1)
                if(box_video[bi*8 +: 24]===24'h00ff00) green_hits=green_hits+1;
    end
    initial begin
        repeat(5) @(negedge clk); rst=1; sof=1;
        @(negedge clk); sof=0;
        repeat(20) @(negedge clk);
        for(y=0;y<48;y=y+1) begin
            for(g=0;g<16;g=g+1) begin
                @(negedge clk); valid=1; last=(g==15);
                for(k=0;k<4;k=k+1) begin
                    x=g*4+k;
                    rgb[95-k*24 -: 24]=((x-32)*(x-32)+(y-24)*(y-24)<=100)?24'hc81e1e:24'h101820;
                end
            end
            @(negedge clk); valid=0; last=0;
            repeat(10) @(negedge clk);
        end
        repeat(20) @(negedge clk);
        sof=1; @(negedge clk); sof=0;
        wait(frame_done); #1;
        if(!frame_hit || !box_valid || !ball || red_pixels!=317 || area!=317 ||
           geometry!=4'hf || xmin!=22 || xmax!=42 || ymin!=14 || ymax!=34 ||
           ball_x!=32 || ball_y!=24 ||
           box_left!=18 || box_right!=46 || box_top!=10 || box_bottom!=38 ||
           bad_frame || error_code!=0)
            $fatal(1,"stream box mismatch hit=%b valid=%b red=%0d geom=%h bad=%b lines=%0d",frame_hit,box_valid,red_pixels,geometry,bad_frame,lines);
        for(y=0;y<48;y=y+1) begin
            for(g=0;g<16;g=g+1) begin
                @(negedge clk); valid=1; last=(g==15); rgb=96'h101820101820101820101820;
            end
            @(negedge clk); valid=0; last=0;
            repeat(10) @(negedge clk);
        end
        repeat(20) @(negedge clk);
        if(green_hits==0) $fatal(1,"green box absent from video output");
        sof=1; @(negedge clk); sof=0;
        wait(frame_done); #1;
        if(box_valid || ball || red_pixels!=0 || bad_frame)
            $fatal(1,"box remained after red ball left frame");
        $display("PASS streaming red ball to green HDMI box under burst input");
        $finish;
    end
endmodule
