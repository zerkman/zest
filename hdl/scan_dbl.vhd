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

library work;
use work.all;

entity scan_dbl is
	port (
		clk : in std_logic;
		resetn : in std_logic;
		mode : in std_logic;
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

	constant CLKFREQ : integer := 32000000;
	constant HSWIDTH : integer := 22;
	constant HBORDER : integer := 96;
	constant HCOLUMNS : integer := 832;

	signal lineid	: std_logic;		-- id of line in buffer to write to
	signal oycnt	: std_logic;		-- output line counter
	signal ixcnt	: integer range 0 to 2047;	-- cycles counter since latest hsync
	signal oxcnt	: integer range 0 to 2047;	-- cycles counter since latest hsync
	signal xres		: integer range 0 to 4095;	-- number of cycles between two latest hsync
	signal ipixcnt	: integer range 0 to 1023;	-- index for input pixel buffer
	signal opixcnt	: integer range 0 to 1023;	-- index for output pixel buffer
	signal idraw	: std_logic;		-- current read line has pixels
	signal odraw	: std_logic;		-- current write line has pixels
	signal ivsync	: std_logic;
	signal ihsync	: std_logic;
	signal ovsync	: std_logic;
	signal ode		: std_logic;
	signal odata	: std_logic_vector(23 downto 0);

	signal w_addr	: std_logic_vector(9 downto 0);
	signal r_addr	: std_logic_vector(9 downto 0);
	signal r_data0	: std_logic_vector(23 downto 0);
	signal r_data1	: std_logic_vector(23 downto 0);
	signal we0		: std_logic;
	signal we1		: std_logic;

begin

	OUT_VSYNC <= ovsync;
	OUT_DE <= ode;
	OUT_DATA <= odata;

	w_addr <= std_logic_vector(to_unsigned(ipixcnt,10));
	r_addr <= std_logic_vector(to_unsigned(opixcnt+1,10));

	ram0: entity ram_tdp generic map (
			DATA_WIDTH => 24,
			ADDR_WIDTH => 10
		)
		port map (
			clk1 => clk,
			clk2 => clk,
			addr1 => w_addr,
			addr2 => r_addr,
			din1 => IN_DATA,
			din2 => (others => '0'),
			wsb1 => "111",
			wsb2 => "000",
			dout1 => open,
			dout2 => r_data0,
			we1 => we0,
			we2 => '0',
			re1 => '0',
			re2 => '1'
		);

	ram1: entity ram_tdp generic map (
			DATA_WIDTH => 24,
			ADDR_WIDTH => 10
		)
		port map (
			clk1 => clk,
			clk2 => clk,
			addr1 => w_addr,
			addr2 => r_addr,
			din1 => IN_DATA,
			din2 => (others => '0'),
			wsb1 => "111",
			wsb2 => "000",
			dout1 => open,
			dout2 => r_data1,
			we1 => we1,
			we2 => '0',
			re1 => '0',
			re2 => '1'
		);

	process(clk,resetn)
		variable p0 : std_logic_vector(23 downto 0);
		variable p1 : std_logic_vector(23 downto 0);
		variable r0 : integer range 0 to 255;
		variable g0 : integer range 0 to 255;
		variable b0 : integer range 0 to 255;
		variable r1 : integer range 0 to 255;
		variable g1 : integer range 0 to 255;
		variable b1 : integer range 0 to 255;
	begin
		if resetn = '0' then
			lineid <= '0';
			ixcnt <= 0;
			oxcnt <= 0;
			xres <= 0;
			ipixcnt <= 0;
			opixcnt <= 0;
			idraw <= '0';
			ivsync <= '0';
			ihsync <= '0';
			ovsync <= '0';
			ode <= '0';
			oycnt <= '0';
			we0 <= '0';
			we1 <= '0';
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
					ixcnt <= 0;
					xres <= ixcnt + 1;
					idraw <= '0';
					odraw <= idraw;
					ipixcnt <= 0;
					lineid <= not lineid;
					ivsync <= IN_VSYNC;
					ovsync <= ivsync;
				else
					if IN_DE = '1' and ixcnt mod 2 = 0 and ipixcnt < HCOLUMNS then
						we0 <= not lineid;
						we1 <= lineid;
						ipixcnt <= ipixcnt + 1;
						idraw <= '1';
					else
						we0 <= '0';
						we1 <= '0';
					end if;
					ixcnt <= ixcnt + 1;
				end if;
				if (IN_HSYNC = '1' and ihsync = '0') or ixcnt = xres/2-1 then
					oxcnt <= 0;
					opixcnt <= 0;
					oycnt <= not oycnt;
					OUT_HSYNC <= '1';
				else
					if odraw = '1' and oxcnt+1 >= HBORDER and oxcnt+1 < HBORDER+HCOLUMNS then
						ode <= '1';
						if oycnt = '0' or mode = '0' then
							if lineid = '0' then
								odata <= r_data1;
							else
								odata <= r_data0;
							end if;
						else
							p0 := r_data0;
							p1 := r_data1;
							r0 := to_integer(unsigned(p0(23 downto 16)));
							g0 := to_integer(unsigned(p0(15 downto 8)));
							b0 := to_integer(unsigned(p0(7 downto 0)));
							r1 := to_integer(unsigned(p1(23 downto 16)));
							g1 := to_integer(unsigned(p1(15 downto 8)));
							b1 := to_integer(unsigned(p1(7 downto 0)));
							odata <= std_logic_vector(to_unsigned((r0+r1)*3/8,8)) & std_logic_vector(to_unsigned((g0+g1)*3/8,8)) & std_logic_vector(to_unsigned((b0+b1)*3/8,8));
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
