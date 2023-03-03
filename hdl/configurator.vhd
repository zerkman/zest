-- configurator.vhd - Bank of memory-mapped configuration registers
--
-- Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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

entity configurator is
	generic (
		DATA_WIDTH_BITS	: integer := 5;		-- log2(width of data bus)
		ADDR_WIDTH		: integer := 6		-- Width of address bus
	);
	port (
		clk			: in std_logic;
		resetn		: in std_logic;

		bridge_addr		: in std_logic_vector(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
		bridge_r		: in std_logic;
		bridge_r_data	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w		: in std_logic;
		bridge_w_data	: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w_strb	: in std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);

		out_reg0	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg1	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg2	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg3	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg4	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg5	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg6	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg7	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		out_reg8_11	: out std_logic_vector(2**DATA_WIDTH_BITS*4-1 downto 0);

		in_reg0		: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		in_reg1		: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		in_reg8_11  : in std_logic_vector(2**DATA_WIDTH_BITS*4-1 downto 0)
	);
end configurator;

architecture arch_imp of configurator is

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit 2**DATA_WIDTH_BITS
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB	: integer := DATA_WIDTH_BITS-3;
	-- address bits are in range (ADDR_MSB downto ADDR_LSB)
	constant ADDR_MSB	: integer := ADDR_WIDTH-1;

	-- register space
	type out_reg_t is array (0 to 2**(ADDR_MSB-ADDR_LSB+1)-1) of std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal out_reg : out_reg_t;

	-- Input register array
	type in_reg_t is array (0 to 2**(ADDR_MSB-ADDR_LSB+1)-1) of std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal in_reg : in_reg_t;

begin
	-- I/O Connections assignments
	out_reg0 <= out_reg(0);
	out_reg1 <= out_reg(1);
	out_reg2 <= out_reg(2);
	out_reg3 <= out_reg(3);
	out_reg4 <= out_reg(4);
	out_reg5 <= out_reg(5);
	out_reg6 <= out_reg(6);
	out_reg7 <= out_reg(7);
	out_reg8_11 <= out_reg(11) & out_reg(10) & out_reg(9) & out_reg(8);
	in_reg(0) <= in_reg0;
	in_reg(1) <= in_reg1;
	in_reg(2) <= out_reg(2);
	in_reg(3) <= out_reg(3);
	in_reg(4) <= out_reg(4);
	in_reg(5) <= out_reg(5);
	in_reg(6) <= out_reg(6);
	in_reg(7) <= out_reg(7);
	in_reg(8) <= in_reg8_11(31 downto 0);
	in_reg(9) <= in_reg8_11(63 downto 32);
	in_reg(10) <= in_reg8_11(95 downto 64);
	in_reg(11) <= in_reg8_11(127 downto 96);
	in_reg(12) <= out_reg(12);
	in_reg(13) <= out_reg(13);
	in_reg(14) <= out_reg(14);
	in_reg(15) <= out_reg(15);

	process(clk)
	begin
		if rising_edge(clk) then
			if bridge_w = '1' then
				out_reg(to_integer(unsigned(bridge_addr))) <= bridge_w_data;
			end if;
			if bridge_r = '1' then
				bridge_r_data <= in_reg(to_integer(unsigned(bridge_addr)));
			end if;
		end if;
	end process;

end arch_imp;
