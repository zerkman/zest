-- tb_fdc_read_track.vhd - testbench for fdc and floppy drive
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

entity tb_fdc_read_track is
end tb_fdc_read_track;

architecture dut of tb_fdc_read_track is
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

	component wd1772 is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			CSn			: in std_logic;
			RWn			: in std_logic;
			A			: in std_logic_vector(1 downto 0);
			iDAL		: in std_logic_vector(7 downto 0);
			oDAL		: out std_logic_vector(7 downto 0);
			INTRQ		: out std_logic;
			DRQ			: out std_logic;
			DDENn		: in std_logic;
			WPRTn		: in std_logic;
			IPn			: in std_logic;
			TR0n		: in std_logic;
			WD			: out std_logic;
			WG			: out std_logic;
			MO			: out std_logic;
			RDn			: in std_logic;
			DIRC		: out std_logic;
			STEP		: out std_logic
		);
	end component;

	signal clk			: std_logic := '1';
	signal clken		: std_logic;
	signal resetn		: std_logic;

	signal CSn			: std_logic;
	signal RWn			: std_logic;
	signal A			: std_logic_vector(1 downto 0);
	signal iDAL			: std_logic_vector(7 downto 0);
	signal oDAL			: std_logic_vector(7 downto 0);
	signal INTRQ		: std_logic;
	signal DRQ			: std_logic;
	signal DDENn		: std_logic;

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

	signal data			: std_logic_vector(7 downto 0);

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

	fdc:wd1772 port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		CSn => CSn,
		RWn => RWn,
		A => A,
		iDAL => iDAL,
		oDAL => oDAL,
		INTRQ => INTRQ,
		DRQ => DRQ,
		DDENn => DDENn,
		WPRTn => write_protn,
		IPn => indexn,
		TR0n => track0n,
		WD => write_data,
		WG => write_gate,
		MO => motor_on,
		RDn => read_datan,
		DIRC => direction,
		STEP => stepn
	);
	DDENn <= '0';

	clk <= not clk after 62500 ps;	-- 8 MHz
	clken <= '1';
	resetn <= '0', '1' after 30 us;

	tb1 : process
		constant cycle: time := 125 ns;
		constant instr: time := 1 us;
	begin
		drv_select <= '0';
		RWn <= '1';
		CSn <= '1';
		iDAL <= x"00";
		A <= "00";
		wait for 50 us;

		drv_select <= '1';
		RWn <= '0';
		CSn <= '0';
		A <= "00";				-- command register
		iDAL <= "00000011";		-- restore, motor on, no verify, 3 ms stepping
		wait for 2*cycle;

		RWn <= '1';
		CSn <= '1';
		wait until INTRQ = '1';

		wait for 8*cycle;

		RWn <= '0';
		CSn <= '0';
		A <= "00";
		iDAL <= "11101100";		-- read track, no spin-up, 15 ms delay
		wait for 2*cycle;

		RWn <= '1';
		CSn <= '1';
		A <= "11";				-- data register

		readloop : for i in 0 to 6249 loop
			wait until DRQ = '1';
			CSn <= '0';
			wait for 2*cycle;
			data <= oDAL;
			CSn <= '1';
		end loop;

		wait until INTRQ = '1';

		assert false report "end of test" severity note;
		wait;
	end process;
end architecture;
