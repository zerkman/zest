-- hdmi_signaling.vhd - HDMI signal generator
--
-- Copyright (c) 2021 Francois Galea <fgalea at free.fr>
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

entity hdmi_sig is
	port (
		clk   : in std_logic;
		reset : in std_logic;
		rgb   : in std_logic_vector(23 downto 0);
		vsync : in std_logic;
		hsync : in std_logic;
		ide   : in std_logic;

		data  : out std_logic_vector(23 downto 0);
		de    : out std_logic;		-- display enable
		ae    : out std_logic;		-- aux enable
		vgb   : out std_logic;		-- video leading guard band
		dgb   : out std_logic		-- data island leading or trailing guard band
	);
end hdmi_sig;

architecture rtl of hdmi_sig is
	-- shift register for input signals
	type sdelay_e_t is record
		data  : std_logic_vector(23 downto 0);
		de    : std_logic;
	end record;
	type sdelay_t is array (0 to 10) of sdelay_e_t;
	signal sdelay : sdelay_t;

	-- signals for preamble and guard band generation
	signal pr_cnt : unsigned(3 downto 0);
	signal old_de : std_logic;

	-- signals to trigger the generation of the infoframe data island
	signal vsync0     : std_logic;
	signal info_ready : std_logic;
	signal if_trig    : std_logic;

	-- Pre-defined data island packet types
	type data_packet_t is array (0 to 30) of std_logic_vector(7 downto 0);
	-- Auxiliary Video Information (AVI) InfoFrame
	constant avi_infoframe : data_packet_t := (
		x"82", x"02", x"0d",	-- AVI InfoFrame version 2 header
		x"12",			-- format = RGB, active format information present, no bar data, activate underscan

		-- x"28",			-- no colorimetry data, 16/9 input ratio, same display ratio
		-- x"2a",			-- no colorimetry data, 16/9 input ratio, 16/9 centered display ratio
		-- x"18",			-- no colorimetry data, 4/3 input ratio, same display ratio
		x"19",			-- no colorimetry data, 4/3 input ratio, 4/3 centered display ratio

		x"80",			-- IT content, no colorimetry data (bc. RGB mode), default RGB quantization, no known non-uniform scaling

		-- x"10",			-- 1920x1080p @ 60 Hz
		-- x"11",			-- 720x576p @ 50 Hz, 4:3
		x"00",			-- no standard screen mode

		x"30",			-- YCC quantization ignored, game content type, no pixel repetition
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00",
		x"00", x"00", x"00", x"00", x"00", x"00", x"00" );
	type island_st_t is (idle, preamble, ld_guard, packet, tr_guard);
	signal island_st : island_st_t;
	signal islandst1 : island_st_t;
	signal packet0   : std_logic;	-- determines 1st char of data packet
	-- state counter for infoframe data island generation
	signal ifcnt     : unsigned(4 downto 0);
	signal ecc0      : std_logic_vector(7 downto 0);
	type chn_ecc_t is array(0 to 3) of std_logic_vector(7 downto 0);
	signal ecc       : chn_ecc_t;

	-- BCH encoded auxiliary data
	signal aux0      : std_logic;
	signal aux1      : std_logic_vector(3 downto 0);
	signal aux2      : std_logic_vector(3 downto 0);

	function next_ecc(old_ecc : in std_logic_vector; x : in std_logic) return std_logic_vector is
	begin
		return (old_ecc(0) & old_ecc(7 downto 1)) xor (x"83" and (7 downto 0 => x));
	end function;

begin

process(clk)
	variable dly : sdelay_e_t;
