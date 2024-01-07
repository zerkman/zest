-- ikbd.vhd - Implementation of the Atari ST IKBD
--
-- Copyright (c) 2020-2024 Francois Galea <fgalea at free.fr>
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

entity atari_ikbd is
	port (
		clk		: in std_logic;
		clkren	: in std_logic;
		clkfen	: in std_logic;
		reset	: in std_logic;
		rx		: in std_logic;
		tx		: out std_logic;
		j0		: in std_logic_vector(4 downto 0);
		j1		: in std_logic_vector(4 downto 0);
		k		: in std_logic_vector(95 downto 0)
	);
end atari_ikbd;

architecture behavioral of atari_ikbd is

	component HD63701V0_M6 is
		port (
			CLKx2	: in std_logic;
			clkren	: in std_logic;
			clkfen	: in std_logic;
			RST		: in std_logic;
			NMI		: in std_logic;
			IRQ		: in std_logic;

			RW		: out std_logic;
			AD		: out std_logic_vector(15 downto 0);
			DO		: out std_logic_vector(7 downto 0);
			DI		: in std_logic_vector(7 downto 0);
			PI4		: in std_logic_vector(7 downto 0);
			PI1		: in std_logic_vector(7 downto 0);
			PO1		: out std_logic_vector(7 downto 0);
			PI2		: in std_logic_vector(4 downto 0);
			PO2		: out std_logic_vector(7 downto 0)
		);
	end component;

	signal row : std_logic_vector(7 downto 0);
	signal colsel : std_logic_vector(14 downto 0);
	signal ad : std_logic_vector(15 downto 0);
	signal i2 : std_logic_vector(4 downto 0);
	signal o2 : std_logic_vector(7 downto 0);
	signal js : std_logic_vector(7 downto 0);
	signal jssel : std_logic;

	signal i3 : std_logic_vector(7 downto 0);
	signal i4 : std_logic_vector(7 downto 0);

begin

	row(0) <= (colsel(0) or k(95))
		and (colsel(1) or k(0))
		and (colsel(2) or k(1))
		and (colsel(3) or k(2))
		and (colsel(4) or k(3))
		and (colsel(5) or k(4))
		and (colsel(6) or k(5))
		and (colsel(7) or k(6))
		and (colsel(8) or k(7))
		and (colsel(9) or k(8))
		and (colsel(10) or k(9))
		and (colsel(11) or k(10))
		and (colsel(12) or k(11))
		and (colsel(13) or k(12))
		and (colsel(14) or k(13));
	row(1) <= (colsel(4) or k(14))
		and (colsel(5) or k(15))
		and (colsel(6) or k(16))
		and (colsel(7) or k(17))
		and (colsel(8) or k(18))
		and (colsel(9) or k(19))
		and (colsel(10) or k(20))
		and (colsel(11) or k(21))
		and (colsel(12) or k(22))
		and (colsel(13) or k(23))
		and (colsel(14) or k(24));
	row(2) <= (colsel(4) or k(25))
		and (colsel(5) or k(26))
		and (colsel(6) or k(27))
		and (colsel(7) or k(28))
		and (colsel(8) or k(29))
		and (colsel(9) or k(30))
		and (colsel(10) or k(31))
		and (colsel(11) or k(32))
		and (colsel(12) or k(33))
		and (colsel(13) or k(34))
		and (colsel(14) or k(35));
	row(3) <= (colsel(4) or k(36))
		and (colsel(5) or k(37))
		and (colsel(6) or k(38))
		and (colsel(7) or k(39))
		and (colsel(8) or k(40))
		and (colsel(9) or k(41))
		and (colsel(10) or k(42))
		and (colsel(11) or k(43))
		and (colsel(12) or k(44))
		and (colsel(13) or k(45))
		and (colsel(14) or k(46));
	row(4) <= (colsel(0) or k(47))
		and (colsel(4) or k(48))
		and (colsel(5) or k(49))
		and (colsel(6) or k(50))
		and (colsel(7) or k(51))
		and (colsel(8) or k(52))
		and (colsel(9) or k(53))
		and (colsel(10) or k(54))
		and (colsel(11) or k(55))
		and (colsel(12) or k(56))
		and (colsel(13) or k(57))
		and (colsel(14) or k(58));
	row(5) <= (colsel(1) or k(59))
		and (colsel(4) or k(60))
		and (colsel(5) or k(61))
		and (colsel(6) or k(62))
		and (colsel(7) or k(63))
		and (colsel(8) or k(64))
		and (colsel(9) or k(65))
		and (colsel(10) or k(66))
		and (colsel(11) or k(67))
		and (colsel(12) or k(68))
		and (colsel(13) or k(69))
		and (colsel(14) or k(70));
	row(6) <= (colsel(2) or k(71))
		and (colsel(4) or k(72))
		and (colsel(5) or k(73))
		and (colsel(6) or k(74))
		and (colsel(7) or k(75))
		and (colsel(8) or k(76))
		and (colsel(9) or k(77))
		and (colsel(10) or k(78))
		and (colsel(11) or k(79))
		and (colsel(12) or k(80))
		and (colsel(13) or k(81))
		and (colsel(14) or k(82));
	row(7) <= (colsel(3) or k(83))
		and (colsel(4) or k(84))
		and (colsel(5) or k(85))
		and (colsel(6) or k(86))
		and (colsel(7) or k(87))
		and (colsel(8) or k(88))
		and (colsel(9) or k(89))
		and (colsel(10) or k(90))
		and (colsel(11) or k(91))
		and (colsel(12) or k(92))
		and (colsel(13) or k(93))
		and (colsel(14) or k(94));

	hd6301:HD63701V0_M6 port map (
		CLKx2 => clk,
		clkren => clkren,
		clkfen => clkfen,
		RST => reset,
		NMI => '0',
		IRQ => '0',

		AD => ad,
		DI => i3,
		PI4 => i4,
		PI1 => row,
		PI2 => i2,
		PO2 => o2
	);
	colsel <= ad(15 downto 1);
	i4 <= (j1(3 downto 0) & j0(3 downto 0)) xor (7 downto 0 => jssel);
	i3 <= x"ff";
	i2 <= '1' & rx & j1(4) & j0(4) & '1';
	tx <= o2(4);
	jssel <= o2(0);

end behavioral;
