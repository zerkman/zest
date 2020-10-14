-- sim_host.vhd - Simulation of host for Floppy emulator
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

entity sim_host is
	port (
		clk			: in std_logic;
		clken		: in std_logic;
		resetn		: in std_logic;

		intr		: in std_logic;
		din			: in std_logic_vector(31 downto 0);
		dout		: out std_logic_vector(31 downto 0);
		r			: in std_logic;
		w			: in std_logic;
		addr		: in std_logic_vector(10 downto 0);
		track		: in std_logic_vector(7 downto 0)
	);

end sim_host;

architecture behavioral of sim_host is
	signal intr_ff	: std_logic;
begin

	process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				dout <= (others => '0');
			elsif clken = '1' then
				intr_ff <= intr;
				if intr = '1' and intr_ff = '0' then
					if r = '1' then
						dout <= not track & track & "00000" & addr;
					end if;
				end if;
			end if;
		end if;
	end process;

end architecture;
