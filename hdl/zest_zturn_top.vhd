-- zest_zturn_top.vhd - Top-level for the Z-Turn board zeST implementation
--
-- Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
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

entity zest_top is
	port (
		DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
		DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
		DDR_cas_n : inout STD_LOGIC;
		DDR_ck_n : inout STD_LOGIC;
		DDR_ck_p : inout STD_LOGIC;
		DDR_cke : inout STD_LOGIC;
		DDR_cs_n : inout STD_LOGIC;
		DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
		DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
		DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
		DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
		DDR_odt : inout STD_LOGIC;
		DDR_ras_n : inout STD_LOGIC;
		DDR_reset_n : inout STD_LOGIC;
		DDR_we_n : inout STD_LOGIC;
		FIXED_IO_ddr_vrn : inout STD_LOGIC;
		FIXED_IO_ddr_vrp : inout STD_LOGIC;
		FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
		FIXED_IO_ps_clk : inout STD_LOGIC;
		FIXED_IO_ps_porb : inout STD_LOGIC;
		FIXED_IO_ps_srstb : inout STD_LOGIC;
		LCD_DATA : out std_logic_vector(15 downto 0);
		LCD_VSYNC : out std_logic;
		LCD_HSYNC : out std_logic;
		LCD_DE : out std_logic;
		LCD_PCLK : out std_logic;
		LEDS : out std_logic_vector (2 downto 0);  -- (2=>Rn,1=>Bn,0=>Gn)
		I2C0_SCL : inout STD_LOGIC;
		I2C0_SDA : inout STD_LOGIC;
		MEMS_INTn : in STD_LOGIC;
		HDMI_INTn : in STD_LOGIC
	);
end zest_top;


