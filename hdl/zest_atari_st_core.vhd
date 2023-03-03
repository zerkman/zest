-- zest_atari_st_core.vhd - Atari ST core for zeST
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

entity zest_atari_st_core is
	generic (
		-- bridge bus defines
		DATA_WIDTH_BITS	: integer := 5;
		ADDR_WIDTH		: integer := 16;
		SUBADDR_WIDTH	: integer := 13;
		CFG_ADDR_WIDTH	: integer := 6;
		N_OUTPUTS		: integer := 2
	);
	port (
		clk				: in std_logic;
		resetn			: in std_logic;

		-- board LEDs
		led				: out std_logic_vector(1 downto 0);

		-- bridge host signals
		bridge_addr		: in std_logic_vector(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
		bridge_r		: in std_logic;
		bridge_r_data	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w		: in std_logic;
		bridge_w_data	: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w_strb	: in std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);

		-- interrupt
		irq				: out std_logic;

		-- ram interface signals
		ram_a			: out std_logic_vector(31 downto 0);
		ram_ds			: out std_logic_vector(1 downto 0);
		ram_r			: out std_logic;
		ram_r_d			: in std_logic_vector(15 downto 0);
		ram_r_done		: in std_logic;
		ram_w			: out std_logic;
		ram_w_d			: out std_logic_vector(15 downto 0);
		ram_w_done		: in std_logic;

		-- video
		pclk			: in std_logic;		-- independent clock
		rgb				: out std_logic_vector(23 downto 0);
		de				: out std_logic;
		vsync			: out std_logic;
		hsync			: out std_logic;

		-- sound
		sound_clk		: out std_logic;	-- coherent with pclk
		sound_l			: out std_logic_vector(15 downto 0);
		sound_r			: out std_logic_vector(15 downto 0)
	);
end zest_atari_st_core;


architecture structure of zest_atari_st_core is
	signal soft_resetn	: std_logic;
	signal clken		: std_logic;

	signal dev_addr		: std_logic_vector(SUBADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
	signal dev_r		: std_logic_vector(N_OUTPUTS-1 downto 0);
	signal dev_r_data	: std_logic_vector((2**DATA_WIDTH_BITS)*N_OUTPUTS-1 downto 0);
	signal dev_w		: std_logic_vector(N_OUTPUTS-1 downto 0);
	signal dev_w_data	: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal dev_w_strb	: std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);

	signal clken_err	: std_logic;
	signal st_rgb 		: std_logic_vector(8 downto 0);
	signal monomon		: std_logic;
	signal mem_top		: std_logic_vector(3 downto 0);
	signal wakestate	: std_logic_vector(1 downto 0);
	signal ikbd_clkren	: std_logic;
	signal ikbd_clkfen	: std_logic;
	signal ikbd_clk		: std_logic;
	signal ikbd_reset	: std_logic;
	signal ikbd_rx		: std_logic;
	signal ikbd_tx		: std_logic;
	signal ikbd_j0		: std_logic_vector(4 downto 0);
	signal ikbd_j1		: std_logic_vector(4 downto 0);
	signal ikbd_k		: std_logic_vector(94 downto 0);

	signal fdd_read_datan	: std_logic;
	signal fdd_side0		: std_logic;
	signal fdd_indexn		: std_logic;
	signal fdd_drv0_select	: std_logic;
	signal fdd_drv1_select	: std_logic;
	signal fdd_motor_on		: std_logic;
	signal fdd_direction	: std_logic;
	signal fdd_step			: std_logic;
	signal fdd_write_data	: std_logic;
	signal fdd_write_gate	: std_logic;
	signal fdd_track0n		: std_logic;
	signal fdd_write_protn	: std_logic;

	signal ram_A_23		: std_logic_vector(23 downto 1);

	signal in_reg0		: std_logic_vector(31 downto 0);
	signal in_reg1		: std_logic_vector(31 downto 0);
	signal in_reg8_11	: std_logic_vector(127 downto 0);
	signal out_reg0		: std_logic_vector(31 downto 0);
	signal out_reg1		: std_logic_vector(31 downto 0);
	signal out_reg2		: std_logic_vector(31 downto 0);
	signal out_reg3		: std_logic_vector(31 downto 0);
	signal out_reg4		: std_logic_vector(31 downto 0);
	signal out_reg5		: std_logic_vector(31 downto 0);
	signal out_reg6		: std_logic_vector(31 downto 0);
	signal out_reg7		: std_logic_vector(31 downto 0);
	signal out_reg8_11	: std_logic_vector(127 downto 0);

	signal pclken		: std_logic;
	signal st_de		: std_logic;
	signal pix			: std_logic_vector(15 downto 0);
	signal st_vsync		: std_logic;
	signal st_hsync		: std_logic;
	signal ppix			: std_logic_vector(15 downto 0);
	signal pvsync		: std_logic;
	signal phsync		: std_logic;
	signal pde			: std_logic;

	signal isound		: std_logic_vector(15 downto 0);
	signal sound		: std_logic_vector(15 downto 0);
	signal sound_vol	: std_logic_vector(4 downto 0);

	signal dblpix		: std_logic_vector(15 downto 0);
	signal dblpix24		: std_logic_vector(23 downto 0);
	signal dblvsync		: std_logic;
	signal dblhsync		: std_logic;
	signal dblde		: std_logic;
	signal opix			: std_logic_vector(23 downto 0);
	signal ovsync		: std_logic;
	signal ohsync		: std_logic;
	signal ode			: std_logic;

