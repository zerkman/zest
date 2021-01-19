-- simple_ram.vhd - simple RAM implementation suitable for simulation
--
-- Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
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

entity simple_ram is
	generic (
		MEM_SIZE	: integer	:= 32768
	);
	port (
		clk		: in std_logic;
		resetn	: in std_logic;

		-- address
		A		: in std_logic_vector(23 downto 1);
		-- input data
		iD		: in std_logic_vector(15 downto 0);
		-- output data
		oD		: out std_logic_vector(15 downto 0);
		-- initiate write transaction
		W		: in std_logic;
		-- initiate read transaction
		R		: in std_logic;
		-- data strobe (for each byte of the data bus)
		DS		: in std_logic_vector(1 downto 0);

		-- Write done signal
		W_DONE	: out std_logic;
		-- Read done signal
		R_DONE	: out std_logic
	);
end simple_ram;

architecture arch_imp of simple_ram is

	signal address : integer;
	type testmem is array(0 to MEM_SIZE/2-1) of std_logic_vector(15 downto 0);
	signal mem	: testmem := (
		x"0000",x"0300",x"0000",x"0008",x"46fc",x"2700",x"200f",x"e048",
		x"21c0",x"8200",x"11fc",x"0005",x"8001",x"41f8",x"fc00",x"10bc",
		x"0003",x"10bc",x"0096",x"11fc",x"0000",x"fa03",x"11fc",x"0000",
		x"fa05",x"11fc",x"0048",x"fa17",x"11fc",x"0040",x"fa09",x"11fc",
		x"0040",x"fa15",x"41fa",x"0020",x"21c8",x"0118",x"46fc",x"2500",
		x"7000",x"11c0",x"8800",x"11c0",x"8802",x"31c0",x"8240",x"11fc",
		x"0002",x"820a",x"60fe",x"11f8",x"fc02",x"0008",x"11fc",x"00bf",
		x"fa11",x"4e73",
		others => x"0000"
	);

begin
	address <= to_integer(unsigned(A));

	-- Add user logic here
	process (clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				oD <= (others => '1');
				W_DONE <= '0';
				R_DONE <= '0';
			else
				oD <= (others => '1');
				if R = '1' then
					oD <= mem(address);
					R_DONE <= '1';
				else
					R_DONE <= '0';
				end if;
				if W = '1' then
					-- write cycle
					if DS(1) = '1' then
						mem(address)(15 downto 8) <= iD(15 downto 8);
					end if;
					if DS(0) = '1' then
						mem(address)(7 downto 0) <= iD(7 downto 0);
					end if;
					W_DONE <= '1';
				else
					W_DONE <= '0';
				end if;
			end if;
		end if;
	end process;
	-- User logic ends

end arch_imp;
