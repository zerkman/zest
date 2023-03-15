-- floppy.vhd - floppy drive emulation (hardware part)
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

entity floppy_drive is
	port (
		clk			: in std_logic;
		clken		: in std_logic;
		resetn		: in std_logic;

		read_datan	: out std_logic;
		side0		: in std_logic;
		indexn		: out std_logic;
		drv0_select	: in std_logic;
		drv1_select	: in std_logic;
		motor_on	: in std_logic;
		direction	: in std_logic;
		step		: in std_logic;
		write_data	: in std_logic;
		write_gate	: in std_logic;
		track0n		: out std_logic;
		write_protn	: out std_logic;

		host_wp0	: in std_logic;
		host_wp1	: in std_logic;
		host_intr	: out std_logic;
		host_din	: out std_logic_vector(127 downto 0);
		host_dout	: in std_logic_vector(127 downto 0);
		host_r		: out std_logic;
		host_w		: out std_logic;
		host_drv	: out std_logic;
		host_addr	: out std_logic_vector(8 downto 0);
		host_track	: out std_logic_vector(7 downto 0)
	);
end floppy_drive;

architecture behavioral of floppy_drive is
	constant NBITS		: integer := 128;
	constant LOGNBITS	: integer := 7;
	constant LASTNB		: integer := 6250 mod (NBITS/8);
	signal ccnt			: unsigned(20 downto 0);
	signal track0		: unsigned(6 downto 0);
	signal track1		: unsigned(6 downto 0);
	signal data_sr		: std_logic_vector(NBITS-1 downto 0);
	signal nextdata		: std_logic_vector(NBITS-1 downto 0);
	signal wrq			: std_logic;
	signal step_ff		: std_logic;
	signal s_indexn		: std_logic;

begin

	indexn <= s_indexn when drv0_select = '0' or drv1_select = '0' else '1';
	read_datan <= (not data_sr(NBITS-1)) when drv0_select = '0' or drv1_select = '0' else '1';
	write_protn <= '0' when (drv0_select = '0' and host_wp0 = '1') or (drv1_select = '0' and host_wp1 = '1') else '1';
	track0n <= '0' when (drv0_select = '0' and track0 = 0) or (drv1_select = '0' and track1 = 0) else '1';

-- track position for the host
process(drv0_select,drv1_select,track0,track1,side0)
begin
	host_track <= (others => '1');
	if drv0_select = '0' then
		host_track <= std_logic_vector(track0) & not side0;
	elsif drv1_select = '0' then
		host_track <= std_logic_vector(track1) & not side0;
	end if;
end process;

-- next host data word
process(data_sr,write_data,write_gate)
begin
	if write_gate = '1' then
		nextdata <= data_sr(NBITS-2 downto 0) & write_data;
	else
		nextdata <= data_sr(NBITS-2 downto 0) & data_sr(NBITS-1);
	end if;
end process;

-- position
process(clk)
	variable wrq0 : std_logic;
begin
	if rising_edge(clk) then
		if resetn = '0' then
			ccnt <= (others => '0');
			track0 <= (others => '0');
			track1 <= (others => '0');
			data_sr <= (others => '0');
			wrq <= '0';
			step_ff <= '1';
			host_intr <= '0';
			host_din <= (others => '0');
			host_r <= '0';
			host_w <= '0';
			host_drv <= '0';
			host_addr <= (others => '0');
			s_indexn <= '0';
		elsif clken = '1' then
			if drv0_select = '0' then
				step_ff <= step;
				if step = '1' and step_ff = '0' then
					if direction = '1' and track0 < 83 then
						track0 <= track0 + 1;
					elsif direction = '0' and track0 > 0 then
						track0 <= track0 - 1;
					end if;
				end if;
			elsif drv1_select = '0' then
				step_ff <= step;
				if step = '1' and step_ff = '0' then
					if direction = '1' and track1 < 83 then
						track1 <= track1 + 1;
					elsif direction = '0' and track1 > 0 then
						track1 <= track1 - 1;
					end if;
				end if;
			else
				host_r <= '0';
				host_w <= '0';
				step_ff <= '0';
			end if;
			if motor_on = '1' then
				if ccnt < 1599999 then
					ccnt <= ccnt + 1;
					if ccnt = 176-1 then	-- minimun 160 = 20 us
						s_indexn <= '1';
					end if;
				else
					ccnt <= (others => '0');
					s_indexn <= '0';
				end if;
				if ccnt(4 downto 0) = "11111" then
					-- new data bit
					wrq0 := wrq;
					if write_gate = '1' and (drv0_select = '0' or drv1_select = '0') then
						wrq <= '1';
						wrq0 := '1';
					end if;
					data_sr <= nextdata;
					if ccnt(LOGNBITS+4 downto 5) = (LOGNBITS-1 downto 0 => '1') or ccnt = 1599999 then
						-- shift register is full (write) or empty (read)
						if ccnt = 1599999 then
							host_addr <= (others => '0');
							for i in 0 to LASTNB-1 loop
								host_din(i*8+7 downto i*8) <= nextdata(((LASTNB-1)-i)*8+7 downto ((LASTNB-1)-i)*8);
							end loop;
							host_din(NBITS-1 downto LASTNB*8) <= (others => '0');
						else
							host_addr <= std_logic_vector(ccnt(20 downto LOGNBITS+5)+1);
							for i in 0 to NBITS/8-1 loop
								host_din(i*8+7 downto i*8) <= nextdata(((NBITS/8-1)-i)*8+7 downto ((NBITS/8-1)-i)*8);
							end loop;
						end if;
						host_w <= wrq0;
						host_r <= '1';
						host_drv <= drv0_select;
						host_intr <= '1';
						for i in 0 to NBITS/8-1 loop
							data_sr(i*8+7 downto i*8) <= host_dout(((NBITS/8-1)-i)*8+7 downto ((NBITS/8-1)-i)*8);
						end loop;
						wrq <= '0';
					elsif ccnt(LOGNBITS+4 downto 5) = (LOGNBITS-1 => '0', LOGNBITS-2 downto 0 => '1') then
						host_intr <= '0';
					end if;
				end if;
			else
				s_indexn <= '1';
			end if;
		end if;
	end if;
end process;


end behavioral;
