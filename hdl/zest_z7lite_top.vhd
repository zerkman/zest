-- zest_z7lite_top.vhd - Top-level for the Z7-Lite board zeST implementation
--
-- Copyright (c) 2021-2025 Francois Galea <fgalea at free.fr>
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <https://www.gnu.org/licenses/>.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library zhdmi;

library work;
use work.all;

entity zest_top is
	port (
		DDR_addr : inout std_logic_vector(14 downto 0);
		DDR_ba : inout std_logic_vector(2 downto 0);
		DDR_cas_n : inout std_logic;
		DDR_ck_n : inout std_logic;
		DDR_ck_p : inout std_logic;
		DDR_cke : inout std_logic;
		DDR_cs_n : inout std_logic;
		DDR_dm : inout std_logic_vector(3 downto 0);
		DDR_dq : inout std_logic_vector(31 downto 0);
		DDR_dqs_n : inout std_logic_vector(3 downto 0);
		DDR_dqs_p : inout std_logic_vector(3 downto 0);
		DDR_odt : inout std_logic;
		DDR_ras_n : inout std_logic;
		DDR_reset_n : inout std_logic;
		DDR_we_n : inout std_logic;
		FIXED_IO_ddr_vrn : inout std_logic;
		FIXED_IO_ddr_vrp : inout std_logic;
		FIXED_IO_mio : inout std_logic_vector(53 downto 0);
		FIXED_IO_ps_clk : inout std_logic;
		FIXED_IO_ps_porb : inout std_logic;
		FIXED_IO_ps_srstb : inout std_logic;
		led : out std_logic_vector(1 downto 0);
		reset_rtl_0 : out std_logic;
		mdio_rtl_0_mdc : out std_logic;
		mdio_rtl_0_mdio_io : inout std_logic;
		mii_tx_clk_0 : in std_logic;
		mii_tx_en_0 : out std_logic;
		mii_txd_0 : out std_logic_vector(3 downto 0);
		mii_rx_clk_0 : in std_logic;
		mii_rx_dv_0 : in std_logic;
		mii_rxd_0 : in std_logic_vector(3 downto 0);
		hdmi_tx_clk_n : out std_logic;
		hdmi_tx_clk_p : out std_logic;
		hdmi_tx_d_n : out std_logic_vector(2 downto 0);
		hdmi_tx_d_p : out std_logic_vector(2 downto 0)
	);
end zest_top;


