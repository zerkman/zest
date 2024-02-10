-- mono_hde_gen.vhd - Generate a clean HDE signal in mono resolution
--
-- Copyright (c) 2024 Francois Galea <fgalea at free.fr>
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

entity mono_hde_gen is
	port (
		clk : in std_logic;
		clken : in std_logic;
		resetn : in std_logic;
		wakest : in std_logic_vector(1 downto 0);
		in_hde : in std_logic;
		out_hde : out std_logic
	);
end entity;

architecture hdl of mono_hde_gen is
	constant MAX : integer := 1023;

	signal ccnt : integer range 0 to MAX;
	signal hde1 : std_logic;
	signal begdly : integer range 0 to 31;
begin

	begdly <= to_integer(unsigned(wakest)+1)*4+14;

process(clk,resetn)
	variable nccnt : integer range 0 to MAX;
begin
	if resetn = '0' then
		ccnt <= 0;
		hde1 <= '0';
		out_hde <= '0';
	elsif rising_edge(clk) then
		if clken = '1' then
			hde1 <= in_hde;
			if in_hde = '1' and hde1 = '0' then
				nccnt := 0;
			elsif ccnt < MAX then
				nccnt := ccnt + 1;
			end if;
			ccnt <= nccnt;
			if nccnt = begdly then
				out_hde <= '1';
			elsif nccnt = begdly+640 then
				out_hde <= '0';
			end if;
		end if;
	end if;
end process;

end architecture;