architecture structure of zest_top is
	component ps_domain_wrapper is
		port (
			A_0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
			DDR_addr : inout STD_LOGIC_VECTOR ( 14 downto 0 );
			DDR_ba : inout STD_LOGIC_VECTOR ( 2 downto 0 );
			DDR_cas_n : inout STD_LOGIC;
			DDR_ck_n : inout STD_LOGIC;
			DDR_ck_p : inout STD_LOGIC;
			DDR_cke : inout STD_LOGIC;
			DDR_cs_n : inout STD_LOGIC;
			DDR_dm : inout STD_LOGIC_VECTOR ( 3 downto 0 );
			DDR_dq : inout STD_LOGIC_VECTOR ( 31 downto 0 );
			DDR_dqs_n : inout STD_LOGIC_VECTOR ( 3 downto 0 );
			DDR_dqs_p : inout STD_LOGIC_VECTOR ( 3 downto 0 );
			DDR_odt : inout STD_LOGIC;
			DDR_ras_n : inout STD_LOGIC;
			DDR_reset_n : inout STD_LOGIC;
			DDR_we_n : inout STD_LOGIC;
			DS_0 : in STD_LOGIC_VECTOR ( 1 downto 0 );
			ERROR_0 : out STD_LOGIC;
			FIXED_IO_ddr_vrn : inout STD_LOGIC;
			FIXED_IO_ddr_vrp : inout STD_LOGIC;
			FIXED_IO_mio : inout STD_LOGIC_VECTOR ( 53 downto 0 );
			FIXED_IO_ps_clk : inout STD_LOGIC;
			FIXED_IO_ps_porb : inout STD_LOGIC;
			FIXED_IO_ps_srstb : inout STD_LOGIC;
			IIC_0_0_scl_io : inout STD_LOGIC;
			IIC_0_0_sda_io : inout STD_LOGIC;
			IRQ_F2P_0 : in STD_LOGIC_VECTOR ( 0 to 0 );
			OFFSET_0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
			OFFVALD_0 : in STD_LOGIC;
			R_0 : in STD_LOGIC;
			R_DONE_0 : out STD_LOGIC;
			W_0 : in STD_LOGIC;
			W_DONE_0 : out STD_LOGIC;
			clk : out STD_LOGIC;
			iD_0 : in STD_LOGIC_VECTOR ( 15 downto 0 );
			in_reg0_0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
			in_reg1_0 : in STD_LOGIC_VECTOR ( 31 downto 0 );
			oD_0 : out STD_LOGIC_VECTOR ( 15 downto 0 );
			out_reg0_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg1_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg2_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg3_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg4_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg5_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg6_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			out_reg7_0 : out STD_LOGIC_VECTOR ( 31 downto 0 );
			resetn : out STD_LOGIC;
			vid_clk : out STD_LOGIC
		);
	end component;

	component atarist_main is
		port (
			clk : in std_logic;
			resetn : in std_logic;

			clken_error : out std_logic;
			monomon : in std_logic;
			mem_top	: in std_logic_vector(3 downto 0);

			pclken : out std_logic;
			de : out std_logic;
			hsync : out std_logic;
			vsync : out std_logic;
			rgb : out std_logic_vector(8 downto 0);

			ikbd_clkren : out std_logic;
			ikbd_clkfen : out std_logic;
			ikbd_rx : in std_logic;
			ikbd_tx : out std_logic;

			fdd_clken : out std_logic;
			fdd_read_datan : in std_logic;
			fdd_side0 : out std_logic;
			fdd_indexn : in std_logic;
			fdd_drv0_select : out std_logic;
			fdd_drv1_select : out std_logic;
			fdd_motor_on : out std_logic;
			fdd_direction : out std_logic;
			fdd_step : out std_logic;
			fdd_write_data : out std_logic;
			fdd_write_gate : out std_logic;
			fdd_track0n : in std_logic;
			fdd_write_protn : in std_logic;

			a : out std_logic_vector(23 downto 1);
			ds : out std_logic_vector(1 downto 0);
			r : out std_logic;
			r_done : in std_logic;
			w : out std_logic;
			w_done : in std_logic;
			od : in std_logic_vector(15 downto 0);
			id : out std_logic_vector(15 downto 0)
		);
	end component;

	component floppy_drive is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			read_datan	: out std_logic;
			side0		: in std_logic;
			indexn		: out std_logic;
			drv_select	: in std_logic;
			motor_on	: in std_logic;
			direction	: in std_logic;
			step		: in std_logic;
			write_data	: in std_logic;
			write_gate	: in std_logic;
			track0n		: out std_logic;
			write_protn	: out std_logic;

			host_intr	: out std_logic;
			host_din	: out std_logic_vector(31 downto 0);
			host_dout	: in std_logic_vector(31 downto 0);
			host_r		: out std_logic;
			host_w		: out std_logic;
			host_addr	: out std_logic_vector(10 downto 0);
			host_track	: out std_logic_vector(7 downto 0)
		);
	end component;

	component atari_ikbd is
		port (
			clk		: in std_logic;
			clkren	: in std_logic;
			clkfen	: in std_logic;
			reset	: in std_logic;
			rx		: in std_logic;
			tx		: out std_logic;
			j0		: in std_logic_vector(4 downto 0);
			j1		: in std_logic_vector(4 downto 0);
			k		: in std_logic_vector(94 downto 0)
		);
	end component;

	component vclkconvert is
		port (
			clk     : in std_logic;
			clken	: in std_logic;
			pclk    : in std_logic;
			resetn	: in std_logic;

			ivsync  : in std_logic;
			ihsync  : in std_logic;
			ide     : in std_logic;
			ipix    : in std_logic_vector(15 downto 0);

			ovsync  : out std_logic;
			ohsync  : out std_logic;
			ode     : out std_logic;
			opix    : out std_logic_vector(15 downto 0)
		);
	end component;

	component scan_dbl is
		port (
			clk 	: in std_logic;
			resetn 	: in std_logic;
			passthru : in std_logic;
			IN_DATA : in std_logic_vector(15 downto 0);
			IN_VSYNC : in std_logic;
			IN_HSYNC : in std_logic;
			IN_DE 	: in std_logic;
			OUT_DATA : out std_logic_vector(15 downto 0);
			OUT_VSYNC : out std_logic;
			OUT_HSYNC : out std_logic;
			OUT_DE	: out std_logic
		);
	end component;

	signal clk			: std_logic;
	signal resetn		: std_logic;
	signal pclk			: std_logic;
	signal soft_resetn	: std_logic;
	signal irq_f2p		: std_logic_vector(0 downto 0);

	signal clken_err	: std_logic;
	signal rgb 			: std_logic_vector(8 downto 0);
	signal monomon		: std_logic;
	signal mem_top		: std_logic_vector(3 downto 0);
	signal ikbd_clkren	: std_logic;
	signal ikbd_clkfen	: std_logic;
	signal ikbd_clk		: std_logic;
	signal ikbd_reset	: std_logic;
	signal ikbd_rx		: std_logic;
	signal ikbd_tx		: std_logic;
	signal ikbd_j0		: std_logic_vector(4 downto 0);
	signal ikbd_j1		: std_logic_vector(4 downto 0);
	signal ikbd_k		: std_logic_vector(94 downto 0);

	signal fdd_clken		: std_logic;
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
	signal ram_A		: std_logic_vector(31 downto 0);
	signal ram_iD		: std_logic_vector(15 downto 0);
	signal ram_oD		: std_logic_vector(15 downto 0);
	signal ram_W		: std_logic;
	signal ram_R		: std_logic;
	signal ram_DS		: std_logic_vector(1 downto 0);
	signal ram_W_DONE	: std_logic;
	signal ram_R_DONE	: std_logic;
	signal ram_offset	: std_logic_vector(31 downto 0);
	signal ram_offvald	: std_logic;
	signal ram_error	: std_logic;

	signal in_reg0		: std_logic_vector(31 downto 0);
	signal in_reg1		: std_logic_vector(31 downto 0);
	signal out_reg0		: std_logic_vector(31 downto 0);
	signal out_reg1		: std_logic_vector(31 downto 0);
	signal out_reg2		: std_logic_vector(31 downto 0);
	signal out_reg3		: std_logic_vector(31 downto 0);
	signal out_reg4		: std_logic_vector(31 downto 0);
	signal out_reg5		: std_logic_vector(31 downto 0);
	signal out_reg6		: std_logic_vector(31 downto 0);
	signal out_reg7		: std_logic_vector(31 downto 0);

	signal pclken		: std_logic;
	signal de			: std_logic;
	signal pix			: std_logic_vector(15 downto 0);
	signal vsync		: std_logic;
	signal hsync		: std_logic;
	signal ppix			: std_logic_vector(15 downto 0);
	signal pvsync		: std_logic;
	signal phsync		: std_logic;
	signal pde			: std_logic;

	signal opix			: std_logic_vector(15 downto 0);
	signal ovsync		: std_logic;
	signal ohsync		: std_logic;
	signal ode			: std_logic;