begin
	if rising_edge(clk) then
		if reset = '1' then
			sdelay <= (others => ((others => '0'), '0'));
		else
			if ide = '1' then
				dly.data := rgb;
			else
				dly.data := x"03030" & "00" & vsync & hsync;
			end if;
			dly.de := ide;
			sdelay <= sdelay(1 to sdelay'high) & dly;
		end if;
	end if;
end process;

-- preamble counter management
process(clk)
begin
	if rising_edge(clk) then
		if reset = '1' then
			old_de <= '0';
			pr_cnt <= x"0";
		else
			old_de <= ide;
			if ide = '1' and old_de = '0' then
				pr_cnt <= x"a";
			elsif pr_cnt > 0 then
				pr_cnt <= pr_cnt - 1;
			end if;
		end if;
	end if;
end process;

process(clk)
	variable dly : sdelay_e_t;
begin
	if rising_edge(clk) then
		if reset = '1' then
			data <= (others => '0');
			de <= '0';
			ae <= '0';
			vgb <= '0';
			dgb <= '0';
			vsync0 <= '0';
			info_ready <= '1';
			if_trig <= '0';
			packet0 <= '0';
		else
			islandst1 <= island_st;		-- one cycle dela
			dly := sdelay(0);
			data <= dly.data;
			de <= dly.de;
			ae <= '0';
			vgb <= '0';
			dgb <= '0';
			if_trig <= '0';
			if dly.de = '0' then
				-- default: only output vsync & hsync
				if islandst1 /= idle then
					-- data island mode
					if islandst1 = preamble then
						-- preamble for data island period
						data(17 downto 16) <= "01";
						data(9 downto 8) <= "01";
						packet0 <= '0';
					elsif islandst1 = ld_guard or islandst1 = tr_guard then
						-- leading or trailing guard band
						ae <= '1';
						dgb <= '1';
						data(3 downto 2) <= "11";
					elsif islandst1 = packet then
						ae <= '1';
						data(2) <= aux0;
						data(3) <= packet0;
						packet0 <= '1';
						data(11 downto 8) <= aux1;
						data(19 downto 16) <= aux2;
					end if;
				elsif pr_cnt > 2 then
					-- preamble for video data period
					data(17 downto 16) <= "00";
					data(9 downto 8) <= "01";
				elsif pr_cnt > 0 then
					-- video leading guard band
					vgb <= '1';
				end if;
				vsync0 <= dly.data(1);
				if dly.data(1) /= vsync0 then
					if info_ready = '1' then
						info_ready <= '0';
					else
						-- second vsync value change after video display => trigger data island for InfoFrames
						if_trig <= '1';
					end if;
				end if;
			else
				info_ready <= '1';
			end if;
		end if;
	end if;
end process;


process(clk)
	variable pck : data_packet_t := avi_infoframe;
	variable bid : integer range 0 to 7;
	variable idx : integer range 0 to 30;
	variable ec  : std_logic_vector(7 downto 0);
	variable b   : std_logic;
begin
	if rising_edge(clk) then
		if reset = '1' then
			ifcnt <= (others => '0');
			island_st <= idle;
		else
			if ifcnt > 0 then
				ifcnt <= ifcnt - 1;
			end if;

			case island_st is
			when idle =>
				if if_trig = '1' then
					ifcnt <= to_unsigned(7,ifcnt'length);
					island_st <= preamble;
				end if;
			when preamble =>
				if ifcnt = 0 then
					ifcnt <= to_unsigned(1,ifcnt'length);
					island_st <= ld_guard;
				end if;
			when ld_guard =>
				if ifcnt = 0 then
					ifcnt <= to_unsigned(31,ifcnt'length);
					ecc0 <= x"00";
					ecc <= (others => x"00");
					island_st <= packet;
				end if;
			when packet =>
				bid := 7 - to_integer(ifcnt(2 downto 0));
				if ifcnt >= 8 then
					idx := 3 - to_integer(ifcnt(4 downto 3));
					b := pck(idx)(bid);
					aux0 <= b;
					ecc0 <= next_ecc(ecc0,b);
				else
					aux0 <= ecc0(bid);
				end if;

				bid := 6 - 2 * to_integer(ifcnt(1 downto 0));
				idx := 3 + 7 - to_integer(ifcnt(4 downto 2));
				if ifcnt >= 4 then
					for i in 0 to 3 loop
						b := pck(idx+7*i)(bid);
						aux1(i) <= b;
						ec := next_ecc(ecc(i),b);
						b := pck(idx+7*i)(bid+1);
						aux2(i) <= b;
						ecc(i) <= next_ecc(ec,b);
					end loop;
				else
					for i in 0 to 3 loop
						aux1(i) <= ecc(i)(bid);
						aux2(i) <= ecc(i)(bid+1);
					end loop;
				end if;

				if ifcnt = 0 then
					ifcnt <= to_unsigned(1,ifcnt'length);
					island_st <= tr_guard;
				end if;
			when tr_guard =>
				if ifcnt = 0 then
					island_st <= idle;
				end if;
			end case;
		end if;
	end if;
end process;


end architecture;
