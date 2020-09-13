-- ikbd.vhd - Implementation of the Atari ST IKBD
--
-- Copyright (colsel) 2020 Francois Galea <fgalea at free.fr>
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
		k		: in std_logic_vector(94 downto 0)
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

	-- matrix(0) <= row(4) nor k(47);
	-- matrix(1) <= (row(0) nor k(0)) and (row(5) nor k(59));
	-- matrix(2) <= (row(0) nor k(1)) and (row(6) nor k(71));
	-- matrix(3) <= (row(0) nor k(2)) and (row(7) nor k(83));
	-- matrix(4) <= (row(0) nor k(3)) and (row(1) nor k(14)) and (row(2) nor k(25)) and (row(3) nor k(36)) and (row(4) nor k(48)) and (row(5) nor k(60)) and (row(6) nor k(72)) and (row(7) nor k(84));
	-- matrix(5) <= (row(0) nor k(4)) and (row(1) nor k(15)) and (row(2) nor k(26)) and (row(3) nor k(37)) and (row(4) nor k(49)) and (row(5) nor k(61)) and (row(6) nor k(73)) and (row(7) nor k(85));
	-- matrix(6) <= (row(0) nor k(5)) and (row(1) nor k(16)) and (row(2) nor k(27)) and (row(3) nor k(38)) and (row(4) nor k(50)) and (row(5) nor k(62)) and (row(6) nor k(74)) and (row(7) nor k(86));
	-- matrix(7) <= (row(0) nor k(6)) and (row(1) nor k(17)) and (row(2) nor k(28)) and (row(3) nor k(39)) and (row(4) nor k(51)) and (row(5) nor k(63)) and (row(6) nor k(75)) and (row(7) nor k(87));
	-- matrix(8) <= (row(0) nor k(7)) and (row(1) nor k(18)) and (row(2) nor k(29)) and (row(3) nor k(40)) and (row(4) nor k(52)) and (row(5) nor k(64)) and (row(6) nor k(76)) and (row(7) nor k(88));
	-- matrix(9) <= (row(0) nor k(8)) and (row(1) nor k(19)) and (row(2) nor k(30)) and (row(3) nor k(41)) and (row(4) nor k(53)) and (row(5) nor k(65)) and (row(6) nor k(77)) and (row(7) nor k(89));
	-- matrix(10) <= (row(0) nor k(9)) and (row(1) nor k(20)) and (row(2) nor k(31)) and (row(3) nor k(42)) and (row(4) nor k(54)) and (row(5) nor k(66)) and (row(6) nor k(78)) and (row(7) nor k(90));
	-- matrix(11) <= (row(0) nor k(10)) and (row(1) nor k(21)) and (row(2) nor k(32)) and (row(3) nor k(43)) and (row(4) nor k(55)) and (row(5) nor k(67)) and (row(6) nor k(79)) and (row(7) nor k(91));
	-- matrix(12) <= (row(0) nor k(11)) and (row(1) nor k(22)) and (row(2) nor k(33)) and (row(3) nor k(44)) and (row(4) nor k(56)) and (row(5) nor k(68)) and (row(6) nor k(80)) and (row(7) nor k(92));
	-- matrix(13) <= (row(0) nor k(12)) and (row(1) nor k(23)) and (row(2) nor k(34)) and (row(3) nor k(45)) and (row(4) nor k(57)) and (row(5) nor k(69)) and (row(6) nor k(81)) and (row(7) nor k(93));
	-- matrix(14) <= (row(0) nor k(13)) and (row(1) nor k(24)) and (row(2) nor k(35)) and (row(3) nor k(46)) and (row(4) nor k(58)) and (row(5) nor k(70)) and (row(6) nor k(82)) and (row(7) nor k(94));

	row(0) <= (colsel(1) nor k(0))
		and (colsel(2) nor k(1))
		and (colsel(3) nor k(2))
		and (colsel(4) nor k(3))
		and (colsel(5) nor k(4))
		and (colsel(6) nor k(5))
		and (colsel(7) nor k(6))
		and (colsel(8) nor k(7))
		and (colsel(9) nor k(8))
		and (colsel(10) nor k(9))
		and (colsel(11) nor k(10))
		and (colsel(12) nor k(11))
		and (colsel(13) nor k(12))
		and (colsel(14) nor k(13));
	row(1) <= (colsel(4) nor k(14))
		and (colsel(5) nor k(15))
		and (colsel(6) nor k(16))
		and (colsel(7) nor k(17))
		and (colsel(8) nor k(18))
		and (colsel(9) nor k(19))
		and (colsel(10) nor k(20))
		and (colsel(11) nor k(21))
		and (colsel(12) nor k(22))
		and (colsel(13) nor k(23))
		and (colsel(14) nor k(24));
	row(2) <= (colsel(4) nor k(25))
		and (colsel(5) nor k(26))
		and (colsel(6) nor k(27))
		and (colsel(7) nor k(28))
		and (colsel(8) nor k(29))
		and (colsel(9) nor k(30))
		and (colsel(10) nor k(31))
		and (colsel(11) nor k(32))
		and (colsel(12) nor k(33))
		and (colsel(13) nor k(34))
		and (colsel(14) nor k(35));
	row(3) <= (colsel(4) nor k(36))
		and (colsel(5) nor k(37))
		and (colsel(6) nor k(38))
		and (colsel(7) nor k(39))
		and (colsel(8) nor k(40))
		and (colsel(9) nor k(41))
		and (colsel(10) nor k(42))
		and (colsel(11) nor k(43))
		and (colsel(12) nor k(44))
		and (colsel(13) nor k(45))
		and (colsel(14) nor k(46));
	row(4) <= (colsel(0) nor k(47))
		and (colsel(4) nor k(48))
		and (colsel(5) nor k(49))
		and (colsel(6) nor k(50))
		and (colsel(7) nor k(51))
		and (colsel(8) nor k(52))
		and (colsel(9) nor k(53))
		and (colsel(10) nor k(54))
		and (colsel(11) nor k(55))
		and (colsel(12) nor k(56))
		and (colsel(13) nor k(57))
		and (colsel(14) nor k(58));
	row(5) <= (colsel(1) nor k(59))
		and (colsel(4) nor k(60))
		and (colsel(5) nor k(61))
		and (colsel(6) nor k(62))
		and (colsel(7) nor k(63))
		and (colsel(8) nor k(64))
		and (colsel(9) nor k(65))
		and (colsel(10) nor k(66))
		and (colsel(11) nor k(67))
		and (colsel(12) nor k(68))
		and (colsel(13) nor k(69))
		and (colsel(14) nor k(70));
	row(6) <= (colsel(2) nor k(71))
		and (colsel(4) nor k(72))
		and (colsel(5) nor k(73))
		and (colsel(6) nor k(74))
		and (colsel(7) nor k(75))
		and (colsel(8) nor k(76))
		and (colsel(9) nor k(77))
		and (colsel(10) nor k(78))
		and (colsel(11) nor k(79))
		and (colsel(12) nor k(80))
		and (colsel(13) nor k(81))
		and (colsel(14) nor k(82));
	row(7) <= (colsel(3) nor k(83))
		and (colsel(4) nor k(84))
		and (colsel(5) nor k(85))
		and (colsel(6) nor k(86))
		and (colsel(7) nor k(87))
		and (colsel(8) nor k(88))
		and (colsel(9) nor k(89))
		and (colsel(10) nor k(90))
		and (colsel(11) nor k(91))
		and (colsel(12) nor k(92))
		and (colsel(13) nor k(93))
		and (colsel(14) nor k(94));

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
