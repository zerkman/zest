-- zest_sim_top.vhd - Top level for zeST simulation
--
-- Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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

entity zest_sim_top is
end zest_sim_top;


architecture dut of zest_sim_top is

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
			fdd_drv_select : out std_logic;
			fdd_motor_on : out std_logic;
			fdd_direction : out std_logic;
			fdd_stepn : out std_logic;
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

	component simple_ram is
		generic (
			MEM_SIZE	: integer	:= 32768
		);
		port (
			clk		: in std_logic;
			resetn	: in std_logic;

			-- address
			A		: in std_logic_vector(23 downto 1);
			-- input data
			iD		: in std_logic_vector(15 downto 0);
			-- output data
			oD		: out std_logic_vector(15 downto 0);
			-- initiate write transaction
			W		: in std_logic;
			-- initiate read transaction
			R		: in std_logic;
			-- data strobe (for each byte of the data bus)
			DS		: in std_logic_vector(1 downto 0);

			-- Write done signal
			W_DONE	: out std_logic;
			-- Read done signal
			R_DONE	: out std_logic
		);
	end component;

	component sim_host is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			intr		: in std_logic;
			din			: in std_logic_vector(31 downto 0);
			dout		: out std_logic_vector(31 downto 0);
			r			: in std_logic;
			w			: in std_logic;
			addr		: in std_logic_vector(10 downto 0);
			track		: in std_logic_vector(7 downto 0)
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
			stepn		: in std_logic;
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

	signal clk			: std_logic := '0';
	signal resetn		: std_logic;

	signal clken_err	: std_logic;
	signal rgb 			: std_logic_vector(8 downto 0);
	signal monomon		: std_logic := '0';
	signal mem_top		: std_logic_vector(3 downto 0) := "0000";

	signal ram_A		: std_logic_vector(23 downto 1);
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

	signal pclken		: std_logic;
	signal de			: std_logic;
	signal vsync		: std_logic;
	signal hsync		: std_logic;
	signal ikbd_rx		: std_logic := '1';

	signal fdd_clken	: std_logic;
	signal read_datan	: std_logic;
	signal side0		: std_logic;
	signal indexn		: std_logic;
	signal drv_select	: std_logic;
	signal motor_on		: std_logic;
	signal direction	: std_logic;
	signal stepn		: std_logic;
	signal write_data	: std_logic;
	signal write_gate	: std_logic;
	signal track0n		: std_logic;
	signal write_protn	: std_logic;

	signal host_intr	: std_logic;
	signal host_din		: std_logic_vector(31 downto 0);
	signal host_dout	: std_logic_vector(31 downto 0);
	signal host_r		: std_logic;
	signal host_w		: std_logic;
	signal host_addr	: std_logic_vector(10 downto 0);
	signal host_track	: std_logic_vector(7 downto 0);

begin
	atarist:atarist_main port map(
		clk => clk,
		resetn => resetn,
		clken_error => clken_err,
		monomon => monomon,
		mem_top => mem_top,
		pclken => pclken,
		de => de,
		hsync => hsync,
		vsync => vsync,
		rgb => rgb,
		ikbd_rx => ikbd_rx,

		fdd_clken => fdd_clken,
		fdd_read_datan => read_datan,
		fdd_side0 => side0,
		fdd_indexn => indexn,
		fdd_drv_select => drv_select,
		fdd_motor_on => motor_on,
		fdd_direction => direction,
		fdd_stepn => stepn,
		fdd_write_data => write_data,
		fdd_write_gate => write_gate,
		fdd_track0n => track0n,
		fdd_write_protn => write_protn,

		a => ram_A,
		ds => ram_DS,
		r => ram_R,
		r_done => ram_R_DONE,
		w => ram_W,
		w_done => ram_W_DONE,
		od => ram_oD,
		id => ram_iD
	);

	ram:simple_ram port map(
		clk => clk,
		resetn => resetn,
		A => ram_A,
		iD => ram_iD,
		oD => ram_oD,
		W => ram_W,
		R => ram_R,
		DS => ram_DS,
		W_DONE => ram_W_DONE,
		R_DONE => ram_R_DONE
	);

	floppy:floppy_drive port map (
		clk => clk,
		clken => fdd_clken,
		resetn => resetn,

		read_datan => read_datan,
		side0 => side0,
		indexn => indexn,
		drv_select => drv_select,
		motor_on => motor_on,
		direction => direction,
		stepn => stepn,
		write_data => write_data,
		write_gate => write_gate,
		track0n => track0n,
		write_protn => write_protn,

		host_intr => host_intr,
		host_din => host_din,
		host_dout => host_dout,
		host_r => host_r,
		host_w => host_w,
		host_addr => host_addr,
		host_track => host_track
	);
	side0 <= '1';
	drv_select <= '1';

	host:sim_host port map (
		clk => clk,
		clken => fdd_clken,
		resetn => resetn,

		intr => host_intr,
		din => host_din,
		dout => host_dout,
		r => host_r,
		w => host_w,
		addr => host_addr,
		track => host_track
	);

	clk <= not clk after 5 ns;		-- 100 MHz
	resetn <= '0', '1' after 442 ns;

	-- -- send byte $35 - [/] key
	-- ikbd_rx <= '1',
	-- 	'0' after 1000 us,
	-- 	'1' after 1128 us,
	-- 	'0' after 1256 us,
	-- 	'1' after 1384 us,
	-- 	'0' after 1512 us,
	-- 	'1' after 1640 us,
	-- 	'0' after 1896 us,
	-- 	'1' after 2152 us;

end dut;
