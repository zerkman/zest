-- ram_tdp.vhd - True dual-port RAM
--
-- Copyright (c) 2022-2025 Francois Galea <fgalea at free.fr>
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

entity ram_tdp is
	generic (
		DATA_WIDTH : integer := 32;
		ADDR_WIDTH : integer := 10
	);
	port (
		clk1  : in std_logic;
		clk2  : in std_logic;
		addr1 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		addr2 : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		din1  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		din2  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		wsb1  : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		wsb2  : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		dout1 : out std_logic_vector(DATA_WIDTH-1 downto 0);
		dout2 : out std_logic_vector(DATA_WIDTH-1 downto 0);
		we1   : in std_logic;
		we2   : in std_logic;
		re1   : in std_logic;
		re2   : in std_logic
	);
end ram_tdp;

architecture behavioral of ram_tdp is
	type mem_t is array (2**ADDR_WIDTH-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
	shared variable mem : mem_t;

begin

process(clk1)
begin
	if rising_edge(clk1) then
		if re1 = '1' then
			dout1 <= mem(to_integer(unsigned(addr1)));
		end if;
		if we1 = '1' then
			for i in 0 to (DATA_WIDTH/8-1) loop
				if wsb1(i) = '1' then
					mem(to_integer(unsigned(addr1)))(i*8+7 downto i*8) := din1(i*8+7 downto i*8);
				end if;
			end loop;
		end if;
	end if;
end process;

process(clk2)
begin
	if rising_edge(clk2) then
		if re2 = '1' then
			dout2 <= mem(to_integer(unsigned(addr2)));
		end if;
		if we2 = '1' then
			for i in 0 to (DATA_WIDTH/8-1) loop
				if wsb2(i) = '1' then
					mem(to_integer(unsigned(addr2)))(i*8+7 downto i*8) := din2(i*8+7 downto i*8);
				end if;
			end loop;
		end if;
	end if;
end process;

end architecture;