begin
	soft_resetn <= out_reg0(0);
	LEDS <= not clken_err & "11";
	LCD_PCLK <= pclk;
	LCD_DATA <= opix;
	LCD_VSYNC <= ovsync;
	LCD_HSYNC <= ohsync;
	LCD_DE <= ode;
	ram_A <= x"00" & ram_A_23 & '0';
	ram_offvald <= out_reg0(1);
	monomon <= out_reg0(2);
	mem_top <= out_reg0(7 downto 4);

	ram_offset <= out_reg1;
	in_reg0(10 downto 0) <= (others => '0');

	psd:ps_domain_wrapper port map(
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
		IIC_0_0_scl_io => I2C0_SCL,
		IIC_0_0_sda_io => I2C0_SDA,
		IRQ_F2P_0 => irq_f2p,
		clk => clk,
		in_reg0_0 => in_reg0,
		in_reg1_0 => in_reg1,
		out_reg0_0 => out_reg0,
		out_reg1_0 => out_reg1,
		out_reg2_0 => out_reg2,
		out_reg3_0 => out_reg3,
		out_reg4_0 => out_reg4,
		out_reg5_0 => out_reg5,
		out_reg6_0 => out_reg6,
		out_reg7_0 => out_reg7,
		resetn => resetn,
		vid_clk => pclk,
		OFFSET_0 => ram_offset,
		OFFVALD_0 => ram_offvald,
		ERROR_0 => ram_error,
		A_0 => ram_A,
		iD_0 => ram_iD,
		oD_0 => ram_oD,
		W_0 => ram_W,
		R_0 => ram_R,
		DS_0 => ram_DS,
		W_DONE_0 => ram_W_DONE,
		R_DONE_0 => ram_R_DONE
	);

	atarist:atarist_main port map(
		clk => clk,
		resetn => soft_resetn,
		clken_error => clken_err,
		monomon => monomon,
		mem_top	=> mem_top,
		pclken => pclken,
		de => de,
		hsync => hsync,
		vsync => vsync,
		rgb => rgb,
		ikbd_clkren => ikbd_clkren,
		ikbd_clkfen => ikbd_clkfen,
		ikbd_rx => ikbd_rx,
		ikbd_tx => ikbd_tx,
		fdd_clken => fdd_clken,
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
		a => ram_A_23,
		ds => ram_DS,
		r => ram_R,
		r_done => ram_R_DONE,
		w => ram_W,
		w_done => ram_W_DONE,
		od => ram_oD,
		id => ram_iD
	);

	fdd:floppy_drive port map (
		clk => clk,
		clken => fdd_clken,
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

		host_intr => irq_f2p(0),
		host_din => in_reg1,
		host_dout => out_reg2,
		host_r => in_reg0(31),
		host_w => in_reg0(30),
		host_addr => in_reg0(29 downto 19),
		host_track => in_reg0(18 downto 11)
	);

	ikbd_clk <= clk;
	ikbd_reset <= not soft_resetn;
	ikbd_j0 <= out_reg7(26 downto 22);
	ikbd_j1 <= out_reg7(31 downto 27);
	ikbd_k <= out_reg6(30 downto 0) & out_reg5 & out_reg4;
	ikbd:atari_ikbd port map (
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

	pix <= rgb(8 downto 6) & "00" & rgb(5 downto 3) & "000" & rgb(2 downto 0) & "00";
	clkconv:vclkconvert port map(
		clk => clk,
		clken => pclken,
		pclk => pclk,
		resetn => soft_resetn,
		ivsync => vsync,
		ihsync => hsync,
		ide => de,
		ipix => pix,
		ovsync => pvsync,
		ohsync => phsync,
		ode => pde,
		opix => ppix
	);

	scandbl:scan_dbl port map (
		clk => pclk,
		resetn => soft_resetn,
		passthru => monomon,
		IN_DATA => ppix,
		IN_VSYNC => pvsync,
		IN_HSYNC => phsync,
		IN_DE => pde,
		OUT_DATA => opix,
		OUT_VSYNC => ovsync,
		OUT_HSYNC => ohsync,
		OUT_DE => ode
	);

end structure;
