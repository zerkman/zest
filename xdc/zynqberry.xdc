
# General
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]

# HDMI
set_property IOSTANDARD TMDS_33 [get_ports hdmi_tx_clk_p]
set_property PACKAGE_PIN R7 [get_ports hdmi_tx_clk_p]

set_property IOSTANDARD TMDS_33 [get_ports {hdmi_tx_d_p[*]}]
set_property PACKAGE_PIN P8 [get_ports {hdmi_tx_d_p[0]}]
set_property PACKAGE_PIN P10 [get_ports {hdmi_tx_d_p[1]}]
set_property PACKAGE_PIN P11 [get_ports {hdmi_tx_d_p[2]}]

# PWM_R
set_property PACKAGE_PIN N8 [get_ports pwm_r]
# PWM_L
set_property PACKAGE_PIN N7 [get_ports pwm_l]
set_property IOSTANDARD LVCMOS33 [get_ports pwm_*]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins psd/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks clk_fpga_0]
