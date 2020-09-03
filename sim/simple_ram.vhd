-- simple_ram.vhd - simple RAM implementation suitable for simulation
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
		x"0000",x"1234",x"0000",x"0008",x"4ff8",x"0300",x"204f",x"2008",
		x"e048",x"21c0",x"8200",x"31fc",x"0777",x"8240",x"4278",x"825e",
		x"203c",x"00ff",x"00ff",x"7218",x"7407",x"7609",x"20c0",x"20c0",
		x"20c0",x"20c0",x"51cb",x"fff6",x"51ca",x"fff0",x"4680",x"51c9",
		x"ffe8",x"60fe",
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
