-- sound_mixer.vhd - Atari ST sound mixer
--
-- Copyright (c) 2023 Francois Galea <fgalea at free.fr>
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

entity sound_mixer is
	port (
		clk			: in std_logic;
		cken		: in std_logic;
		reset		: in std_logic;

		psg_cken	: in std_logic;
		psg_a		: in std_logic_vector(15 downto 0);
		psg_b		: in std_logic_vector(15 downto 0);
		psg_c		: in std_logic_vector(15 downto 0);

		sound_clk	: in std_logic;
		sound		: out std_logic_vector(15 downto 0)
	);
end sound_mixer;

architecture rtl of sound_mixer is
	signal snd_clk1	: std_logic;
	signal x0		: integer range -2**15 to 2**15-1;
	signal x1		: integer range -2**15 to 2**15-1;
	signal y0		: integer range -2**15 to 2**15-1;
	signal y1		: integer range -2**15 to 2**15-1;
	signal z0		: integer range -2**15 to 2**15-1;
	signal z1		: integer range -2**25 to 2**25-1;
begin

	sound <= std_logic_vector(to_signed(z0,16));

	-- Low pass filter simulating the STF's YM output RC circuitry
	-- method taken from the Hatari ST emulator
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				x0 <= 0;
				x1 <= 0;
				y0 <= 0;
			elsif psg_cken = '1' then
				-- PSG state has changed
				x0 <= (to_integer(signed(psg_a)) + to_integer(signed(psg_b)) + to_integer(signed(psg_c)))/4;
				x1 <= x0;
				if x0 >= y0 then
					-- YM Pull up:   fc = 7586.1 Hz (44.1 KHz), fc = 8257.0 Hz (48 KHz)
					y0 <= (3*(x0 + x1) + (2*y0)) / 8;
				else
					-- R8 Pull down: fc = 1992.0 Hz (44.1 KHz), fc = 2168.0 Hz (48 KHz)
					y0 <= ((x0 + x1) + (6*y0)) / 8;
				end if;
			end if;
		end if;
	end process;

	-- DC adjuster as a IIR HPF
	-- method taken from the Hatari ST emulator
	z0 <= z1/(2**9);
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				snd_clk1 <= '0';
				y1 <= 0;
				z1 <= 0;
			else
				snd_clk1 <= sound_clk;
				if sound_clk = '0' and snd_clk1 = '1' then	-- low edge of sound clock
					-- apply DC correcting HPF
					z1 <= z1 + (y0 - y1)*(2**9) - z0;
					y1 <= y0;
				end if;
			end if;
		end if;
	end process;


end architecture;
