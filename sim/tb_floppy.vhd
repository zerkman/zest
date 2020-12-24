-- tb_floppy.vhd - testbench for floppy drive
--
-- Copyright (c) 2020 Francois Galea <fgalea at free.fr>
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

entity tb_floppy is
end tb_floppy;

architecture dut of tb_floppy is
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
			side		: in std_logic;
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

	signal clk			: std_logic := '1';
	signal clken		: std_logic;
	signal resetn		: std_logic;

	signal read_datan	: std_logic;
	signal side			: std_logic;
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
	host:sim_host port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		intr => host_intr,
		din => host_din,
		dout => host_dout,
		r => host_r,
		w => host_w,
		addr => host_addr,
		track => host_track
	);

	floppy:floppy_drive port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		read_datan => read_datan,
		side => side,
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
	side <= '0';

	clk <= not clk after 62500 ps;	-- 8 MHz
	clken <= '1';

	tb1 : process
		constant cycle: time := 125 ns;
		constant instr: time := 1 us;
	begin
		drv_select <= '0';
		direction <= '0';
		stepn <= '1';
		write_data <= '0';
		write_gate <= '0';
		resetn <= '0';
		motor_on <= '0';
		wait for 30 us;

		resetn <= '1';
		wait for 20 us;

		motor_on <= '1';
		drv_select <= '1';

		assert track0n = '0'
		report "test failed for track 0" severity error;

		for i in 0 to 5 loop
			wait until indexn = '1';
			wait until indexn = '0';
		end loop;

		assert false report "end of test" severity note;
		wait;
	end process;
end architecture;
