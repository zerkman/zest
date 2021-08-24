-- hdmi_packet_gen.vhd - Generator for HDMI data island packets

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

entity hdmi_packet_gen is
	port (
		clk    : in std_logic;
		reset  : in std_logic;

		if_tr  : in std_logic;		-- infoframe island trigger

		data   : out std_logic_vector(7 downto 0);		-- packet data
		dvalid : out std_logic;
		dready : in std_logic
	);
end hdmi_packet_gen;


architecture rtl of hdmi_packet_gen is
	-- Pre-defined data island packet types
	type data_packet_t is array (0 to 30) of std_logic_vector(7 downto 0);
	-- Auxiliary Video Information (AVI) InfoFrame
	constant avi_infoframe : data_packet_t := (
		x"82", x"02", x"0d",	-- AVI InfoFrame version 2 header
		x"94",			-- checksum
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
		others => x"00" );
	constant audio_infoframe : data_packet_t := (
		x"84", x"01", x"0a",	-- Audio InfoFrame header
		x"70",			-- checksum
		x"01",			-- coding = refer to stream header, 2 channels
		x"00",			-- sample freq and sample size = refer to stream header
		x"00",
		x"00",			-- channel/speaker allocation: stereo, front left and right
		x"00",			-- no downmix inhibition, no attenuation
		others => x"00" );

	signal byte_idx : integer range 0 to 30;

	signal tr       : std_logic;
	signal id       : std_logic;
	signal busy     : std_logic;
	signal valid    : std_logic;
begin

	dvalid <= valid;

process(clk)
	variable packet : data_packet_t;
begin
	if rising_edge(clk) then
		if reset = '1' then
			byte_idx <= 0;
			tr <= '0';
			id <= '0';
			busy <= '0';
			valid <= '0';
		else
			tr <= if_tr;
			if id = '0' then
				packet := avi_infoframe;
			else
				packet := audio_infoframe;
			end if;
			if if_tr = '1' and tr = '0' then
				id <= '0';
				busy <= '1';
				valid <= '1';
				data <= avi_infoframe(0);
				byte_idx <= 1;
			end if;
			if valid = '1' and dready = '1' then
				valid <= busy;
				if busy = '1' then
					data <= packet(byte_idx);
					if byte_idx < 30 then
						byte_idx <= byte_idx + 1;
					-- elsif id = '0' then
					-- 	id <= '1';
					-- 	byte_idx <= 0;
					else
						busy <= '0';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;


end architecture;
