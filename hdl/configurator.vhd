-- configurator.vhd - Bank of memory-mapped configuration registers
--
-- Copyright (c) 2020-2025 Francois Galea <fgalea at free.fr>
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
		ADDR_WIDTH		: integer := 6;		-- Width of address bus
		N_REGISTERS		: integer := 12		-- number of registers
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

		fdd_ack		: out std_logic;

		-- ACIA signals for MIDI
		midi_cs		: in std_logic;
		midi_addr	: in std_logic;
		midi_rw		: in std_logic;
		midi_id		: in std_logic_vector(7 downto 0);
		midi_od		: out std_logic_vector(7 downto 0);
		midi_irq	: out std_logic;

		host_intr	: out std_logic;

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
	type out_reg_t is array (0 to N_REGISTERS-1) of std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal out_reg : out_reg_t;

	-- Input register array
	type in_reg_t is array (0 to N_REGISTERS-1) of std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal in_reg : in_reg_t;

	signal b_addr : integer range 0 to 12;

	-- midi signals
	signal midi_txd			: std_logic_vector(7 downto 0);
	signal midi_txd_full	: std_logic;
	signal midi_tx_intr_en	: std_logic;
	signal midi_rxd			: std_logic_vector(7 downto 0);
	signal midi_rxd_full	: std_logic;
	signal midi_rxd_full0	: std_logic;
	signal midi_rx_intr_en	: std_logic;
	signal midi_irq_r		: std_logic;
	signal midi_cs1			: std_logic;

	signal midi_host_intr	: std_logic;

begin
	b_addr <= to_integer(unsigned(bridge_addr));
	host_intr <= midi_host_intr and not midi_cs;
	midi_irq <= midi_irq_r;

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

	process(clk,resetn)
	begin
		if resetn = '0' then
			midi_txd_full <= '0';
			midi_rxd_full <= '0';
			midi_irq_r <= '0';
			midi_tx_intr_en <= '0';
			midi_rx_intr_en <= '0';
			midi_host_intr <= '0';
			midi_cs1 <= '0';
			midi_od <= x"ff";
		elsif rising_edge(clk) then
			fdd_ack <= '0';
			-- bridge bus
			if bridge_w = '1' then
				if b_addr < N_REGISTERS then
					-- out registers
					out_reg(b_addr) <= bridge_w_data;
				elsif b_addr = 12 then
					-- MIDI host access
					midi_rxd <= bridge_w_data(7 downto 0);
					midi_rxd_full <= '1';
					if midi_rxd_full = '0' and midi_rx_intr_en = '1' then
						midi_irq_r <= '1';
					end if;
				end if;
			end if;
			if bridge_r = '1' then
				if b_addr < N_REGISTERS then
					bridge_r_data <= in_reg(b_addr);
					if b_addr = 0 then
						fdd_ack <= '1';
					end if;
				elsif b_addr = 12 then
					-- MIDI host access
					bridge_r_data <= (31 downto 10 => '0') & midi_txd_full & midi_rxd_full & midi_txd;
					if midi_txd_full = '1' and midi_tx_intr_en = '1' then
						midi_irq_r <= '1';
					end if;
					midi_txd_full <= '0';
					midi_host_intr <= '0';
				end if;
			end if;

			-- MIDI ACIA interface
			midi_cs1 <= midi_cs;
			if midi_cs = '1' and midi_cs1 = '0' then
				midi_rxd_full0 <= midi_rxd_full;
				if midi_rw = '1' then
					-- read from MIDI port
					if midi_addr = '0' then
						-- status reg
						midi_od <= midi_irq_r & "00000" & not midi_txd_full & midi_rxd_full;
					else
						-- data reg
						midi_od <= midi_rxd;
						midi_rxd_full0 <= '0';
						midi_irq_r <= '0';
						midi_host_intr <= '1';
					end if;
				else
					-- write to MIDI port
					if midi_addr = '0' then
						-- control reg
						midi_rx_intr_en <= midi_id(7);
						midi_tx_intr_en <= midi_id(5) and not midi_id(6);
						if midi_id(1 downto 0) = "11" then
							-- reset: clear state
							midi_txd_full <= '0';
							midi_rxd_full0 <= '0';
							midi_irq_r <= '0';
						end if;
					else
						-- data reg
						if midi_txd_full = '0' then
							midi_txd <= midi_id;
							midi_txd_full <= '1';
							midi_host_intr <= '1';
						end if;
						midi_irq_r <= '0';
					end if;
				end if;
			end if;
			if midi_cs = '0' and midi_cs1 = '1' then
				midi_rxd_full <= midi_rxd_full0;
				midi_od <= x"ff";
			end if;
		end if;
	end process;

end arch_imp;
