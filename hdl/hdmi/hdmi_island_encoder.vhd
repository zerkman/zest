-- hdmi_island_encoder.vhd - HDMI data island encoder

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

entity hdmi_island_encoder is
	port (
		clk      : in std_logic;
		reset    : in std_logic;

		data     : in std_logic_vector(7 downto 0);
		dvalid   : in std_logic;
		dready   : out std_logic;

		busy     : out std_logic;
		preamble : out std_logic;
		guard    : out std_logic;
		packet   : out std_logic;
		aux0     : out std_logic;
		aux1     : out std_logic_vector(3 downto 0);
		aux2     : out std_logic_vector(3 downto 0)
	);
end hdmi_island_encoder;

architecture rtl of hdmi_island_encoder is

	-- Data island packet
	type data_packet_t is array (0 to 30) of std_logic_vector(7 downto 0);
	-- packet double buffer
	type data_packet_buffer_t is array (0 to 1) of data_packet_t;
	signal packet_buffer : data_packet_buffer_t;
	-- read packet index

	signal packet_rd_buf_idx : integer range 0 to 1;
	signal packet_rd_idx : integer range 0 to 30;
	-- packet buffer read state
	signal packet_available : std_logic;
	signal buffer_full : std_logic;

	signal packet_wr_buf_idx : integer range 0 to 1;

	-- state counter for infoframe data island generation
	signal ifcnt     : unsigned(4 downto 0);
	signal ecc0      : std_logic_vector(7 downto 0);
	type chn_ecc_t is array(0 to 3) of std_logic_vector(7 downto 0);
	signal ecc       : chn_ecc_t;

	type island_st_t is (idle, preamb, ld_guard, pack, tr_guard);
	signal island_st : island_st_t;

	signal s_busy     : std_logic;
	signal s_preamble : std_logic;
	signal s_guard    : std_logic;
	signal s_packet   : std_logic;

	function next_ecc(old_ecc : in std_logic_vector; x : in std_logic) return std_logic_vector is
	begin
		return ('0' & old_ecc(7 downto 1)) xor (x"83" and (7 downto 0 => (x xor old_ecc(0))));
	end function;


begin

	s_busy <= '1' when island_st /= idle else '0';
	s_preamble <= '1' when island_st = preamb else '0';
	s_guard <= '1' when island_st = ld_guard or island_st = tr_guard else '0';
	s_packet <= '1' when island_st = pack else '0';

	buffer_full <= '1' when packet_rd_buf_idx /= packet_wr_buf_idx and packet_rd_idx = 30 else '0';
	dready <= '1' when dvalid = '1' and buffer_full = '0' else '0';

process(clk)
begin
	if rising_edge(clk) then
		busy <= s_busy;
		preamble <= s_preamble;
		guard <= s_guard;
		packet <= s_packet;
	end if;
end process;

-- Read input data
process(clk)
begin
	if rising_edge(clk) then
		if reset = '1' then
			packet_rd_buf_idx <= 0;
			packet_rd_idx <= 0;
		else
			if dvalid = '1' and buffer_full = '0' then
				-- dready is set (combinatorial)
				packet_buffer(packet_rd_buf_idx)(packet_rd_idx) <= data;
				if packet_rd_idx < 30 then
					packet_rd_idx <= packet_rd_idx + 1;
				else
					packet_rd_idx <= 0;
					packet_rd_buf_idx <= 1-packet_rd_buf_idx;
				end if;
			end if;
		end if;
	end if;
end process;

-- BCH encoder auxiliary data
process(clk)
	variable pck : data_packet_t;
	variable bid : integer range 0 to 7;
	variable idx : integer range 0 to 30;
	variable ec  : std_logic_vector(7 downto 0);
	variable b   : std_logic;
begin
	if rising_edge(clk) then
		if reset = '1' then
			packet_wr_buf_idx <= 0;
			ifcnt <= (others => '0');
			island_st <= idle;
			aux0 <= '0';
			aux1 <= "0000";
			aux2 <= "0000";
		else
			if ifcnt > 0 then
				ifcnt <= ifcnt - 1;
			end if;

			case island_st is
			when idle =>
				if packet_rd_idx = 15 then
					ifcnt <= to_unsigned(7,ifcnt'length);
					island_st <= preamb;
				end if;
			when preamb =>
				if ifcnt = 0 then
					ifcnt <= to_unsigned(1,ifcnt'length);
					island_st <= ld_guard;
				end if;
			when ld_guard =>
				if ifcnt = 0 then
					ifcnt <= to_unsigned(31,ifcnt'length);
					ecc0 <= x"00";
					ecc <= (others => x"00");
					island_st <= pack;
				end if;
			when pack =>
				pck := packet_buffer(packet_wr_buf_idx);
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
					packet_wr_buf_idx <= 1-packet_wr_buf_idx;
					if packet_wr_buf_idx /= packet_rd_buf_idx and packet_rd_idx = 0 then
						-- buffer is empty - end of data island
						ifcnt <= to_unsigned(1,ifcnt'length);
						island_st <= tr_guard;
					else
						-- send another packet
						ifcnt <= to_unsigned(31,ifcnt'length);
						ecc0 <= x"00";
						ecc <= (others => x"00");
					end if;
				end if;
			when tr_guard =>
				aux0 <= '0';
				aux1 <= "0000";
				aux2 <= "0000";
				if ifcnt = 0 then
					island_st <= idle;
				end if;
			end case;
		end if;
	end if;
end process;



end architecture;
