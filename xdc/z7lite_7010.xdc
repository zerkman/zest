# PL Push buttons
#set_property PACKAGE_PIN P16 [get_ports {key[0]}]
#set_property PACKAGE_PIN T12 [get_ports {key[1]}]
#set_property IOSTANDARD LVCMOS33 [get_ports {key[*]}]

# PL LEDs
set_property PACKAGE_PIN P15 [get_ports {led[0]}]
set_property PACKAGE_PIN U12 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

# HDMI
set_property PACKAGE_PIN U18 [get_ports hdmi_tx_clk_p]
set_property PACKAGE_PIN V20 [get_ports {hdmi_tx_d_p[0]}]
set_property PACKAGE_PIN T20 [get_ports {hdmi_tx_d_p[1]}]
set_property PACKAGE_PIN N20 [get_ports {hdmi_tx_d_p[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_tx_d_p[*]}]
set_property IOSTANDARD TMDS_33 [get_ports hdmi_tx_clk_p]

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins psd/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks clk_fpga_0]
