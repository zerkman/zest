-- pwm_encoder.vhd - Delta-Sigma PCM to PWM encoder
--
-- Copyright (c) 2024-2025 Francois Galea <fgalea at free.fr>
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

entity pwm_encoder is
	generic (
		NBITS	: integer := 16
	);
	port (
		clk		: in std_logic;
		reset	: in std_logic;
		pcm		: in std_logic_vector(NBITS-1 downto 0);
		pwm		: out std_logic
	);
end pwm_encoder;

architecture rtl of pwm_encoder is
	signal err		: integer range -2**(NBITS-1) to 2**(NBITS-1)-1;
	signal cpcm		: integer range -2**NBITS to 2**NBITS-1;
begin
	cpcm <= to_integer(signed(pcm)) + err;

	process(clk,reset)
	begin
		if reset = '1' then
			err <= 0;
			pwm <= '0';
		elsif rising_edge(clk) then
			if cpcm >= 0 then
				pwm <= '1';
				err <= cpcm - 32767;
			else
				pwm <= '0';
				err <= cpcm + 32768;
			end if;
		end if;
	end process;

end architecture;
