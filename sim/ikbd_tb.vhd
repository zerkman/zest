-- ikbd_tb.vhd - Testbench for IKBD
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

entity ikbd_tb is
end ikbd_tb;


architecture dut of ikbd_tb is

	signal clk			: std_logic := '0';
	signal reset		: std_logic;
	signal rx			: std_logic := '1';
	signal tx			: std_logic;
	signal j0			: std_logic_vector(4 downto 0) := (others => '1');
	signal j1			: std_logic_vector(4 downto 0) := (others => '1');
	signal k			: std_logic_vector(94 downto 0) := (others => '1');


	component atari_ikbd is
		port (
			clk		: in std_logic;
			reset	: in std_logic;
			rx		: in std_logic;
			tx		: out std_logic;
			j0		: in std_logic_vector(4 downto 0);
			j1		: in std_logic_vector(4 downto 0);
			k		: in std_logic_vector(94 downto 0)
		);
	end component;

begin

	ikbd:atari_ikbd port map (
		clk => clk,
		reset => reset,
		rx => rx,
		tx => tx,
		j0 => j0,
		j1 => j1,
		k => k
	);

	clk <= not clk after 125 ns;		-- 4 MHz
	reset <= '1', '0' after 2442 ns;
	rx <= '1', '0' after 30 us, '1' after 500 us;
	k(2) <= '1', '0' after 8 us, '1' after 820 us;

end dut;
