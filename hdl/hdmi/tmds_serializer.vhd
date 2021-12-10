-- tmds_serializer.vhd - serializer for DVI/HDMI output (Xilinx 7 series)
--
-- Copyright (c) 2021 Francois Galea <fgalea at free.fr>
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
library unisim;
use unisim.vcomponents.all;

entity tmds_serializer is
	port (
		clk    : in std_logic;
		sclk   : in std_logic;		-- serial clock; frequency = 5 times clk
		reset  : in std_logic;
		tmds_d : in std_logic_vector(9 downto 0);
		tx_d_n : out std_logic;
		tx_d_p : out std_logic
	);
end tmds_serializer;

architecture rtl of tmds_serializer is
	signal tx_d     : std_logic;
	signal shiftin1 : std_logic;
	signal shiftin2 : std_logic;
begin

	buf: OBUFDS
	generic map (
		IOSTANDARD => "DEFAULT", -- Specify the output I/O standard
		SLEW => "SLOW")          -- Specify the output slew rate
	port map (
		O => tx_d_p,  -- Diff_p output (connect directly to top-level port)
		OB => tx_d_n, -- Diff_n output (connect directly to top-level port)
		I => tx_d     -- Buffer input
	);

	ser_master: OSERDESE2
	generic map (
		DATA_RATE_OQ => "DDR",   -- DDR, SDR
		DATA_RATE_TQ => "SDR",   -- DDR, BUF, SDR
		DATA_WIDTH => 10,        -- Parallel data width (2-8,10,14)
		INIT_OQ => '0',          -- Initial value of OQ output (1'b0,1'b1)
		INIT_TQ => '0',          -- Initial value of TQ output (1'b0,1'b1)
		SERDES_MODE => "MASTER", -- MASTER, SLAVE
		SRVAL_OQ => '0',         -- OQ output value when SR is used (1'b0,1'b1)
		SRVAL_TQ => '0',         -- TQ output value when SR is used (1'b0,1'b1)
		TBYTE_CTL => "FALSE",    -- Enable tristate byte operation (FALSE, TRUE)
		TBYTE_SRC => "FALSE",    -- Tristate byte source (FALSE, TRUE)
		TRISTATE_WIDTH => 1      -- 3-state converter width (1,4)
	)
	port map (
		OFB => open,            -- 1-bit output: Feedback path for data
		OQ => tx_d,             -- 1-bit output: Data path output
		-- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
		SHIFTOUT1 => open,
		SHIFTOUT2 => open,
		TBYTEOUT => open,       -- 1-bit output: Byte group tristate
		TFB => open,            -- 1-bit output: 3-state control
		TQ => open,             -- 1-bit output: 3-state control
		CLK => sclk,            -- 1-bit input: High speed clock
		CLKDIV => clk,          -- 1-bit input: Divided clock
		-- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
		D1 => tmds_d(0),
		D2 => tmds_d(1),
		D3 => tmds_d(2),
		D4 => tmds_d(3),
		D5 => tmds_d(4),
		D6 => tmds_d(5),
		D7 => tmds_d(6),
		D8 => tmds_d(7),
		OCE => '1',             -- 1-bit input: Output data clock enable
		RST => reset,           -- 1-bit input: Reset
		-- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
		SHIFTIN1 => shiftin1,
		SHIFTIN2 => shiftin2,
		-- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
		T1 => '0',
		T2 => '0',
		T3 => '0',
		T4 => '0',
		TBYTEIN => '0',         -- 1-bit input: Byte group tristate
		TCE => '0'              -- 1-bit input: 3-state clock enable
	);

	ser_slave: OSERDESE2
	generic map (
		DATA_RATE_OQ => "DDR",   -- DDR, SDR
		DATA_RATE_TQ => "SDR",   -- DDR, BUF, SDR
		DATA_WIDTH => 10,        -- Parallel data width (2-8,10,14)
		INIT_OQ => '0',          -- Initial value of OQ output (1'b0,1'b1)
		INIT_TQ => '0',          -- Initial value of TQ output (1'b0,1'b1)
		SERDES_MODE => "SLAVE",  -- MASTER, SLAVE
		SRVAL_OQ => '0',         -- OQ output value when SR is used (1'b0,1'b1)
		SRVAL_TQ => '0',         -- TQ output value when SR is used (1'b0,1'b1)
		TBYTE_CTL => "FALSE",    -- Enable tristate byte operation (FALSE, TRUE)
		TBYTE_SRC => "FALSE",    -- Tristate byte source (FALSE, TRUE)
		TRISTATE_WIDTH => 1      -- 3-state converter width (1,4)
	)
	port map (
		OFB => open,            -- 1-bit output: Feedback path for data
		OQ => open,             -- 1-bit output: Data path output
		-- SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
		SHIFTOUT1 => shiftin1,
		SHIFTOUT2 => shiftin2,
		TBYTEOUT => open,       -- 1-bit output: Byte group tristate
		TFB => open,            -- 1-bit output: 3-state control
		TQ => open,             -- 1-bit output: 3-state control
		CLK => sclk,            -- 1-bit input: High speed clock
		CLKDIV => clk,          -- 1-bit input: Divided clock
		-- D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
		D1 => '0',
		D2 => '0',
		D3 => tmds_d(8),
		D4 => tmds_d(9),
		D5 => '0',
		D6 => '0',
		D7 => '0',
		D8 => '0',
		OCE => '1',             -- 1-bit input: Output data clock enable
		RST => reset,           -- 1-bit input: Reset
		-- SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
		SHIFTIN1 => '0',
		SHIFTIN2 => '0',
		-- T1 - T4: 1-bit (each) input: Parallel 3-state inputs
		T1 => '0',
		T2 => '0',
		T3 => '0',
		T4 => '0',
		TBYTEIN => '0',         -- 1-bit input: Byte group tristate
		TCE => '0'              -- 1-bit input: 3-state clock enable
	);

end architecture;
