-- hdmi_audio_packetizer.vhd - Generator for HDMI audio packets

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

-- Mostly inspired by the work by Sameer Puri (https://github.com/sameer)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity hdmi_audio_packetizer is
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
end hdmi_audio_packetizer;


architecture rtl of hdmi_audio_packetizer is

	type sample_t is array (0 to 1) of std_logic_vector(23 downto 0);
	type sample_buf_t is array (0 to 7) of sample_t;
	signal sample_buf     : sample_buf_t;
	signal buf_beg        : unsigned(2 downto 0);
	signal buf_end        : unsigned(2 downto 0);
	signal audio_clk0     : std_logic;
	signal n_samples      : unsigned(2 downto 0);
	signal sample_present : std_logic_vector(3 downto 0);
	signal frame_begin    : std_logic_vector(3 downto 0);

	signal byte_idx       : integer range 0 to 30;
	signal frame_cnt      : integer range 0 to 191;
	signal sample_id      : integer range 0 to 3;
	signal sample_pos     : integer range 0 to 6;
	signal parity_l       : std_logic;
	signal parity_r       : std_logic;

	-- channel status values, see IEC 60958-3, section 5.2.2

	function freq_code(x : in integer) return std_logic_vector is
		begin
			case x is
				when 32000 => return "0011";
				when 44100 => return "0000";
				when 48000 => return "0010";
				when 88200 => return "1000";
				when 96000 => return "1010";
				when 176400 => return "1100";
				when 192000 => return "1110";
				when others => return "XXXX";
			end case;
	end function;

	-- consumer use - 0 -> consumer, 1 -> professional
	constant consumer_use : std_logic := '0';

	-- sample representation - 0 -> linear PCM
	constant sample_representation : std_logic := '0';

	-- copyright protection flag
	constant no_copyright_asserted : std_logic := '1';

	-- additional format info - linear PCM audio mode - 0 -> 2 audio channels without pre-emphasis
	constant additional_format : std_logic_vector(2 downto 0) := "000";

	-- channel status mode - must be 0
	constant channel_status_mode : std_logic_vector(1 downto 0) := "00";

	-- category code - 0 => general
	constant category_code : std_logic_vector(7 downto 0) := x"00";

	-- source number - 0 => do not take into account
	constant source_number : std_logic_vector(3 downto 0) := "0000";

	-- audio channels
	constant channel_l : std_logic_vector(3 downto 0) := "0001";
	constant channel_r : std_logic_vector(3 downto 0) := "0010";

	-- sampling frequency code
	constant sampling_freq : std_logic_vector(3 downto 0) := freq_code(SAMPLE_FREQ);

	-- clock accuracy (00 => level II)
	constant clock_accuracy : std_logic_vector(1 downto 0) := "00";

	-- sample word length - 16 bit -> "0010", 24 bit -> "1011"
	constant word_length : std_logic_vector(3 downto 0) := "1011";

	-- original sampling frequency - 0000 => not indicated (default)
	constant original_freq : std_logic_vector(3 downto 0) := "0000";

	constant channel_status_l : std_logic_vector(191 downto 0) :=
		(191 downto 40 => '0') & original_freq & word_length & "00"
		& clock_accuracy & sampling_freq & channel_l & source_number
		& category_code & channel_status_mode & additional_format
		& no_copyright_asserted & sample_representation & consumer_use;

	constant channel_status_r : std_logic_vector(191 downto 0) :=
		(191 downto 40 => '0') & original_freq & word_length & "00"
		& clock_accuracy & sampling_freq & channel_r & source_number
		& category_code & channel_status_mode & additional_format
		& no_copyright_asserted & sample_representation & consumer_use;

	constant valid_l      : std_logic_vector(3 downto 0) := "0000";
	constant valid_r      : std_logic_vector(3 downto 0) := "0000";
	constant user_data_l  : std_logic_vector(3 downto 0) := "0000";
	constant user_data_r  : std_logic_vector(3 downto 0) := "0000";

	constant layout       : std_logic := '0';
	constant sample_flat  : std_logic_vector := "0000";

	function parity(x : in std_logic_vector) return std_logic is
		variable p : std_logic;
		begin
			p := '0';
			for i in x'range loop
				p := p xor x(i);
			end loop;
			return p;
	end function;

begin

-- write to sample buffer
process(clk)
begin
	if rising_edge(clk) then
		if reset = '1' then
			buf_end <= to_unsigned(0, buf_end'length);
			audio_clk0 <= '0';
		elsif audio_en = '1' then
			audio_clk0 <= audio_clk;
			if audio_clk = '1' and audio_clk0 = '0' then
				sample_buf(to_integer(buf_end)) <= ( audio_l, audio_r );
				if buf_end + 1 /= buf_beg then
					buf_end <= buf_end + 1;
				end if;
			end if;
		end if;
	end if;
end process;


-- send data packet
process(clk)
	variable v_sample_present : std_logic_vector(3 downto 0);
	variable v_n_samples      : unsigned(2 downto 0);
	variable v_frame_cnt      : integer range 0 to 191;
	variable v_data           : std_logic_vector(7 downto 0);
	variable v_buf_beg        : unsigned(2 downto 0);
begin
	if rising_edge(clk) then
		if reset = '1' then
			byte_idx <= 0;
			buf_beg <= to_unsigned(0, buf_beg'length);
			data <= (others => '0');
			dvalid <= '0';
			frame_cnt <= 0;
			sample_id <= 0;
			sample_pos <= 0;
			parity_l <= '0';
			parity_r <= '0';
			n_samples <= to_unsigned(0, n_samples'length);
		else
			if byte_idx = 0 then
				v_buf_beg := buf_beg;
				if dready = '1' then
					-- end of packet transmission
					v_buf_beg := buf_beg + n_samples;
					buf_beg <= v_buf_beg;
					dvalid <= '0';
				end if;
				if buf_end /= v_buf_beg then
					data <= x"02";		-- audio sample packet id
					dvalid <= '1';
					byte_idx <= 1;
				end if;
			elsif dready = '1' then
				data <= x"00";
				case byte_idx is
					when 1 =>
						v_n_samples := buf_end - buf_beg;
						n_samples <= v_n_samples;
						v_sample_present := "0000";
						frame_begin <= "0000";
						for i in 0 to 3 loop
							if frame_cnt + i >= 192 then
								v_frame_cnt := frame_cnt + i - 192;
							else
								v_frame_cnt := frame_cnt + i;
							end if;
							if i < v_n_samples then
								v_sample_present(i) := '1';
								if v_frame_cnt = 0 then
									frame_begin(i) <= '1';
								end if;
							end if;
						end loop;
						sample_present <= v_sample_present;
						data <= "000" & layout & v_sample_present;
					when 2 =>
						data <= frame_begin & sample_flat;
						sample_id <= 0;
						sample_pos <= 0;
					when others =>
						if sample_present(sample_id) = '1' then
							case sample_pos is
								when 0 =>
									-- left channel, low byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(0)(7 downto 0);
									parity_l <= parity(v_data) xor channel_status_l(frame_cnt) xor user_data_l(sample_id) xor valid_l(sample_id);
									data <= v_data;
								when 1 =>
									-- left channel, medium byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(0)(15 downto 8);
									parity_l <= parity_l xor parity(v_data);
									data <= v_data;
								when 2 =>
									-- left channel, high byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(0)(23 downto 16);
									parity_l <= parity_l xor parity(v_data);
									data <= v_data;
								when 3 =>
									-- right channel, low byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(1)(7 downto 0);
									parity_r <= parity(v_data) xor channel_status_r(frame_cnt) xor user_data_r(sample_id) xor valid_r(sample_id);
									data <= v_data;
								when 4 =>
									-- right channel, medium byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(1)(15 downto 8);
									parity_r <= parity_r xor parity(v_data);
									data <= v_data;
								when 5 =>
									-- right channel, high byte
									v_data := sample_buf(to_integer(buf_beg+sample_id))(1)(23 downto 16);
									parity_r <= parity_r xor parity(v_data);
									data <= v_data;
								when others => null;
							end case;
							if sample_pos = 6 then
								data <= parity_r & channel_status_r(frame_cnt) & user_data_r(sample_id) & valid_r(sample_id)
								      & parity_l & channel_status_l(frame_cnt) & user_data_l(sample_id) & valid_l(sample_id);
								if frame_cnt < 191 then
									frame_cnt <= frame_cnt + 1;
								else
									frame_cnt <= 0;
								end if;
							end if;

							if sample_pos < 6 then
								sample_pos <= sample_pos + 1;
							elsif sample_id < 3 then
								sample_pos <= 0;
								sample_id <= sample_id + 1;
							else
								sample_pos <= 0;
								sample_id <= 0;
							end if;
						end if;
				end case;

				if byte_idx < 30 then
					byte_idx <= byte_idx + 1;
				else
					byte_idx <= 0;
				end if;
			end if;

		end if;
	end if;
end process;


end architecture;
