-- scan_dbl.vhd - Video scanline doubler
--
-- Copyright (c) 2020-2025 Francois Galea <fgalea at free.fr>
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

entity scan_dbl is
	generic (
		-- 288p50
		CLKFREQ : integer := 32000000;
		HSWIDTH : integer := 22;
		HBORDER : integer := 96;
		HCOLUMNS : integer := 832
	);
	port (
		clk : in std_logic;
		resetn : in std_logic;
		passthru : in std_logic;
		IN_DATA : in std_logic_vector(23 downto 0);
		IN_VSYNC : in std_logic;
		IN_HSYNC : in std_logic;
		IN_DE : in std_logic;
		OUT_DATA : out std_logic_vector(23 downto 0);
		OUT_VSYNC : out std_logic;
		OUT_HSYNC : out std_logic;
		OUT_DE : out std_logic
	);
end scan_dbl;

architecture behavioral of scan_dbl is

	type line_t is array (0 to HCOLUMNS-1) of std_logic_vector(23 downto 0);
	signal linebuf0	: line_t;			-- pixel buffer
	signal linebuf1	: line_t;			-- pixel buffer
	signal lineid	: std_logic;		-- id of line in buffer to write to
	signal ixcnt	: unsigned(11 downto 0);	-- cycles counter since latest hsync
	signal oxcnt	: unsigned(11 downto 0);	-- cycles counter since latest hsync
	signal xres		: unsigned(11 downto 0);	-- number of cycles between two latest hsync
	signal ipixcnt	: unsigned(11 downto 0);	-- index for input pixel buffer
	signal opixcnt	: unsigned(11 downto 0);	-- index for output pixel buffer
	signal idraw	: std_logic;		-- current read line has pixels
	signal odraw	: std_logic;		-- current write line has pixels
	signal ivsync	: std_logic;
	signal ihsync	: std_logic;
	signal ovsync	: std_logic;
	signal ode		: std_logic;
	signal odata	: std_logic_vector(23 downto 0);

begin

	OUT_VSYNC <= ovsync;
	OUT_DE <= ode;
	OUT_DATA <= odata;

	process(clk,resetn)
	begin
		if resetn = '0' then
			lineid <= '0';
			ixcnt <= (others => '0');
			oxcnt <= (others => '0');
			xres <= (others => '0');
			ipixcnt <= (others => '0');
			opixcnt <= (others => '0');
			idraw <= '0';
			ivsync <= '0';
			ihsync <= '0';
			ovsync <= '0';
			ode <= '0';
		elsif rising_edge(clk) then
			if passthru = '1' then
				odata <= IN_DATA;
				ovsync <= IN_VSYNC;
				OUT_HSYNC <= IN_HSYNC;
				ode <= IN_DE;
			else
				ihsync <= IN_HSYNC;
				if IN_HSYNC = '1' and ihsync = '0' then
					-- new input line
					ixcnt <= (others => '0');
					xres <= ixcnt + 1;
					idraw <= '0';
					odraw <= idraw;
					ipixcnt <= (others => '0');
					lineid <= not lineid;
					ivsync <= IN_VSYNC;
					ovsync <= ivsync;
				else
					if IN_DE = '1' and ixcnt(0) = '0' and ipixcnt < HCOLUMNS then
						if lineid = '0' then
							linebuf0(to_integer(ipixcnt)) <= IN_DATA;
						else
							linebuf1(to_integer(ipixcnt)) <= IN_DATA;
						end if;
						ipixcnt <= ipixcnt + 1;
						idraw <= '1';
					end if;
					ixcnt <= ixcnt + 1;
				end if;
				if (IN_HSYNC = '1' and ihsync = '0') or ixcnt = xres/2-1 then
					oxcnt <= (others => '0');
					opixcnt <= (others => '0');
					OUT_HSYNC <= '1';
				else
					if odraw = '1' and oxcnt+1 >= HBORDER and oxcnt+1 < HBORDER+HCOLUMNS then
						ode <= '1';
						if lineid = '0' then
							odata <= linebuf1(to_integer(opixcnt));
						else
							odata <= linebuf0(to_integer(opixcnt));
						end if;
						opixcnt <= opixcnt + 1;
					else
						ode <= '0';
					end if;
					oxcnt <= oxcnt + 1;
					if oxcnt+1<HSWIDTH then
						OUT_HSYNC <= '1';
					else
						OUT_HSYNC <= '0';
					end if;
				end if;
			end if;
		end if;
	end process;

end behavioral;
