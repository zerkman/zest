-- ikbd_tb.vhd - Testbench for IKBD
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

entity ikbd_tb is
end ikbd_tb;


architecture dut of ikbd_tb is

	signal clk			: std_logic := '0';
	signal clkren		: std_logic := '0';
	signal clkfen		: std_logic := '0';
	signal reset		: std_logic;
	signal rx			: std_logic := '1';
	signal tx			: std_logic;
	signal j0			: std_logic_vector(4 downto 0) := (others => '1');
	signal j1			: std_logic_vector(4 downto 0) := (others => '1');
	signal k			: std_logic_vector(94 downto 0) := (others => '1');


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

	component clock_enabler is
		port (
			clk			: in std_logic;
			reset		: in std_logic;
			enNC1		: in std_logic;		-- enable 8 MHz rising edges
			enNC2		: in std_logic;		-- enable 8 MHz falling edges
			en8rck		: out std_logic;	-- 8 MHz rising edge
			en8fck		: out std_logic;	-- 8 MHz falling edge
			en32ck		: out std_logic;	-- 32 MHz rising edge
			en4rck		: out std_logic;	-- 4 MHz rising edge
			en4fck		: out std_logic;	-- 4 MHz falling edge
			en2rck		: out std_logic;	-- 2 MHz rising edge
			en2fck		: out std_logic;	-- 2 MHz falling edge
			en2_4576	: out std_logic;	-- 2.4576 MHz rising edge
			ck05		: out std_logic;	-- 500 kHz clock
			error		: out std_logic		-- time out error
		);
	end component;


begin

	ikbd:atari_ikbd port map (
		clk => clk,
		clkren => clkren,
		clkfen => clkfen,
		reset => reset,
		rx => rx,
		tx => tx,
		j0 => j0,
		j1 => j1,
		k => k
	);

	clken:clock_enabler port map (
		clk => clk,
		reset => reset,
		enNC1 => '1',
		enNC2 => '1',
		en2rck => clkren,
		en2fck => clkfen
	);

	clk <= not clk after 5 ns;		-- 100 MHz
	reset <= '0', '1' after 300 us, '0' after 510 us;
	rx <= '1', '0' after 600 us, '1' after 220 ms;	-- processor reset
	k(91) <= '1', '0' after 350 ms, '1' after 500 ms; 	-- [/] key, scan code 0x35

end dut;
