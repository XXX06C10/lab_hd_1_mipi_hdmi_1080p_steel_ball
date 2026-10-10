`timescale 1ns/1ps
module tb_stream_cluster;
    localparam W=128, H=72;
    reg clk=0, rst_n=0;
    always #5 clk=~clk;
    reg [5:0] mask=0;
    reg [4:0] meta=0;
    wire frame_done, frame_hit, ball, bright, box_valid, bad_frame;
    wire [10:0] box_left, box_right, box_top, box_bottom;
    wire [21:0] red_pixels, area;
    wire [23:0] perimeter;
    wire [10:0] xmin, xmax, ymin, ymax, ball_x, ball_y;
    wire [3:0] geometry, confidence;
    wire [11:0] lines;
    wire [2:0] clusters;
    wire [1:0] error_code;
    integer i, fails;
    reg [5:0] token_mask;
    reg redmap[0:W*H-1];


    steel_ball_stream_bbox #(
        .IMG_WIDTH(W), .IMG_HEIGHT(H),
        .MIN_AREA(20), .MAX_AREA(2000),
        .CONFIRM_FRAMES(2),
        .FILL_MIN_PERCENT(15), .FILL_MAX_PERCENT(100),
        .DOMINANCE_PERCENT(50), .ASPECT_PERCENT(50),
        .CLUSTER_RADIUS(16), .MAX_JUMP(48), .EDGE_MARGIN(2), .MAX_DIM(60),
        .MARK_HALF(14)
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

    task clr_map;
        begin
            for(i=0;i<W*H;i=i+1) redmap[i]=1'b0;
        end
    endtask

    task put_disk;
        input integer cx, cy, r;
        integer ux, uy;
        begin
            for(uy=0;uy<H;uy=uy+1)
                for(ux=0;ux<W;ux=ux+1)
                    if((ux-cx)*(ux-cx)+(uy-cy)*(uy-cy)<=r*r) redmap[uy*W+ux]=1'b1;
        end
    endtask

    task put_ring;
        input integer cx, cy, r, t;
        integer ux, uy, d2;
        begin
            for(uy=0;uy<H;uy=uy+1)
                for(ux=0;ux<W;ux=ux+1) begin
                    d2=(ux-cx)*(ux-cx)+(uy-cy)*(uy-cy);
                    if(d2<=(r+t)*(r+t) && d2>=(r-t)*(r-t)) redmap[uy*W+ux]=1'b1;
                end
        end
    endtask

    task put_pixel;
        input integer ux, uy;
        begin redmap[uy*W+ux]=1'b1; end
    endtask

    task pulse_sof;
        begin
            @(negedge clk); mask=0; meta=5'b10000;
            @(negedge clk); meta=5'b00000;
        end
    endtask

    task stream_frame;
        integer yy, gg, pp, cc, bb, xx;
        begin
            for(yy=0;yy<H;yy=yy+1) begin
                for(gg=0;gg<8;gg=gg+1) begin
                    for(pp=0;pp<3;pp=pp+1) begin
                        cc = (pp==2)?6:5;
                        bb = gg*16 + ((pp==0)?0:(pp==1)?5:10);
                        token_mask=0;
                        for(xx=0;xx<cc;xx=xx+1)
                            if(redmap[yy*W+bb+xx]) token_mask[xx]=1'b1;
                        @(negedge clk);
                        mask=token_mask;
                        meta={1'b0,(gg==7 && pp==2),cc[2:0]};
                    end
                end
            end
        end
    endtask

    task wait_done;
        integer w;
        begin
            @(negedge clk); mask=0; meta=0;
            for(w=0;w<300;w=w+1) begin
                @(negedge clk);
                if(frame_done) w=100000;
            end
            if(!frame_done)
                $display("NOWAIT scan=%b idx=%0d eval=%0d sv=%b sfo=%b scnt=%0d",dut.scanning,dut.scan_idx,dut.eval_stage,dut.sel_valid,dut.sel_frame_ok,dut.sel_cnt);
            @(negedge clk);
        end
    endtask

    task hard_reset;
        begin
            rst_n=0;
            repeat(3) @(negedge clk);
            rst_n=1;
            @(negedge clk);
        end
    endtask

    task chk_center;
        input [10:0] ex, ey;
        input integer tol;
        begin
            if(ball_x>ex+tol || ball_x+tol<ex || ball_y>ey+tol || ball_y+tol<ey) begin
                fails=fails+1;
                $display("FAIL center got (%0d,%0d) expected (%0d,%0d)",ball_x,ball_y,ex,ey);
            end else $display("  ok center (%0d,%0d)",ball_x,ball_y);
        end
    endtask

    task chk;
        input cond;
        input [8*48-1:0] msg;
        begin
            if(!cond) begin fails=fails+1; $display("FAIL %0s",msg); end
            else $display("  ok %0s",msg);
        end
    endtask

    initial begin
        fails=0;
        for(i=0;i<W*H;i=i+1) redmap[i]=0;
        rst_n=0; repeat(4) @(negedge clk); rst_n=1; @(negedge clk);

        $display("SCENARIO moving ball");
        pulse_sof();
        clr_map(); put_disk(30,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(box_valid,"moving frame1 candidate");
        chk(!ball,"moving frame1 not confirmed yet");
        chk(confidence==4'h8,"moving frame1 confidence=8");
        chk_center(30,36,1);
        chk((box_left+box_right)==(2*ball_x),"candidate box centered on centroid");
        clr_map(); put_disk(50,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"moving frame2 confirmed");
        chk(confidence==4'hF,"moving frame2 confidence=15");
        chk_center(50,36,1);
        clr_map(); put_disk(70,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"moving frame3 confirmed");
        chk_center(70,36,1);

        $display("SCENARIO sparse ring");
        hard_reset();
        pulse_sof();
        clr_map(); put_ring(44,36,8,1);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_ring(44,36,8,1);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"ring confirmed");
        chk_center(44,36,2);

        $display("SCENARIO scattered noise");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(60,36,6);
        put_pixel(5,5); put_pixel(120,5); put_pixel(5,66); put_pixel(120,66);
        put_pixel(64,8); put_pixel(100,64); put_pixel(20,10); put_pixel(110,20);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(60,36,6);
        put_pixel(5,5); put_pixel(120,5); put_pixel(5,66); put_pixel(120,66);
        put_pixel(64,8); put_pixel(100,64); put_pixel(20,10); put_pixel(110,20);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"noise ball confirmed");
        chk_center(60,36,1);
        chk(xmax-xmin<=16,"noise bbox not stretched");

        $display("SCENARIO edge artefact");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(30,36,6);
        for(i=0;i<W;i=i+1) begin put_pixel(i,71); put_pixel(i,0); end
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(30,36,6);
        for(i=0;i<W;i=i+1) begin put_pixel(i,71); put_pixel(i,0); end
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"edge artefact ball confirmed");
        chk_center(30,36,1);
        chk(ymax<70,"edge artefact excluded");

        $display("SCENARIO no ball");
        hard_reset();
        pulse_sof();
        clr_map();
        stream_frame(); pulse_sof(); wait_done();
        clr_map();
        stream_frame(); pulse_sof(); wait_done();
        chk(!box_valid,"no ball no candidate");
        chk(!ball,"no ball not confirmed");
        chk(area==0,"no ball zero area");
        chk(perimeter==0,"no ball zero perimeter");
        chk(geometry==0,"no ball zero geometry");
        chk(ball_x==0 && ball_y==0,"no ball zero center");
        chk(confidence==0,"no ball zero confidence");

        $display("SCENARIO multiple objects");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(30,36,6); put_disk(100,20,4);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(30,36,6); put_disk(100,20,4);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"multi object confirmed dominant");
        chk_center(30,36,1);

        $display("SCENARIO cluster saturation");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(64,40,6);
        put_disk(10,10,3); put_disk(118,10,3); put_disk(10,62,3);
        put_disk(118,62,3); put_disk(64,8,3);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(64,40,6);
        put_disk(10,10,3); put_disk(118,10,3); put_disk(10,62,3);
        put_disk(118,62,3); put_disk(64,8,3);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"saturation ball confirmed");
        chk_center(64,40,2);

        $display("SCENARIO disappear and re-enter");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(40,36,6);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(40,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"reenter first acquisition confirmed");
        clr_map();
        stream_frame(); pulse_sof(); wait_done();
        chk(!ball,"reenter lost confirmation");
        chk(!box_valid,"reenter cleared candidate");
        chk(ball_x==0,"reenter cleared center");
        clr_map();
        stream_frame(); pulse_sof(); wait_done();
        chk(!ball,"reenter still absent");
        clr_map(); put_disk(40,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(!ball,"reenter needs one more frame");
        clr_map(); put_disk(40,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(ball,"reenter re-confirmed");
        chk_center(40,36,1);

        $display("SCENARIO edge clipped ball");
        hard_reset();
        pulse_sof();
        clr_map(); put_disk(5,36,6);
        stream_frame(); pulse_sof(); wait_done();
        clr_map(); put_disk(5,36,6);
        stream_frame(); pulse_sof(); wait_done();
        chk(box_valid,"edge clipped candidate");
        chk_center(6,36,3);

        if(fails==0) $display("PASS cluster scenarios");
        else $fatal(1,"cluster scenarios failed: %0d",fails);
        $finish;
    end
endmodule
