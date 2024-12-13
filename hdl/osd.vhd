-- osd.vhd - On-screen text display
--
-- Copyright (c) 2022-2024 Francois Galea <fgalea at free.fr>
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

-- This module implements a memory-mappable buffer of 1024 32bit words.
-- The address space is as follows:
-- 0x000-0x00f: configuration registers
-- 0x010-0x0ff: character colours (foreground and background)
-- 0x100-0x3ff: characters (first is the rightmost one)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity on_screen_display is
	port (
		clk				: in std_logic;
		resetn			: in std_logic;

		-- bridge bus signals
		bridge_addr		: in std_logic_vector(12 downto 2);
		bridge_r		: in std_logic;
		bridge_r_data	: out std_logic_vector(31 downto 0);
		bridge_w		: in std_logic;
		bridge_w_data	: in std_logic_vector(31 downto 0);
		bridge_w_strb	: in std_logic_vector(3 downto 0);

		-- video signals
		pclk			: in std_logic;
		idata			: in std_logic_vector(23 downto 0);
		ivsync			: in std_logic;
		ihsync			: in std_logic;
		ide				: in std_logic;
		odata			: out std_logic_vector(23 downto 0);
		ovsync			: out std_logic;
		ohsync			: out std_logic;
		ode				: out std_logic;

		intr			: out std_logic
	);
end on_screen_display;

architecture arch_imp of on_screen_display is

	type br_st_t is ( IDLE, WR, RD, RD1, RD2 );
	signal br_st		: br_st_t;

	constant DATA_WIDTH_BITS: integer := 5;		-- log2(width of data bus)
	constant ADDR_WIDTH		: integer := 13;	-- Width of address bus
	constant ADDR_LSB	: integer := DATA_WIDTH_BITS-3;
	constant ADDR_MSB	: integer := ADDR_WIDTH-1;

	-- RAM signals
	signal ram_addr1	: std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_addr2	: std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_din1		: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_din2		: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_wsb1		: std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);
	signal ram_wsb2		: std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);
	signal ram_dout1	: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_dout2	: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_we1		: std_logic;
	signal ram_we2		: std_logic;
	signal ram_re1		: std_logic;
	signal ram_re2		: std_logic;

	signal s_vsync		: std_logic;
	signal s_hsync		: std_logic;
	signal s_de			: std_logic;

	constant pal_offset	: integer := 8;
	constant clr_offset	: integer := 16;
	constant pix_offset	: integer := 244;

	signal varcnt		: integer range 0 to 7;		-- variable load counter
	signal show			: std_logic;				-- show/hide the OSD
	signal xsize		: integer range 0 to 511;	-- number of pixels per row
	signal ysize		: integer range 0 to 255;	-- number of rows of pixels
	signal clrcnt		: integer range 0 to 3;		-- colours load counter
	type colr_t is array (0 to 3) of std_logic_vector(23 downto 0);
	signal colr			: colr_t;

	signal xcnt0		: signed(12 downto 0);		-- X pixel counter
	signal xcnt			: signed(12 downto 0);		-- X pixel counter
	signal ycnt			: signed(12 downto 0);		-- Y pixel counter
	signal pxok			: std_logic;


	signal pixp			: integer range 0 to 2**(ADDR_WIDTH-2)-1;	-- pixel pointer
	signal clrp			: integer range 0 to 2**(ADDR_WIDTH-2)-1;	-- colour change pointer
	signal pix			: std_logic_vector(31 downto 0);
	signal dout_big		: std_logic_vector(31 downto 0);	-- big endian memory read

