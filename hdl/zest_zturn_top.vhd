-- zest_zturn_top.vhd - Top-level for the Z-Turn board zeST implementation
--
-- Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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
		LCD_DATA : out std_logic_vector(15 downto 0);
		LCD_VSYNC : out std_logic;
		LCD_HSYNC : out std_logic;
		LCD_DE : out std_logic;
		LCD_PCLK : out std_logic;
		LEDS : out std_logic_vector(2 downto 0);  -- (2=>Rn,1=>Bn,0=>Gn)
		I2C0_SCL : inout std_logic;
		I2C0_SDA : inout std_logic;
		I2S_SCLK : out std_logic;
		I2S_FSYNC_OUT : out std_logic;
		I2S_DOUT : out std_logic;
		MEMS_INTn : in std_logic;
		HDMI_INTn : in std_logic
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
			IIC_0_scl_i : in std_logic;
			IIC_0_scl_o : out std_logic;
			IIC_0_scl_t : out std_logic;
			IIC_0_sda_i : in std_logic;
			IIC_0_sda_o : out std_logic;
			IIC_0_sda_t : out std_logic;
			IRQ_F2P : in std_logic_vector(1 downto 0);
			bridge_addr : out std_logic_vector(15 downto 2);
			bridge_r : out std_logic;
			bridge_r_data : in std_logic_vector(31 downto 0);
			bridge_w : out std_logic;
			bridge_w_data : out std_logic_vector(31 downto 0);
			bridge_w_strb : out std_logic_vector(3 downto 0);
			clk : out std_logic;
			ram_a : in std_logic_vector(31 downto 0);
			ram_ds : in std_logic_vector(1 downto 0);
			ram_error : out std_logic;
			ram_r : in std_logic;
			ram_r_d : out std_logic_vector(15 downto 0);
			ram_r_done : out std_logic;
			ram_w : in std_logic;
			ram_w_d : in std_logic_vector(15 downto 0);
			ram_w_done : out std_logic;
			resetn : out std_logic;
			vid_clk : out std_logic
		);
	end component;

	signal clk			: std_logic;
	signal resetn		: std_logic;
	signal irq_f2p		: std_logic_vector(1 downto 0);
	signal led			: std_logic_vector(1 downto 0);

	signal I2C0_scl_i	: std_logic;
	signal I2C0_scl_o	: std_logic;
	signal I2C0_scl_t	: std_logic;
	signal I2C0_sda_i	: std_logic;
	signal I2C0_sda_o	: std_logic;
	signal I2C0_sda_t	: std_logic;

	signal bridge_addr	: std_logic_vector(15 downto 2);
	signal bridge_r		: std_logic;
	signal bridge_r_data: std_logic_vector(31 downto 0);
	signal bridge_w		: std_logic;
	signal bridge_w_data: std_logic_vector(31 downto 0);
	signal bridge_w_strb: std_logic_vector(3 downto 0);

	signal ram_a		: std_logic_vector(31 downto 0);
	signal ram_ds		: std_logic_vector(1 downto 0);
	signal ram_w		: std_logic;
	signal ram_w_d		: std_logic_vector(15 downto 0);
	signal ram_w_done	: std_logic;
	signal ram_r		: std_logic;
	signal ram_r_d		: std_logic_vector(15 downto 0);
	signal ram_r_done	: std_logic;
	signal ram_error	: std_logic;

	signal pclk			: std_logic;
	signal rgb 			: std_logic_vector(23 downto 0);
	signal de			: std_logic;
	signal vsync		: std_logic;
	signal hsync		: std_logic;

	signal sound_l		: std_logic_vector(15 downto 0);
	signal sound_r		: std_logic_vector(15 downto 0);

begin
	LEDS <= led(1) & '1' & led(0);
	LCD_PCLK <= pclk;
	LCD_DATA <= rgb(23 downto 19) & rgb(15 downto 10) & rgb(7 downto 3);
	LCD_VSYNC <= vsync;
	LCD_HSYNC <= hsync;
	LCD_DE <= de;
	irq_f2p(1) <= '0';

	I2C0_SCL <= I2C0_scl_o when I2C0_scl_t = '0' else 'Z';
	I2C0_scl_i <= I2C0_SCL;
	I2C0_SDA <= I2C0_sda_o when I2C0_sda_t = '0' else 'Z';
	I2C0_sda_i <= I2C0_SDA;
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
		IIC_0_scl_i => I2C0_scl_i,
		IIC_0_scl_o => I2C0_scl_o,
		IIC_0_scl_t => I2C0_scl_t,
		IIC_0_sda_i => I2C0_sda_i,
		IIC_0_sda_o => I2C0_sda_o,
		IIC_0_sda_t => I2C0_sda_t,
		IRQ_F2P => irq_f2p,
		bridge_addr => bridge_addr,
		bridge_r => bridge_r,
		bridge_r_data => bridge_r_data,
		bridge_w => bridge_w,
		bridge_w_data => bridge_w_data,
		bridge_w_strb => bridge_w_strb,
		clk => clk,
		ram_a => ram_a,
		ram_ds => ram_ds,
		ram_error => ram_error,
		ram_r => ram_r,
		ram_r_d => ram_r_d,
		ram_r_done => ram_r_done,
		ram_w => ram_w,
		ram_w_d => ram_w_d,
		ram_w_done => ram_w_done,
		resetn => resetn,
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

		pclk => pclk,
		rgb => rgb,
		de => de,
		vsync => vsync,
		hsync => hsync,

		sound_clk => open,
		sound_l => sound_l,
		sound_r => sound_r
	);

	sndout:entity i2s_output port map (
		clk => pclk,
		resetn => resetn,
		data_l => sound_l,
		data_r => sound_r,
		i2s_sck => I2S_SCLK,
		i2s_fs => I2S_FSYNC_OUT,
		i2s_sd => I2S_DOUT
	);

end structure;
