-- shifter.vhd - Implementation of the Atari ST Shifter chip
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

entity shifter is
	port (
		clk		: in std_logic;
		resetn	: in std_logic;
		en8ck	: in std_logic;
		en16ck	: in std_logic;
		en32ck	: in std_logic;

		CSn		: in std_logic;
		RWn		: in std_logic;
		A		: in std_logic_vector(5 downto 1);
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0);
		DE		: in std_logic;
		LOAD	: in std_logic;

		mono	: out std_logic;
		rgb		: out std_logic_vector(8 downto 0)
	);
end shifter;

architecture behavioral of shifter is

	type palette_t is array(0 to 15) of std_logic_vector(8 downto 0);
	signal palette	: palette_t;

	signal monopal	: std_logic;
	signal address	: integer;
	-- resolution
	signal res		: std_logic_vector(1 downto 0) := "00";
	signal res_ff	: std_logic_vector(1 downto 0) := "00";
	signal res_w	: std_logic;
	-- pixel registers
	type pxregs_t is array (0 to 3) of std_logic_vector(15 downto 0);
	signal rr		: pxregs_t;
	signal ir		: pxregs_t;
	signal idff		: std_logic_vector(15 downto 0);
	signal pixel	: std_logic_vector(3 downto 0);
	signal load1	: std_logic;
	signal sde		: std_logic;
	signal enpxck   : std_logic;
	signal lnbegin	: std_logic;
	signal pxctenff	: std_logic;
	signal reload	: std_logic;
	signal reload1	: std_logic;
	signal pxcnt	: unsigned(3 downto 0);
	signal loadsr	: std_logic_vector(3 downto 0);

begin
	address <= to_integer(unsigned(A));
	res_w <= '1' when CSn = '0' and RWn = '0' and A(5) = '1' else '0';
	res <= res_ff when res_w = '0' else iD(9 downto 8);

-- pixel clock enable
process(res,en8ck,en16ck,en32ck)
begin
	if res = "00" then
		enpxck <= en8ck;
	elsif res = "01" then
		enpxck <= en16ck;
	elsif res = "10" then
		enpxck <= en32ck;
	else
		enpxck <= '0';
	end if;
end process;

-- read from palette or resolution registers
process(CSn,RWn,address,palette,res)
begin
	od <= x"ffff";
	if CSn = '0' and RWn = '1' then
		if address < 16 then
			oD <= "00000"&palette(address)(8 downto 6)&'0'&palette(address)(5 downto 3)&'0'&palette(address)(2 downto 0);
		else
			oD <= "000000" & res_ff & "00000000";
		end if;
	end if;
end process;

-- write to palette or resolution registers
process(clk)
begin
	if rising_edge(clk) then
		if en8ck = '1' then
			if CSn = '0' and RWn = '0' then
				-- write
				if address < 16 then
					palette(address) <= iD(10 downto 8) & iD(6 downto 4) & iD(2 downto 0);
					if address = 0 then
						monopal <= iD(0);
					end if;
				end if;
				if res_w = '1' then
					res_ff <= res;
				end if;
			end if;
		end if;
	end if;
end process;

-- pixel value, depending on resolution
process(rr,res)
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

-- reload
process(clk,resetn)
	variable pxcten		: std_logic;
	variable vloadsr	: std_logic_vector(3 downto 0);
begin
	if resetn = '0' then
		lnbegin <= '0';
		pxctenff <= '0';
		load1 <= '1';
		reload <= '0';
		reload1 <= '0';
	elsif rising_edge(clk) then
		if enpxck = '1' then
			reload1 <= reload;
			load1 <= LOAD;
			if DE = '0' then
				lnbegin <= '0';
			elsif LOAD = '1' and load1 = '0' then
				lnbegin <= '1';
			end if;

			pxcten := pxctenff;
			if reload1 = '1' and reload = '0' then
				pxcten := lnbegin;
			end if;
			if lnbegin = '1' then
				pxcten := '1';
			end if;
			pxctenff <= pxcten;

			if pxcten = '1' then
				pxcnt <= pxcnt + 1;
			else
				pxcnt <= x"4";
			end if;

			vloadsr := loadsr;
			if reload = '1' then
				vloadsr := "0000";
			elsif load1 = '0' and LOAD = '1' then
				vloadsr := loadsr(2 downto 0) & '1';
			end if;
			loadsr <= vloadsr;

			if pxcnt = 15 and vloadsr(3) = '1' then
				reload <= '1';
			else
				reload <= '0';
			end if;
		end if;
	end if;
end process;

-- data bus latch
process(clk)
begin
	if rising_edge(clk) then
		if en8ck = '1' then
			if LOAD = '0' then
				idff <= iD;
			end if;
		end if;
	end if;
end process;

-- output RGB pixels
process(clk)
	variable vir : pxregs_t;
begin
	if rising_edge(clk) then
		if enpxck = '1' then
			if res(1) = '1' then
				mono <= pixel(0) xor monopal;
				rgb <= (others => '0');
			else
				mono <= '0';
				rgb <= palette(to_integer(unsigned(pixel)));
			end if;

			vir := ir;
			if LOAD = '1' and load1 = '0' then
				vir(3) := idff;
				vir(2) := ir(3);
				vir(1) := ir(2);
				vir(0) := ir(1);
				ir <= vir;
			end if;

			if reload = '1' then
				rr <= vir;
			elsif res = "00" then
				-- low resolution
				rr(0) <= rr(0)(14 downto 0) & '0';
				rr(1) <= rr(1)(14 downto 0) & '0';
				rr(2) <= rr(2)(14 downto 0) & '0';
				rr(3) <= rr(3)(14 downto 0) & '0';
			elsif res = "01" then
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
