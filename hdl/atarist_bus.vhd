-- atarist_bus.vhd - Atari ST bus
--
-- Copyright (c) 2021-2023 Francois Galea <fgalea at free.fr>
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

entity atarist_bus is
	port (
		cpu_d		: in std_logic_vector(15 downto 0);
		cpu_e		: in std_logic;
		shifter_d	: in std_logic_vector(15 downto 0);
		ram_d		: in std_logic_vector(15 downto 0);
		ram_e		: in std_logic;
		ram_latch	: in std_logic;
		mfp_d		: in std_logic_vector(7 downto 0);
		mmu_d		: in std_logic_vector(7 downto 0);
		glue_d		: in std_logic_vector(1 downto 0);
		acia_ikbd_d	: in std_logic_vector(7 downto 0);
		acia_ikbd_e	: in std_logic;
		acia_midi_d	: in std_logic_vector(7 downto 0);
		acia_midi_e	: in std_logic;
		dma_d		: in std_logic_vector(15 downto 0);
		psg_d		: in std_logic_vector(7 downto 0);
		psg_e		: in std_logic;

		d			: out std_logic_vector(15 downto 0)
	);
end atarist_bus;

architecture rtl of atarist_bus is
	signal ram_ds	: std_logic_vector(15 downto 0);
begin

	process(ram_latch,ram_d)
	begin
		if ram_latch = '0' then
			ram_ds <= ram_d;
		end if;
	end process;

d <= (cpu_d or (15 downto 0 => cpu_e)) and shifter_d
		and (ram_ds or (15 downto 0 => ram_e or not cpu_e))
		and (x"ff" & (mmu_d and mfp_d)) and ("111111" & glue_d & x"ff")
		and ((acia_ikbd_d or (7 downto 0 => acia_ikbd_e nand cpu_e)) & x"ff")
		and ((acia_midi_d or (7 downto 0 => acia_midi_e nand cpu_e)) & x"ff")
		and ((psg_d or (7 downto 0 => psg_e)) & x"ff")
		and dma_d;

end architecture;
