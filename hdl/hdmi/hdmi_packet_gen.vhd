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
	generic (
		SAMPLE_FREQ : integer := 48000
	);
	port (
		clk    : in std_logic;
		reset  : in std_logic;

		island_tr    : in std_logic;		-- trigger data island
		infoframe_en : in std_logic;		-- send infoframes in next data island

		audio_en     : in std_logic;		-- audio enable
		audio_l      : in std_logic_vector(23 downto 0);	-- left channel
		audio_r      : in std_logic_vector(23 downto 0);	-- right channel
		audio_clk    : in std_logic;		-- sample clock

		data   : out std_logic_vector(7 downto 0);		-- packet data
		dvalid : out std_logic;
		dready : in std_logic
	);
end hdmi_packet_gen;


architecture rtl of hdmi_packet_gen is

	-- N and CTS determine the ratio between the sampling frequency (fs) and pixel clock frequency (fpck), such that
	-- 128*fs = fpck*N/CTS
	function get_n(sfq : in integer) return integer is
	begin
		if 128*sfq mod 900 = 0 then
			return 128*sfq/900;
		end if;
		return 128*sfq/1000;
	end function;
	constant N : integer := get_n(SAMPLE_FREQ);
	constant CTS_BITS : integer := 20;
	signal cts : integer range 0 to 2**CTS_BITS-1;
	signal ctscnt : unsigned(17 downto 0);
	signal ctsbuf : std_logic_vector(19 downto 0);
	constant vn   : std_logic_vector(19 downto 0) := std_logic_vector(to_unsigned(N,20));

	component hdmi_audio_packetizer is
		generic (
			SAMPLE_FREQ : integer := 48000
		);
		port (
			clk       : in std_logic;
			reset     : in std_logic;

			audio_en  : in std_logic;		-- audio enable
			audio_l   : in std_logic_vector(23 downto 0);	-- left channel
			audio_r   : in std_logic_vector(23 downto 0);	-- right channel
			audio_clk : in std_logic;		-- sample clock

			data      : out std_logic_vector(7 downto 0);	-- packet data
			dvalid    : out std_logic;
			dready    : in std_logic
		);
	end component;

	type data_packet_t is array (0 to 30) of std_logic_vector(7 downto 0);
	signal audio_clock_regeneration : data_packet_t;

	-- Pre-defined data island packet types
	-- Auxiliary Video Information (AVI) InfoFrame
	constant avi_infoframe : data_packet_t := (
		x"82", x"02", x"0d",	-- AVI InfoFrame version 2 header
		x"94",			-- checksum
		x"12",			-- format = RGB, active format information present, no bar data, activate underscan
		x"19",			-- no colorimetry data, 4/3 input ratio, 4/3 centered display ratio
		x"80",			-- IT content, no colorimetry data (bc. RGB mode), default RGB quantization, no known non-uniform scaling
		x"00",			-- no standard screen mode
		x"30",			-- YCC quantization ignored, game content type, no pixel repetition
		others => x"00" );
	-- Audio Infoframe
	constant audio_infoframe : data_packet_t := (
		x"84", x"01", x"0a",	-- Audio InfoFrame header
		x"70",			-- checksum
		x"01",			-- coding = refer to stream header, 2 channels
		x"00",			-- sample freq and sample size = refer to stream header
		x"00",
		x"00",			-- channel/speaker allocation: stereo, front left and right
		x"00",			-- no downmix inhibition, no attenuation
		others => x"00" );
	-- Source Product Description InfoFrame
	constant spd_infoframe : data_packet_t := (
		x"83", x"01", x"19",	-- Source Product Description InfoFrame header
		x"fc",			-- checksum
		x"73", x"65", x"63", x"74", x"6f", x"72", x"20", x"31",	-- "sector 1"
		x"7a", x"65", x"53", x"54",			-- "zeST"
		others => x"00" );
	type if_array_t is array (0 to 2) of data_packet_t;
	constant if_array : if_array_t := ( audio_infoframe, avi_infoframe, spd_infoframe );

	signal audio_data        : std_logic_vector(7 downto 0);
	signal audio_dvalid      : std_logic;
	signal audio_dready      : std_logic;
	signal send_audio_packet : std_logic;
	signal need_audio_regen  : std_logic;
	signal send_audio_regen  : std_logic;
	signal audio_clk0        : std_logic;

	signal byte_idx : integer range 0 to 30;

	signal island_tr1     : std_logic;
	signal infoframe_en1  : std_logic;
	signal id             : integer range 0 to 2;
	signal packet_valid   : std_logic;
	signal need_infoframe : std_logic;
	signal send_infoframe : std_logic;

	signal packet_data    : std_logic_vector(7 downto 0);

