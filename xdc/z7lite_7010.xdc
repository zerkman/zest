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

# Ethernet MII/MDIO
set_property IOSTANDARD LVCMOS33 [get_ports reset_rtl_0]
set_property IOSTANDARD LVCMOS33 [get_ports mdio_rtl_0_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports mdio_rtl_0_mdio_io]
set_property IOSTANDARD LVCMOS33 [get_ports mii_tx_en_0]
set_property IOSTANDARD LVCMOS33 [get_ports {mii_txd_0[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports {mii_rxd_0[*]}]
set_property IOSTANDARD LVCMOS33 [get_ports mii_rx_dv_0]
set_property IOSTANDARD LVCMOS33 [get_ports mii_rx_clk_0]
set_property IOSTANDARD LVCMOS33 [get_ports mii_tx_clk_0]
set_property PACKAGE_PIN N16 [get_ports mii_tx_en_0]
set_property PACKAGE_PIN L14 [get_ports mii_tx_clk_0]
set_property PACKAGE_PIN K18 [get_ports mii_rx_dv_0]
set_property PACKAGE_PIN K17 [get_ports mii_rx_clk_0]
set_property PACKAGE_PIN J14 [get_ports {mii_rxd_0[0]}]
set_property PACKAGE_PIN K14 [get_ports {mii_rxd_0[1]}]
set_property PACKAGE_PIN M18 [get_ports {mii_rxd_0[2]}]
set_property PACKAGE_PIN M17 [get_ports {mii_rxd_0[3]}]
set_property PACKAGE_PIN M14 [get_ports {mii_txd_0[0]}]
set_property PACKAGE_PIN L15 [get_ports {mii_txd_0[1]}]
set_property PACKAGE_PIN M15 [get_ports {mii_txd_0[2]}]
set_property PACKAGE_PIN N15 [get_ports {mii_txd_0[3]}]
set_property PACKAGE_PIN G14 [get_ports mdio_rtl_0_mdc]
set_property PACKAGE_PIN J15 [get_ports mdio_rtl_0_mdio_io]
set_property PACKAGE_PIN H20 [get_ports reset_rtl_0]
set_property SLEW FAST [get_ports mdio_rtl_0_mdc]
set_property SLEW FAST [get_ports mdio_rtl_0_mdio_io]
set_property SLEW SLOW [get_ports reset_rtl_0]
set_property SLEW FAST [get_ports mii_tx_en_0]
set_property SLEW FAST [get_ports {mii_txd_0[*]}]

set_property BITSTREAM.GENERAL.COMPRESS True [current_design]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins psd/clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0]] -group [get_clocks clk_fpga_0]
