-- shifter.vhd - Implementation of the Atari ST Shifter chip
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

entity shifter is
	port (
		clk		: in std_logic;
		enPhi1	: in std_logic;
		enPhi2	: in std_logic;
		en32ck	: in std_logic;

		CSn		: in std_logic;
		RWn		: in std_logic;
		A		: in std_logic_vector(5 downto 1);
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0);
		DE		: in std_logic;
		LOADn	: out std_logic;

		rgb		: out std_logic_vector(8 downto 0)
	);
end shifter;

architecture behavioral of shifter is

	type palette_t is array(0 to 15) of std_logic_vector(8 downto 0);
	signal palette	: palette_t := (
		"000010010",	-- 022
		"011010010",	-- 322
		"100011011",	-- 433
		"011011010",	-- 332
		"101100100",	-- 544
		"100100011",	-- 443
		"101101100",	-- 554
		"110101101",	-- 655
		"110110101",	-- 665
		"010010000",	-- 220
		"111110110",	-- 766
		"111111111",	-- 777
		"111111110",	-- 776
		"010000000",	-- 200
		"000000000",	-- 000
		"000000000"		-- 000
	);

	signal monopal	: std_logic;
	signal address	: integer;
	-- 32 MHz quarter/half/full pixel counter, depending on resolution (0,1 or 2)
	signal cnt32	: unsigned(5 downto 0) := "000000";
	-- resolution
	signal res		: std_logic_vector(1 downto 0) := "00";
	signal sh0		: std_logic_vector(15 downto 0);
	signal sh1		: std_logic_vector(15 downto 0);
	signal sh2		: std_logic_vector(15 downto 0);
	signal sh3		: std_logic_vector(15 downto 0);
	signal nsh0		: std_logic_vector(15 downto 0);
	signal nsh1		: std_logic_vector(15 downto 0);
	signal nsh2		: std_logic_vector(15 downto 0);
	signal nsh3		: std_logic_vector(15 downto 0);
	signal pixel	: std_logic_vector(3 downto 0);
	signal sloadn	: std_logic;
	signal sde		: std_logic;

begin
	LOADn <= sloadn;
	address <= to_integer(unsigned(A));

-- read/write in palette or resolution registers
process(clk)
begin
	if rising_edge(clk) then
		if enPhi1 = '1' then
			oD <= x"ffff";
			if CSn = '0' then
				if RWn = '1' then
					-- read
					if address < 16 then
						oD <= "00000"&palette(address)(8 downto 6)&'0'&palette(address)(5 downto 3)&'0'&palette(address)(2 downto 0);
					else
						oD <= "000000" & res & "00000000";
					end if;
				else
					-- write
					if address < 16 then
						palette(address) <= iD(10 downto 8) & iD(6 downto 4) & iD(2 downto 0);
						if address = 0 then
							monopal <= iD(0);
						end if;
					else
						res <= iD(9 downto 8);
					end if;
				end if;
			end if;
		end if;
	end if;
end process;

-- load next shift registers
process(clk)
begin
	if rising_edge(clk) then
		if enPhi2 = '1' then
			sloadn <= '1';
			if DE = '1' and cnt32(3 downto 2) = "10" then
				sloadn <= '0';
			elsif cnt32(3 downto 2) = "11" then
				if sloadn = '0' then
					nsh3 <= iD;
				else
					nsh3 <= x"0000";
				end if;
				nsh2 <= nsh3;
				nsh1 <= nsh2;
				nsh0 <= nsh1;
			end if;
		end if;
	end if;
end process;

-- pixel value, depending on resolution
process(sh3,sh2,sh1,sh0,res)
begin
	case res is
	when "00" =>
		pixel <= sh3(15) & sh2(15) & sh1(15) & sh0(15);
	when "01" =>
		pixel <= "00" & sh1(15) & sh0(15);
	when "10" =>
		pixel <= "000" & sh0(15);
	when others =>
		pixel <= "0000";
	end case;
end process;

-- pixel counter
process(clk)
begin
	if rising_edge(clk) then
		if en32ck = '1' then
			sde <= DE;
			if DE = '1' and sde = '0' then
				-- sync counter to MMU and 8 MHz clock
				cnt32 <= "111110";
			else
				cnt32 <= cnt32 + 1;
			end if;
		end if;
	end if;
end process;

-- output RGB pixels
process(clk)
begin
	if rising_edge(clk) then
		if en32ck = '1' then
			if res(1) = '1' then
				rgb <= (8 downto 0 => pixel(0) xor monopal);
			else
				rgb <= palette(to_integer(unsigned(pixel)));
			end if;
			if cnt32 = "111111" then
				sh0 <= nsh0;
				sh1 <= nsh1;
				sh2 <= nsh2;
				sh3 <= nsh3;
			elsif res = "00" and cnt32(1 downto 0) = "11" then
				-- low resolution
				sh0 <= sh0(14 downto 0) & '0';
				sh1 <= sh1(14 downto 0) & '0';
				sh2 <= sh2(14 downto 0) & '0';
				sh3 <= sh3(14 downto 0) & '0';
			elsif res = "01" and cnt32(0) = '1' then
				-- medium resolution
				sh0 <= sh0(14 downto 0) & sh2(15);
				sh1 <= sh1(14 downto 0) & sh3(15);
				sh2 <= sh2(14 downto 0) & '0';
				sh3 <= sh3(14 downto 0) & '0';
			elsif res = "10" then
				-- high resolution
				sh0 <= sh0(14 downto 0) & sh1(15);
				sh1 <= sh1(14 downto 0) & sh2(15);
				sh2 <= sh2(14 downto 0) & sh3(15);
				sh3 <= sh3(14 downto 0) & '0';
			end if;
		end if;
	end if;
end process;


end behavioral;