begin
	-- audio clock regeneration packet
	audio_clock_regeneration <= (
		x"01", x"00", x"00",	-- audio clock regeneration header
		x"00", "0000" & ctsbuf(19 downto 16), ctsbuf(15 downto 8), ctsbuf(7 downto 0), "0000" & vn(19 downto 16), vn(15 downto 8), vn(7 downto 0),
		x"00", "0000" & ctsbuf(19 downto 16), ctsbuf(15 downto 8), ctsbuf(7 downto 0), "0000" & vn(19 downto 16), vn(15 downto 8), vn(7 downto 0),
		x"00", "0000" & ctsbuf(19 downto 16), ctsbuf(15 downto 8), ctsbuf(7 downto 0), "0000" & vn(19 downto 16), vn(15 downto 8), vn(7 downto 0),
		x"00", "0000" & ctsbuf(19 downto 16), ctsbuf(15 downto 8), ctsbuf(7 downto 0), "0000" & vn(19 downto 16), vn(15 downto 8), vn(7 downto 0)
		);

	data <= audio_data when send_audio_packet = '1' and audio_dvalid = '1' else packet_data;
	dvalid <= audio_dvalid when send_audio_packet = '1' else packet_valid;
	audio_dready <= dready and send_audio_packet;

	audio_packetizer : hdmi_audio_packetizer generic map (
			SAMPLE_FREQ => SAMPLE_FREQ )
		port map (
			clk => clk,
			reset => reset,
			audio_en => audio_en,
			audio_l => audio_l,
			audio_r => audio_r,
			audio_clk => audio_clk,
			data => audio_data,
			dvalid => audio_dvalid,
			dready => audio_dready
		);

-- send data packets
process(clk)
	variable v_need_infoframe    : std_logic;
	variable v_send_infoframe    : std_logic;
	variable v_send_audio_regen  : std_logic;
	variable v_send_audio_packet : std_logic;
	variable v_cts               : integer range 0 to 2**CTS_BITS-1;
begin
	if rising_edge(clk) then
		if reset = '1' then
			byte_idx <= 0;
			island_tr1 <= '0';
			infoframe_en1 <= '0';
			id <= 0;
			packet_valid <= '0';
			packet_data <= (others => '0');
			need_infoframe <= '0';
			send_infoframe <= '0';
			send_audio_packet <= '0';
			audio_clk0 <= '0';
			need_audio_regen <= '0';
			send_audio_regen <= '0';
			cts <= 0;
			ctsbuf <= (others => '0');
			ctscnt <= (others => '0');
		else
			audio_clk0 <= audio_clk;
			island_tr1 <= island_tr;
			infoframe_en1 <= infoframe_en;
			v_need_infoframe := need_infoframe;
			v_send_audio_regen := send_audio_regen;
			v_send_audio_packet := send_audio_packet;
			if audio_en = '1' then
				v_cts := cts + 1;
				if audio_clk = '1' and audio_clk0 = '0' then
					if ctscnt + 128 >= N then
						need_audio_regen <= '1';
						ctsbuf <= std_logic_vector(to_unsigned(v_cts,CTS_BITS));
						v_cts := 0;
						ctscnt <= ctscnt + 128 - N;
					else
						ctscnt <= ctscnt + 128;
					end if;
				end if;
				cts <= v_cts;
			end if;
			if infoframe_en = '1' and infoframe_en1 = '0' then
				need_infoframe <= '1';
				v_need_infoframe := '1';
			end if;
			v_send_infoframe := send_infoframe;
			if island_tr = '1' and island_tr1 = '0' then
				if v_send_infoframe = '0' and v_need_infoframe = '1' then
					send_infoframe <= '1';
					v_send_infoframe := '1';
					need_infoframe <= '0';
					if (audio_en = '1') then
						id <= 0;
					else
						id <= 1;
					end if;
					packet_data <= avi_infoframe(0);
				end if;
				if need_audio_regen = '1' then
					v_send_audio_regen := '1';
					send_audio_regen <= '1';
					need_audio_regen <= '0';
					packet_data <= audio_clock_regeneration(0);
				end if;
				if audio_dvalid = '1' then
					v_send_audio_packet := '1';
				end if;
				if v_send_audio_regen = '1' or v_send_infoframe = '1' then
					packet_valid <= '1';
					byte_idx <= 1;
				end if;
			end if;
			if send_audio_packet = '1' then
				if audio_dvalid = '0' then
					-- end of audio packet transmission
					v_send_audio_packet := '0';
				end if;
			end if;
			if packet_valid = '1' and dready = '1' and audio_dready = '0' then
				packet_valid <= v_send_audio_regen or v_send_infoframe;
				if v_send_audio_regen = '1' then
					packet_data <= audio_clock_regeneration(byte_idx);
					if byte_idx < 30 then
						byte_idx <= byte_idx + 1;
					else
						byte_idx <= 0;
						send_audio_regen <= '0';
					end if;
				elsif v_send_infoframe = '1' then
					packet_data <= if_array(id)(byte_idx);
					if byte_idx < 30 then
						byte_idx <= byte_idx + 1;
					elsif id < if_array'high then
						id <= id + 1;
						byte_idx <= 0;
					else
						send_infoframe <= '0';
					end if;
				end if;
			end if;
			send_audio_packet <= v_send_audio_packet;
		end if;
	end if;
end process;


end architecture;
