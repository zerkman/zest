-- video_mixer.vhd - Atari ST RGB/mono video signal mixer
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

library work;
use work.all;

entity video_mixer is
	port (
		monomon			: in std_logic;
		shifter_rgb		: in std_logic_vector(8 downto 0);
		shifter_mono	: in std_logic;
		blankn			: in std_logic;

		rgb				: out std_logic_vector(8 downto 0)
	);
end video_mixer;

architecture rtl of video_mixer is

begin
	process(shifter_rgb,shifter_mono,blankn,monomon) is
		begin
			rgb <= (others => '0');
			if monomon = '1' then
				rgb <= (others => shifter_mono);
			elsif blankn = '1' then
				rgb <= shifter_rgb;
			end if;
		end process;

end architecture;
