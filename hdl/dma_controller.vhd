-- dma_controller.vhd - Implementation of the Atari ST DMA chip
--
-- Copyright (c) 2020 Francois Galea <fgalea at free.fr>
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

entity dma_controller is
	port (
		clk		: in std_logic;
		cken	: in std_logic;

		FCSn	: in std_logic;
		RWn		: in std_logic;
		A1		: in std_logic;
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0)
	);
end dma_controller;

architecture behavioral of dma_controller is

begin

	process(clk)
	begin
		if rising_edge(clk) then
			if cken = '1' then
				oD <= x"ffff";
				if FCSn = '0' and RWn = '1' then
					oD <= x"0000";
				end if;
			end if;
		end if;
	end process;

end architecture;
