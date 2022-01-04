-- i2s_out.vhd - i2s audio encoder
--
-- Copyright (c) 2021,2022 Francois Galea <fgalea at free.fr>
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

entity i2s_output is
	generic (
		MFREQ : integer := 32_000_000;	-- clock frequency
		FREQ  : integer := 48000;		-- sample frequency
		NBITS : integer := 16			-- bit resolution (16/20/24)
	);
	port (
		clk     : in std_logic;
		resetn  : in std_logic;
		data_l  : in std_logic_vector(NBITS-1 downto 0);
		data_r  : in std_logic_vector(NBITS-1 downto 0);
		i2s_sck : out std_logic;
		i2s_fs	: out std_logic;
		i2s_sd	: out std_logic
	);
end i2s_output;

architecture rtl of i2s_output is
	signal bit_cnt : unsigned(4 downto 0);
	signal sck_cnt : unsigned(27 downto 0);
	signal sck     : std_logic;
	signal ws      : std_logic;
	signal ws2     : std_logic;
	signal sr      : std_logic_vector(NBITS-1 downto 0);
	signal dr      : std_logic_vector(NBITS-1 downto 0);
begin

i2s_sck <= sck;
i2s_fs <= ws;
i2s_sd <= sr(NBITS-1);


process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			bit_cnt <= (others => '0');
			sck_cnt <= (others => '0');
			sck <= '0';
			ws <= '1';
			ws2 <= '1';
			sr <= (others => '0');
			dr <= (others => '0');
		else
			if sck_cnt + FREQ*NBITS*2 < MFREQ/2 then
				sck_cnt <= sck_cnt + FREQ*NBITS*2;
			else
				sck <= not sck;
				sck_cnt <= sck_cnt + FREQ*NBITS*2 - MFREQ/2;
				if sck = '1' then
					-- falling edge of sck
					if bit_cnt = NBITS-1 then
						bit_cnt <= (others => '0');
						ws <= not ws;
					else
						bit_cnt <= bit_cnt + 1;
					end if;
					ws2 <= ws;
					if ws /= ws2 then
						if ws = '0' then
							sr <= data_l(7 downto 0) & data_l(15 downto 8);
							dr <= data_r(7 downto 0) & data_r(15 downto 8);
						else
							sr <= dr;
						end if;
					else
						sr <= sr(NBITS-2 downto 0) & '0';
					end if;
				end if;
			end if;
		end if;
	end if;
end process;



end architecture;