begin

	ram_din2 <= (others => '0');
	ram_wsb2 <= (others => '0');
	ram_we2 <= '0';
	ram: entity ram_tdp
		generic map (
			DATA_WIDTH => 2**DATA_WIDTH_BITS,
			ADDR_WIDTH => (ADDR_MSB-ADDR_LSB+1)
		)
		port map (
			clk1 => clk,
			clk2 => pclk,
			addr1 => ram_addr1,
			addr2 => ram_addr2,
			din1 => ram_din1,
			din2 => ram_din2,
			wsb1 => ram_wsb1,
			wsb2 => ram_wsb2,
			dout1 => ram_dout1,
			dout2 => ram_dout2,
			we1 => ram_we1,
			we2 => ram_we2,
			re1 => ram_re1,
			re2 => ram_re2
		);
	-- big endian read
	dout_big <= ram_dout2(7 downto 0)&ram_dout2(15 downto 8)&ram_dout2(23 downto 16)&ram_dout2(31 downto 24);

	-- Bridge bus access to the internal memory buffer
	ram_addr1 <= bridge_addr;
	ram_re1 <= bridge_r;
	bridge_r_data <= ram_dout1;
	ram_we1 <= bridge_w;
	ram_din1 <= bridge_w_data;
	ram_wsb1 <= bridge_w_strb;

	-- video management
	ovsync <= s_vsync;
	ohsync <= s_hsync;
	ode <= s_de;

	process(pclk,resetn) is
	begin
		if resetn = '0' then
			odata <= x"000000";
			s_vsync <= '0';
			s_hsync <= '0';
			s_de <= '0';
			xcnt0 <= (others => '0');
			xcnt <= (others => '0');
			ycnt <= (others => '0');
			pxok <= '0';
			intr <= '0';
			pixp <= pix_offset;
			clrp <= clr_offset;
			pix <= (others => '0');
			ram_re2 <= '0';
			ram_addr2 <= (others => '0');
			varcnt <= 0;
			show <= '0';
			clrcnt <= 0;
		elsif rising_edge(pclk) then
			s_vsync <= ivsync;
			s_hsync <= ihsync;
			s_de <= ide;
			odata <= idata;

			if ivsync = '1' and s_vsync = '0' then
				pixp <= pix_offset;
				clrp <= clr_offset;

				-- load variable values from the RAM
				ram_addr2 <= (others => '0');
				ram_re2 <= '1';
				varcnt <= 1;
			elsif varcnt > 0 then
				if varcnt < 7 then
					ram_addr2 <= std_logic_vector(unsigned(ram_addr2)+1);
					varcnt <= varcnt + 1;
				else
					varcnt <= 0;
				end if;
				if varcnt = 2 then
					show <= ram_dout2(0);
				elsif varcnt = 3 then
					xsize <= to_integer(unsigned(ram_dout2(8 downto 0)));
					ysize <= to_integer(unsigned(ram_dout2(23 downto 16)));
					-- initial palette address
					ram_addr2 <= std_logic_vector(to_unsigned(pal_offset,ram_addr2'length));
				elsif varcnt = 4 then
					-- read xdstart / ydstart and convert them to initial counter values
					xcnt0 <= to_signed(-to_integer(unsigned(ram_dout2(11 downto 0))),xcnt0'length);
					ycnt <= to_signed(-to_integer(unsigned(ram_dout2(27 downto 16))),ycnt'length);
				elsif varcnt = 5 then
					colr(0) <= dout_big(31 downto 8);
					colr(1)(23 downto 16) <= dout_big(7 downto 0);
				elsif varcnt = 6 then
					colr(1)(15 downto 0) <= dout_big(31 downto 16);
					colr(2)(23 downto 8) <= dout_big(15 downto 0);
					ram_addr2 <= (others => '0');
					ram_re2 <= '0';
				elsif varcnt = 7 then
					colr(2)(7 downto 0) <= dout_big(31 downto 24);
					colr(3) <= dout_big(23 downto 0);
				end if;
			end if;

			if ihsync = '1' and s_hsync = '0' then
				xcnt <= xcnt0;
				if pxok = '1' then
					-- end of row with pixels
					ycnt <= ycnt + 1;
					intr <= '0';
					if ycnt+1 = ysize*2 then
						intr <= '1';
					end if;
					if ycnt >= 0 and ycnt < ysize*2 then
						if ycnt(0) = '0' then
							pixp <= pixp - xsize/16;
						else
							clrcnt <= 1;
						end if;
					end if;
				end if;
				pxok <= '0';
			elsif clrcnt > 0 and varcnt = 0 then
				if clrcnt < 3 then
					clrcnt <= clrcnt + 1;
				else
					clrcnt <= 0;
				end if;
				if clrcnt = 1 then
					ram_re2 <= '1';
					ram_addr2 <= std_logic_vector(to_unsigned(clrp,ram_addr2'length));
					clrp <= clrp + 1;
				elsif clrcnt = 2 then
					ram_re2 <= '0';
				elsif clrcnt = 3 then
					if ram_dout2(31 downto 26) = "000000" then
						colr(to_integer(unsigned(ram_dout2(25 downto 24)))) <= ram_dout2(23 downto 0);
					end if;
				end if;
			elsif ide = '1' and show = '1' then
				pxok <= '1';
				xcnt <= xcnt + 1;
				if xcnt >= -3 and xcnt < xsize*2 and ycnt >= 0 and ycnt < ysize*2 then
					if xcnt >= 0 then
						odata <= colr(to_integer(unsigned(std_logic_vector'(pix(31)&pix(15)))));
						if xcnt(0) = '1' then
							pix <= pix(30 downto 16) & '0' & pix(14 downto 0) & '0';
						end if;
					end if;
					if xcnt < xsize*2-3 and xcnt(4 downto 3) = "11" then
						-- fetch next pixels word
						if xcnt(2 downto 0) = "101" then
							ram_re2 <= '1';
							ram_addr2 <= std_logic_vector(to_unsigned(pixp,ram_addr2'length));
						elsif xcnt(2 downto 0) = "110" then
							ram_re2 <= '0';
						elsif xcnt(2 downto 0) = "111" then
							pix <= ram_dout2;
							pixp <= pixp + 1;
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;

end arch_imp;
