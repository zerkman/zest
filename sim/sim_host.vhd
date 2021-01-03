-- sim_host.vhd - Simulation of host for Floppy emulator
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

entity sim_host is
	port (
		clk			: in std_logic;
		clken		: in std_logic;
		resetn		: in std_logic;

		intr		: in std_logic;
		din			: in std_logic_vector(31 downto 0);
		dout		: out std_logic_vector(31 downto 0);
		r			: in std_logic;
		w			: in std_logic;
		addr		: in std_logic_vector(10 downto 0);
		track		: in std_logic_vector(7 downto 0)
	);

end sim_host;

architecture behavioral of sim_host is
	signal intr_ff	: std_logic;
	constant TRACKS		: integer := 80;
	constant SIDES		: integer := 1;
	type buf_type is array (0 to 6250*TRACKS*SIDES-1) of std_logic_vector(7 downto 0);

	impure function init_buf(file_name : in string) return buf_type is
		use std.textio.all;
		type char_file_t is file of character;
		file bin_file : char_file_t;
		variable mem : buf_type;
		variable c : character;
	begin
		file_open(bin_file,file_name,READ_MODE);
		for i in buf_type'range loop
			read(bin_file,c);
			mem(i) := std_logic_vector(to_unsigned(character'pos(c),8));
		end loop;
		file_close(bin_file);
		return mem;
	end function;

	signal buf			: buf_type := init_buf("floppy.mfm");

	signal do			: std_logic_vector(31 downto 0);
	signal di			: std_logic_vector(31 downto 0);
	signal trkaddr		: unsigned(19 downto 0);
	signal pos			: unsigned(12 downto 0);
	signal pos1			: unsigned(12 downto 0);
	signal pos2			: unsigned(12 downto 0);
	signal posw			: unsigned(12 downto 0);
	signal rcnt			: unsigned(2 downto 0) := (others => '0');
	signal wcnt			: unsigned(2 downto 0) := (others => '0');

begin
	dout <= do;

	process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				do <= (others => '0');
			elsif clken = '1' then
				intr_ff <= intr;
				if intr = '1' and intr_ff = '0' then
					if r = '1' then
						trkaddr <= unsigned(track(7 downto 1))*to_unsigned(6250,13);
						if unsigned(std_logic_vector'(addr&"00"))+4 >= 6250 then
							pos <= unsigned(std_logic_vector'(addr&"00"))+4-6250;
						else
							pos <= unsigned(std_logic_vector'(addr&"00"))+4;
						end if;
						pos1 <= pos;
						pos2 <= pos1;
						posw <= pos2;
						rcnt <= "100";
						if w = '1' then
							di <= din;
							wcnt <= "100";
						end if;
					end if;
				end if;
				if rcnt > 0 then
					do <= do(23 downto 0) & buf(to_integer(trkaddr+pos));
					if pos+1 = 6250 then
						pos <= (others => '0');
					else
						pos <= pos + 1;
					end if;
					rcnt <= rcnt - 1;
				end if;
				if wcnt > 0 then
					buf(to_integer(trkaddr+posw)) <= di(31 downto 24);
					di <= di(23 downto 0) & x"00";
					if posw+1 = 6250 then
						wcnt <= "000";
					else
						posw <= posw + 1;
						wcnt <= wcnt - 1;
					end if;
				end if;
			end if;
		end if;
	end process;

end architecture;