architecture structure of zest_top is
	component ps_domain is
		port (
			DDR_addr : inout std_logic_vector(14 downto 0);
			DDR_ba : inout std_logic_vector(2 downto 0);
			DDR_cas_n : inout std_logic;
			DDR_ck_n : inout std_logic;
			DDR_ck_p : inout std_logic;
			DDR_cke : inout std_logic;
			DDR_cs_n : inout std_logic;
			DDR_dm : inout std_logic_vector(3 downto 0);
			DDR_dq : inout std_logic_vector(31 downto 0);
			DDR_dqs_n : inout std_logic_vector(3 downto 0);
			DDR_dqs_p : inout std_logic_vector(3 downto 0);
			DDR_odt : inout std_logic;
			DDR_ras_n : inout std_logic;
			DDR_reset_n : inout std_logic;
			DDR_we_n : inout std_logic;
			FIXED_IO_ddr_vrn : inout std_logic;
			FIXED_IO_ddr_vrp : inout std_logic;
			FIXED_IO_mio : inout std_logic_vector(53 downto 0);
			FIXED_IO_ps_clk : inout std_logic;
			FIXED_IO_ps_porb : inout std_logic;
			FIXED_IO_ps_srstb : inout std_logic;
			GMII_ETHERNET_0_0_col : in std_logic;
			GMII_ETHERNET_0_0_crs : in std_logic;
			GMII_ETHERNET_0_0_rx_clk : in std_logic;
			GMII_ETHERNET_0_0_rx_dv : in std_logic;
			GMII_ETHERNET_0_0_rx_er : in std_logic;
			GMII_ETHERNET_0_0_rxd : in std_logic_vector(7 downto 0);
			GMII_ETHERNET_0_0_tx_clk : in std_logic;
			GMII_ETHERNET_0_0_tx_en : out std_logic_vector(0 to 0);
			GMII_ETHERNET_0_0_tx_er : out std_logic_vector(0 to 0);
			GMII_ETHERNET_0_0_txd : out std_logic_vector(7 downto 0);
			MDIO_ETHERNET_0_0_mdc : out std_logic;
			MDIO_ETHERNET_0_0_mdio_i : in std_logic;
			MDIO_ETHERNET_0_0_mdio_o : out std_logic;
			MDIO_ETHERNET_0_0_mdio_t : out std_logic;
			bridge_addr : out std_logic_vector(15 downto 2);
			bridge_r : out std_logic;
			bridge_r_data : in std_logic_vector(31 downto 0);
			bridge_w : out std_logic;
			bridge_w_data : out std_logic_vector(31 downto 0);
			bridge_w_strb : out std_logic_vector(3 downto 0);
			clk : out std_logic;
			irq_f2p : in std_logic_vector(1 downto 0);
			ram_a : in std_logic_vector(31 downto 0);
			ram_ds : in std_logic_vector(1 downto 0);
			ram_error : out std_logic;
			ram_r : in std_logic;
			ram_r_d : out std_logic_vector(15 downto 0);
			ram_r_done : out std_logic;
			ram_w : in std_logic;
			ram_w_d : in std_logic_vector(15 downto 0);
			ram_w_done : out std_logic;
			rom_a : in std_logic_vector(31 downto 0);
			rom_r : in std_logic;
			rom_r_d : out std_logic_vector(15 downto 0);
			rom_r_done : out std_logic;
			turboram_a : in std_logic_vector(31 downto 0);
			turboram_ds : in std_logic_vector(1 downto 0);
			turboram_r : in std_logic;
			turboram_r_d : out std_logic_vector(15 downto 0);
			turboram_r_done : out std_logic;
			turboram_w : in std_logic;
			turboram_w_d : in std_logic_vector(15 downto 0);
			turboram_w_done : out std_logic;
			resetn : out std_logic;
			vid5_clk : out std_logic;
			vid_clk : out std_logic
		);
	end component;

	signal clk			: std_logic;
	signal resetn		: std_logic;
	signal reset		: std_logic;
	signal irq_f2p		: std_logic_vector(1 downto 0);

	signal GMII_ETHERNET_0_0_col    : std_logic;
	signal GMII_ETHERNET_0_0_crs    : std_logic;
	signal GMII_ETHERNET_0_0_rx_clk : std_logic;
	signal GMII_ETHERNET_0_0_rx_dv  : std_logic;
	signal GMII_ETHERNET_0_0_rx_er  : std_logic;
	signal GMII_ETHERNET_0_0_rxd    : std_logic_vector(7 downto 0);
	signal GMII_ETHERNET_0_0_tx_clk : std_logic;
	signal GMII_ETHERNET_0_0_tx_en  : std_logic_vector(0 to 0);
	signal GMII_ETHERNET_0_0_tx_er  : std_logic_vector(0 to 0);
	signal GMII_ETHERNET_0_0_txd    : std_logic_vector(7 downto 0);
	signal MDIO_ETHERNET_0_0_mdc    : std_logic;
	signal MDIO_ETHERNET_0_0_mdio_i : std_logic;
	signal MDIO_ETHERNET_0_0_mdio_o : std_logic;
	signal MDIO_ETHERNET_0_0_mdio_t : std_logic;

	signal clken_err	: std_logic;

	signal bridge_addr 	: std_logic_vector(15 downto 2);
	signal bridge_r 	: std_logic;
	signal bridge_r_data: std_logic_vector(31 downto 0);
	signal bridge_w 	: std_logic;
	signal bridge_w_data: std_logic_vector(31 downto 0);
	signal bridge_w_strb: std_logic_vector(3 downto 0);
	signal ram_a 		: std_logic_vector(31 downto 0);
	signal ram_ds 		: std_logic_vector(1 downto 0);
	signal ram_error 	: std_logic;
	signal ram_r 		: std_logic;
	signal ram_r_d 		: std_logic_vector(15 downto 0);
	signal ram_r_done 	: std_logic;
	signal ram_w 		: std_logic;
	signal ram_w_d 		: std_logic_vector(15 downto 0);
	signal ram_w_done 	: std_logic;
	signal rom_a 		: std_logic_vector(31 downto 0);
	signal rom_r 		: std_logic;
	signal rom_r_d 		: std_logic_vector(15 downto 0);
	signal rom_r_done 	: std_logic;
	signal turboram_a		: std_logic_vector(31 downto 0);
	signal turboram_ds		: std_logic_vector(1 downto 0);
	signal turboram_w		: std_logic;
	signal turboram_w_d		: std_logic_vector(15 downto 0);
	signal turboram_w_done	: std_logic;
	signal turboram_r		: std_logic;
	signal turboram_r_d		: std_logic_vector(15 downto 0);
	signal turboram_r_done	: std_logic;

	signal pclk			: std_logic;
	signal p5clk		: std_logic;
	signal rgb			: std_logic_vector(23 downto 0);
	signal de			: std_logic;
	signal vsync		: std_logic;
	signal hsync		: std_logic;

	signal sound_clk	: std_logic;
	signal sound_l		: std_logic_vector(15 downto 0);
	signal sound_r		: std_logic_vector(15 downto 0);
	signal sound24_l	: std_logic_vector(23 downto 0);
	signal sound24_r	: std_logic_vector(23 downto 0);

