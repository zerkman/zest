-- bridge_dispatcher.vhd - bridge bus host dispatcher
--
-- Copyright (c) 2023-2025 Francois Galea <fgalea at free.fr>
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

entity bridge_dispatcher is
	generic (
		DATA_WIDTH_BITS	: integer := 5;		-- log2(width of data bus)
		ADDR_WIDTH		: integer := 16;	-- Width of address bus
		SUBADDR_WIDTH	: integer := 13;	-- log2(address space) for each subspace
		N_OUTPUTS		: integer := 2		-- number of outputs
	);
	port (
		clk				: in std_logic;
		resetn			: in std_logic;

		-- bridge host signals
		host_addr		: in std_logic_vector(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
		host_r			: in std_logic;
		host_r_data		: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		host_w			: in std_logic;
		host_w_data		: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		host_w_strb		: in std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);

		-- bridge target signals
		dev_addr		: out std_logic_vector(SUBADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
		dev_r			: out std_logic_vector(N_OUTPUTS-1 downto 0);
		dev_r_data		: in std_logic_vector((2**DATA_WIDTH_BITS)*N_OUTPUTS-1 downto 0);
		dev_w			: out std_logic_vector(N_OUTPUTS-1 downto 0);
		dev_w_data		: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		dev_w_strb		: out std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0)
	);
end bridge_dispatcher;

architecture arch_imp of bridge_dispatcher is
	signal rdst			: integer range 0 to N_OUTPUTS-1;

begin
	host_r_data <= dev_r_data((2**DATA_WIDTH_BITS)*(rdst+1)-1 downto (2**DATA_WIDTH_BITS)*rdst);

	process(clk,resetn)
	begin
		if resetn = '0' then
			dev_addr <= (others => '1');
			rdst <= 0;
			dev_r <= (others => '0');
			dev_w_data <= (others => '0');
			dev_w_strb <= (others => '0');
			dev_w <= (others => '0');
		elsif rising_edge(clk) then
			dev_addr <= (others => '1');
			if host_r = '1' or host_w = '1' then
				dev_addr <= host_addr(SUBADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
			end if;
			dev_r <= (others => '0');
			if host_r = '1' then
				for i in 0 to N_OUTPUTS-1 loop
					if i = unsigned(host_addr(ADDR_WIDTH-1 downto SUBADDR_WIDTH)) then
						dev_r(i) <= '1';
						rdst <= i;
					end if;
				end loop;
			end if;
			dev_w_data <= (others => '0');
			dev_w_strb <= (others => '0');
			dev_w <= (others => '0');
			if host_w = '1' then
				dev_w_data <= host_w_data;
				dev_w_strb <= host_w_strb;
				for i in 0 to N_OUTPUTS-1 loop
					if i = unsigned(host_addr(ADDR_WIDTH-1 downto SUBADDR_WIDTH)) then
						dev_w(i) <= '1';
					end if;
				end loop;
			end if;
		end if;
	end process;

end arch_imp;
