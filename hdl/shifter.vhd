-- shifter.vhd - Implementation of the Atari ST Shifter chip
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

entity shifter is
	port (
		clk		: in std_logic;
		resetn	: in std_logic;
		en8ck	: in std_logic;
		en32ck	: in std_logic;

		CSn		: in std_logic;
		RWn		: in std_logic;
		A		: in std_logic_vector(5 downto 1);
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0);
		DE		: in std_logic;
		LOADn	: in std_logic;

		rgb		: out std_logic_vector(8 downto 0)
	);
end shifter;

architecture behavioral of shifter is

	type palette_t is array(0 to 15) of std_logic_vector(8 downto 0);
	signal palette	: palette_t;

	signal monopal	: std_logic;
	signal address	: integer;
	-- 32 MHz quarter/half/full pixel counter, depending on resolution (0,1 or 2)
	signal cnt32	: unsigned(5 downto 0);
	-- resolution
	signal res		: std_logic_vector(1 downto 0) := "00";
	-- pixel registers
	type pxregs_t is array (0 to 3) of std_logic_vector(15 downto 0);
	signal rr		: pxregs_t;
	signal ir		: pxregs_t;
	signal pixel	: std_logic_vector(3 downto 0);
	signal sloadn	: std_logic;
	signal sde		: std_logic;
	signal lnbegin	: std_logic;

begin
	address <= to_integer(unsigned(A));

-- read/write in palette or resolution registers
process(clk)
begin
	if rising_edge(clk) then
		if en8ck = '1' then
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
		if en8ck = '1' and cnt32(3 downto 2) = "00" then
			if LOADn = '0' then
				ir(3) <= iD;
			else
				ir(3) <= x"0000";
			end if;
			ir(2) <= ir(3);
			ir(1) <= ir(2);
			ir(0) <= ir(1);
		end if;
	end if;
end process;

-- pixel value, depending on resolution
process(rr(3),rr(2),rr(1),rr(0),res)
begin
	case res is
	when "00" =>
		pixel <= rr(3)(15) & rr(2)(15) & rr(1)(15) & rr(0)(15);
	when "01" =>
		pixel <= "00" & rr(1)(15) & rr(0)(15);
	when "10" =>
		pixel <= "000" & rr(0)(15);
	when others =>
		pixel <= "0000";
	end case;
end process;

-- pixel counter
process(clk,resetn)
begin
	if resetn = '0' then
		cnt32 <= "000000";
		lnbegin <= '0';
		sloadn <= '0';
		sde <= '0';
	elsif rising_edge(clk) then
		if en32ck = '1' then
			cnt32 <= cnt32 + 1;
			sloadn <= LOADn;
			sde <= DE;
			if DE = '1' and sde = '0' then
				lnbegin <= '1';
			end if;
			if lnbegin = '1' and LOADn = '0' and sloadn = '1' then
				-- sync with 8 mhz clock and LOADn sequence
				cnt32 <= "000001";
				lnbegin <= '0';
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
				rr(0) <= ir(0);
				rr(1) <= ir(1);
				rr(2) <= ir(2);
				rr(3) <= ir(3);
			elsif res = "00" and cnt32(1 downto 0) = "11" then
				-- low resolution
				rr(0) <= rr(0)(14 downto 0) & '0';
				rr(1) <= rr(1)(14 downto 0) & '0';
				rr(2) <= rr(2)(14 downto 0) & '0';
				rr(3) <= rr(3)(14 downto 0) & '0';
			elsif res = "01" and cnt32(0) = '1' then
				-- medium resolution
				rr(0) <= rr(0)(14 downto 0) & rr(2)(15);
				rr(1) <= rr(1)(14 downto 0) & rr(3)(15);
				rr(2) <= rr(2)(14 downto 0) & '0';
				rr(3) <= rr(3)(14 downto 0) & '0';
			elsif res = "10" then
				-- high resolution
				rr(0) <= rr(0)(14 downto 0) & rr(1)(15);
				rr(1) <= rr(1)(14 downto 0) & rr(2)(15);
				rr(2) <= rr(2)(14 downto 0) & rr(3)(15);
				rr(3) <= rr(3)(14 downto 0) & '0';
			end if;
		end if;
	end if;
end process;


end behavioral;