begin
	reset <= not resetn;

	psd:ps_domain port map(
		DDR_addr => DDR_addr,
		DDR_ba => DDR_ba,
		DDR_cas_n => DDR_cas_n,
		DDR_ck_n => DDR_ck_n,
		DDR_ck_p => DDR_ck_p,
		DDR_cke => DDR_cke,
		DDR_cs_n => DDR_cs_n,
		DDR_dm => DDR_dm,
		DDR_dq => DDR_dq,
		DDR_dqs_n => DDR_dqs_n,
		DDR_dqs_p => DDR_dqs_p,
		DDR_odt => DDR_odt,
		DDR_ras_n => DDR_ras_n,
		DDR_reset_n => DDR_reset_n,
		DDR_we_n => DDR_we_n,
		FIXED_IO_ddr_vrn => FIXED_IO_ddr_vrn,
		FIXED_IO_ddr_vrp => FIXED_IO_ddr_vrp,
		FIXED_IO_mio => FIXED_IO_mio,
		FIXED_IO_ps_clk => FIXED_IO_ps_clk,
		FIXED_IO_ps_porb => FIXED_IO_ps_porb,
		FIXED_IO_ps_srstb => FIXED_IO_ps_srstb,
		GMII_ETHERNET_0_0_col => GMII_ETHERNET_0_0_col,
		GMII_ETHERNET_0_0_crs => GMII_ETHERNET_0_0_crs,
		GMII_ETHERNET_0_0_rx_clk => GMII_ETHERNET_0_0_rx_clk,
		GMII_ETHERNET_0_0_rx_dv => GMII_ETHERNET_0_0_rx_dv,
		GMII_ETHERNET_0_0_rx_er => GMII_ETHERNET_0_0_rx_er,
		GMII_ETHERNET_0_0_rxd => GMII_ETHERNET_0_0_rxd,
		GMII_ETHERNET_0_0_tx_clk => GMII_ETHERNET_0_0_tx_clk,
		GMII_ETHERNET_0_0_tx_en => GMII_ETHERNET_0_0_tx_en,
		GMII_ETHERNET_0_0_tx_er => GMII_ETHERNET_0_0_tx_er,
		GMII_ETHERNET_0_0_txd => GMII_ETHERNET_0_0_txd,
		MDIO_ETHERNET_0_0_mdc => MDIO_ETHERNET_0_0_mdc,
		MDIO_ETHERNET_0_0_mdio_i => MDIO_ETHERNET_0_0_mdio_i,
		MDIO_ETHERNET_0_0_mdio_o => MDIO_ETHERNET_0_0_mdio_o,
		MDIO_ETHERNET_0_0_mdio_t => MDIO_ETHERNET_0_0_mdio_t,
		bridge_addr => bridge_addr,
		bridge_r => bridge_r,
		bridge_r_data => bridge_r_data,
		bridge_w => bridge_w,
		bridge_w_data => bridge_w_data,
		bridge_w_strb => bridge_w_strb,
		clk => clk,
		irq_f2p => irq_f2p,
		ram_a => ram_a,
		ram_ds => ram_ds,
		ram_error => ram_error,
		ram_r => ram_r,
		ram_r_d => ram_r_d,
		ram_r_done => ram_r_done,
		ram_w => ram_w,
		ram_w_d => ram_w_d,
		ram_w_done => ram_w_done,
		rom_a => rom_a,
		rom_r => rom_r,
		rom_r_d => rom_r_d,
		rom_r_done => rom_r_done,
		turboram_a => turboram_a,
		turboram_ds => turboram_ds,
		turboram_r => turboram_r,
		turboram_r_d => turboram_r_d,
		turboram_r_done => turboram_r_done,
		turboram_w => turboram_w,
		turboram_w_d => turboram_w_d,
		turboram_w_done => turboram_w_done,
		resetn => resetn,
		vid5_clk => p5clk,
		vid_clk => pclk
	);

	core:entity zest_atari_st_core port map(
		clk => clk,
		resetn => resetn,
		led => led,

		bridge_addr => bridge_addr,
		bridge_r => bridge_r,
		bridge_r_data => bridge_r_data,
		bridge_w => bridge_w,
		bridge_w_data => bridge_w_data,
		bridge_w_strb => bridge_w_strb,
		irq => irq_f2p(0),

		ram_a => ram_a,
		ram_ds => ram_ds,
		ram_r => ram_r,
		ram_r_d => ram_r_d,
		ram_r_done => ram_r_done,
		ram_w => ram_w,
		ram_w_d => ram_w_d,
		ram_w_done => ram_w_done,
		rom_a => rom_a,
		rom_r => rom_r,
		rom_r_d => rom_r_d,
		rom_r_done => rom_r_done,
		turboram_a => turboram_a,
		turboram_ds => turboram_ds,
		turboram_r => turboram_r,
		turboram_r_d => turboram_r_d,
		turboram_r_done => turboram_r_done,
		turboram_w => turboram_w,
		turboram_w_d => turboram_w_d,
		turboram_w_done => turboram_w_done,

		pclk => pclk,
		rgb => rgb,
		de => de,
		vsync => vsync,
		hsync => hsync,

		sound_clk => sound_clk,
		sound_l => sound_l,
		sound_r => sound_r
	);

	sound24_l <= sound_l & x"00";
	sound24_r <= sound_r & x"00";
	hdmi:entity zhdmi.hdmi_tx port map (
		clk => pclk,
		sclk => p5clk,
		reset => reset,
		rgb => rgb,
		vsync => vsync,
		hsync => hsync,
		de => de,
		audio_en => '1',
		audio_l => sound24_l,
		audio_r => sound24_r,
		audio_clk => sound_clk,
		tx_clk_n => hdmi_tx_clk_n,
		tx_clk_p => hdmi_tx_clk_p,
		tx_d_n => hdmi_tx_d_n,
		tx_d_p => hdmi_tx_d_p
	);

	-- On the Z7-Lite board, Ethernet PHY is connected to the PL.
	-- As the PHY is 10/100mbit it uses MII (Media-independent interface).
	-- Zynq's Ethernet is gigabit so it uses GMII (Gigabit MII), which is backwards
	-- compatible.
	reset_rtl_0 <= not resetn;
	mdio_rtl_0_mdc <= MDIO_ETHERNET_0_0_mdc;
	mdio_rtl_0_mdio_io <= MDIO_ETHERNET_0_0_mdio_o when MDIO_ETHERNET_0_0_mdio_t = '0' else 'Z';
	MDIO_ETHERNET_0_0_mdio_i <= mdio_rtl_0_mdio_io;
	GMII_ETHERNET_0_0_tx_clk <= mii_tx_clk_0;
	mii_tx_en_0 <= GMII_ETHERNET_0_0_tx_en(0);
	mii_txd_0 <= GMII_ETHERNET_0_0_txd(3 downto 0);
	GMII_ETHERNET_0_0_rx_clk <= mii_rx_clk_0;
	GMII_ETHERNET_0_0_rx_dv <= mii_rx_dv_0;
	GMII_ETHERNET_0_0_rxd <= "0000" & mii_rxd_0;
	GMII_ETHERNET_0_0_col <= '0';
	GMII_ETHERNET_0_0_crs <= '0';
	GMII_ETHERNET_0_0_rx_er <= '0';

end structure;
