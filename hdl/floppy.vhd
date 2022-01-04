-- floppy.vhd - floppy drive emulation (hardware part)
--
-- Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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

entity floppy_drive is
	port (
		clk			: in std_logic;
		clken		: in std_logic;
		resetn		: in std_logic;

		read_datan	: out std_logic;
		side0		: in std_logic;
		indexn		: out std_logic;
		drv_select	: in std_logic;
		motor_on	: in std_logic;
		direction	: in std_logic;
		step		: in std_logic;
		write_data	: in std_logic;
		write_gate	: in std_logic;
		track0n		: out std_logic;
		write_protn	: out std_logic;

		host_intr	: out std_logic;
		host_din	: out std_logic_vector(31 downto 0);
		host_dout	: in std_logic_vector(31 downto 0);
		host_r		: out std_logic;
		host_w		: out std_logic;
		host_addr	: out std_logic_vector(10 downto 0);
		host_track	: out std_logic_vector(7 downto 0)
	);
end floppy_drive;

architecture behavioral of floppy_drive is
	signal ccnt		: unsigned(20 downto 0);
	signal track	: unsigned(6 downto 0);
	signal data_sr	: std_logic_vector(31 downto 0);
	signal nextdata	: std_logic_vector(31 downto 0);
	signal wrq		: std_logic;
	signal step_ff	: std_logic;
begin

	read_datan <= not data_sr(31);
	host_track <= std_logic_vector(track) & not side0;
	write_protn <= '1';

-- next host data word
process(data_sr,write_data,write_gate)
begin
	if write_gate = '1' then
		nextdata <= data_sr(30 downto 0) & write_data;
	else
		nextdata <= data_sr(30 downto 0) & data_sr(31);
	end if;
end process;

-- position
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			ccnt <= (others => '0');
			track <= (others => '0');
			data_sr <= (others => '0');
			wrq <= '0';
			step_ff <= '1';
			host_intr <= '0';
			host_din <= (others => '0');
			host_r <= '0';
			host_w <= '0';
			host_addr <= (others => '0');
			track0n <= '0';
			indexn <= '0';
		elsif clken = '1' then
			if drv_select = '0' then
				step_ff <= step;
				if step = '1' and step_ff = '0' then
					if direction = '1' and track < 83 then
						track <= track + 1;
						track0n <= '1';
					elsif direction = '0' and track > 0 then
						track <= track - 1;
						track0n <= '1';
						if track - 1 = 0 then
							track0n <= '0';
						end if;
					end if;
				end if;
				if motor_on = '1' then
					if ccnt < 1599999 then
						ccnt <= ccnt + 1;
						if ccnt = 176-1 then	-- minimun 160 = 20 us
							indexn <= '1';
						end if;
					else
						ccnt <= (others => '0');
						indexn <= '0';
					end if;
					if ccnt(4 downto 0) = "11111" then
						-- new data bit
						host_intr <= '0';
						if write_gate = '1' then
							wrq <= '1';
						end if;
						data_sr <= nextdata;
						if ccnt(9 downto 5) = "11111" or ccnt = 1599999 then
							-- shift register is full (write) or empty (read)
							if ccnt = 1599999 then
								host_addr <= (others => '0');
							else
								host_addr <= std_logic_vector(ccnt(20 downto 10)+1);
							end if;
							host_w <= wrq;
							host_r <= '1';
							host_din <= nextdata;
							host_intr <= '1';
							data_sr <= host_dout;
							wrq <= '0';
						end if;
					end if;
				end if;
			else
				host_r <= '0';
				host_w <= '0';
				step_ff <= '0';
			end if;
		end if;
	end if;
end process;


end behavioral;
