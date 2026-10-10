set base [file dirname [info script]]
cd $base
import_device ph1_35p.db -package PH1P35MDG324 -speed 3
open_project -single_run camera_to_dsi_display.al
elaborate -top design_top_wrapper
read_adc ../user_source/constraints_source/pin.adc
read_ip_adc -ip ddr2 -file ../user_source/hdl_source/ph1p35_ddr/ddr2/src/adc/ddr2.adc
optimize_rtl
read_sdc camera_to_dsi_display.sdc
read_sdc -ip ddr2 ../user_source/hdl_source/ph1p35_ddr/ddr2/src/sdc/ddr2.sdc
read_sdc -ip w128_d512_fifo ../user_source/ip_source/w128_d512_fifo/w128_d512_fifo.tcl
cd camera_to_dsi_display_Runs/phy_1
report_area -file camera_to_dsi_display_rtl.area
optimize_gate -packarea camera_to_dsi_display_gate.area
legalize_phy_inst
export_db camera_to_dsi_display_gate.db
place
report_area -io_info -file camera_to_dsi_display_phy.area
route
update_timing -mode final
report_timing_status -file camera_to_dsi_display_phy.ts
report_timing_summary -file camera_to_dsi_display_pr.timing
report_timing_summary -ep_num 20 -file final_timing.rpt
report_area -io_info -file camera_to_dsi_display_phy.area
export_db camera_to_dsi_display_pr.db
bitgen -bit camera_to_dsi_display.bit
puts STEEL_BALL_BUILD_COMPLETE
exit