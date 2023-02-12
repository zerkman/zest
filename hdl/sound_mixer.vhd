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
		psg_a		: in std_logic_vector(15 downto 0);
		psg_b		: in std_logic_vector(15 downto 0);
		psg_c		: in std_logic_vector(15 downto 0);

		sound		: out std_logic_vector(15 downto 0)
	);
end sound_mixer;

architecture rtl of sound_mixer is
	signal sndsum	: signed(17 downto 0);
begin

	sndsum <= resize(signed(psg_a),sndsum'length) + resize(signed(psg_b),sndsum'length) + resize(signed(psg_c),sndsum'length);
	sound <= std_logic_vector(sndsum(17 downto 2));

end architecture;