begin
	soft_resetn <= out_reg0(0);
	led <= not clken_err & (fdd_drv0_select or not soft_resetn);
	-- rgb <= opix(23 downto 19) & opix(15 downto 10) & opix(7 downto 3);

	dblpix24 <= dblpix(15 downto 11) & "000" & dblpix(10 downto 5) & "00" & dblpix(4 downto 0) & "000";
	ram_a <= x"00" & ram_a_23 & '0';
	monomon <= out_reg0(2);
	mem_top <= out_reg0(7 downto 4);
	wakestate <= out_reg0(9 downto 8);
	sound_vol <= out_reg0(14 downto 10);
	in_reg0(12 downto 0) <= (others => '0');

	dispatch: entity bridge_dispatcher port map (
		host_addr => bridge_addr,
		host_r => bridge_r,
		host_r_data => bridge_r_data,
		host_w => bridge_w,
		host_w_data => bridge_w_data,
		host_w_strb => bridge_w_strb,
		dev_addr => dev_addr,
		dev_r => dev_r,
		dev_r_data => dev_r_data,
		dev_w => dev_w,
		dev_w_data => dev_w_data,
		dev_w_strb => dev_w_strb
	);

	config: entity configurator port map (
		clk => clk,
		resetn => resetn,
		bridge_addr => dev_addr(CFG_ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3),
		bridge_r => dev_r(0),
		bridge_r_data => dev_r_data((2**DATA_WIDTH_BITS)*1-1 downto (2**DATA_WIDTH_BITS)*0),
		bridge_w => dev_w(0),
		bridge_w_data => dev_w_data,
		bridge_w_strb => dev_w_strb,
		out_reg0 => out_reg0,
		out_reg1 => out_reg1,
		out_reg2 => out_reg2,
		out_reg3 => out_reg3,
		out_reg4 => out_reg4,
		out_reg5 => out_reg5,
		out_reg6 => out_reg6,
		out_reg7 => out_reg7,
		out_reg8_11 => out_reg8_11,
		in_reg0 => in_reg0,
		in_reg1 => in_reg1,
		in_reg8_11 => in_reg8_11
	);

	osd: entity on_screen_display port map (
		clk => clk,
		resetn => resetn,
		bridge_addr => dev_addr,
		bridge_r => dev_r(1),
		bridge_r_data => dev_r_data((2**DATA_WIDTH_BITS)*2-1 downto (2**DATA_WIDTH_BITS)*1),
		bridge_w => dev_w(1),
		bridge_w_data => dev_w_data,
		bridge_w_strb => dev_w_strb,
		pclk => pclk,
		idata => dblpix24,
		ivsync => dblvsync,
		ihsync => dblhsync,
		ide => dblde,
		odata => rgb,
		ovsync => vsync,
		ohsync => hsync,
		ode => de,
		intr => open
	);

	atarist:entity atarist_mb port map(
		clk => clk,
		resetn => soft_resetn,
		clken => clken,
		clken_error => clken_err,
		monomon => monomon,
		mem_top	=> mem_top,
		wakestate => wakestate,
		pclken => pclken,
		de => st_de,
		hsync => st_hsync,
		vsync => st_vsync,
		rgb => st_rgb,
		sound_vol => sound_vol,
		sound_clk => open,
		sound => isound,
		ikbd_clkren => ikbd_clkren,
		ikbd_clkfen => ikbd_clkfen,
		ikbd_rx => ikbd_rx,
		ikbd_tx => ikbd_tx,
		fdd_read_datan => fdd_read_datan,
		fdd_side0 => fdd_side0,
		fdd_indexn => fdd_indexn,
		fdd_drv0_select => fdd_drv0_select,
		fdd_drv1_select => fdd_drv1_select,
		fdd_motor_on => fdd_motor_on,
		fdd_direction => fdd_direction,
		fdd_step => fdd_step,
		fdd_write_data => fdd_write_data,
		fdd_write_gate => fdd_write_gate,
		fdd_track0n => fdd_track0n,
		fdd_write_protn => fdd_write_protn,
		a => ram_a_23,
		ds => ram_ds,
		r => ram_r,
		r_done => ram_r_done,
		w => ram_w,
		w_done => ram_w_done,
		od => ram_r_d,
		id => ram_w_d
	);

	fdd:entity floppy_drive port map (
		clk => clk,
		clken => clken,
		resetn => soft_resetn,

		read_datan => fdd_read_datan,
		side0 => fdd_side0,
		indexn => fdd_indexn,
		drv_select => fdd_drv0_select,
		motor_on => fdd_motor_on,
		direction => fdd_direction,
		step => fdd_step,
		write_data => fdd_write_data,
		write_gate => fdd_write_gate,
		track0n => fdd_track0n,
		write_protn => fdd_write_protn,

		host_intr => irq,
		host_din => in_reg8_11,
		host_dout => out_reg8_11,
		host_r => in_reg0(31),
		host_w => in_reg0(30),
		host_addr => in_reg0(29 downto 21),
		host_track => in_reg0(20 downto 13)
	);

	ikbd_clk <= clk;
	ikbd_reset <= not soft_resetn;
	ikbd_j0 <= out_reg7(26 downto 22);
	ikbd_j1 <= out_reg7(31 downto 27);
	ikbd_k <= out_reg6(30 downto 0) & out_reg5 & out_reg4;
	ikbd:entity atari_ikbd port map (
		clk => ikbd_clk,
		clkren => ikbd_clkren,
		clkfen => ikbd_clkfen,
		reset => ikbd_reset,
		rx => ikbd_tx,
		tx => ikbd_rx,
		j0 => ikbd_j0,
		j1 => ikbd_j1,
		k => ikbd_k
	);

	pix <= st_rgb(8 downto 6) & "00" & st_rgb(5 downto 3) & "000" & st_rgb(2 downto 0) & "00";
	clkconv:entity vclkconvert port map(
		clk => clk,
		clken => pclken,
		pclk => pclk,
		resetn => soft_resetn,
		ivsync => st_vsync,
		ihsync => st_hsync,
		ide => st_de,
		ipix => pix,
		isndck => '0',
		isound => isound,
		ovsync => pvsync,
		ohsync => phsync,
		ode => pde,
		opix => ppix,
		osndck => sound_clk,
		osound => sound
	);
	sound_l <= sound;
	sound_r <= sound;

	scandbl:entity scan_dbl port map (
		clk => pclk,
		resetn => soft_resetn,
		passthru => monomon,
		IN_DATA => ppix,
		IN_VSYNC => pvsync,
		IN_HSYNC => phsync,
		IN_DE => pde,
		OUT_DATA => dblpix,
		OUT_VSYNC => dblvsync,
		OUT_HSYNC => dblhsync,
		OUT_DE => dblde
	);

end structure;