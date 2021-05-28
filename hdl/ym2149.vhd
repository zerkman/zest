-- ym2149.vhd - Software-controlled sound generator
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

entity ym2149 is
	port (
		clk		: in std_logic;
		aclken	: in std_logic;
		resetn	: in std_logic;
		bdir	: in std_logic;
		bc1		: in std_logic;
		bc2		: in std_logic;
		ida		: in std_logic_vector(7 downto 0);
		oda		: out std_logic_vector(7 downto 0);
		ia		: in std_logic_vector(7 downto 0);
		oa		: out std_logic_vector(7 downto 0);
		ib		: in std_logic_vector(7 downto 0);
		ob		: out std_logic_vector(7 downto 0);
		a		: out std_logic_vector(15 downto 0);
		b		: out std_logic_vector(15 downto 0);
		c		: out std_logic_vector(15 downto 0)
	);
end ym2149;

architecture rtl of ym2149 is
	type channel_t is record
		period	: unsigned(11 downto 0);
		noise	: std_logic;
		tone	: std_logic;
		mode	: std_logic;
		level	: std_logic_vector(3 downto 0);
		pos		: unsigned(11 downto 0);
		value	: std_logic_vector(15 downto 0);
	end record;
	type channels_t is array (0 to 2) of channel_t;

	type port_t is record
		ino		: std_logic;	-- 0: input, 1: output
		idata	: std_logic_vector(7 downto 0);
		odata	: std_logic_vector(7 downto 0);
	end record;
	type ports_t is array (0 to 1) of port_t;

	signal chan			: channels_t;
	signal ports		: ports_t;
	signal noise_period	: unsigned(4 downto 0);
	signal envel_period	: unsigned(15 downto 0);
	signal envel_shape	: std_logic_vector(3 downto 0);

	procedure chan_reset (signal ch : inout channel_t) is
	begin
		ch.period <= (others => '0');
		ch.noise <= '0';
		ch.tone <= '0';
		ch.mode <= '0';
		ch.level <= (others => '0');
		ch.pos <= (others => '0');
		ch.value <= (others => '0');
	end procedure;

	procedure port_reset (signal pt : inout port_t) is
	begin
		pt.ino <= '0';
		pt.odata <= (others => '0');
	end procedure;

	signal address		: std_logic_vector(3 downto 0);
	signal bus_address	: std_logic;
	signal bus_read		: std_logic;
	signal bus_write	: std_logic;

begin
	a <= chan(0).value;
	b <= chan(1).value;
	c <= chan(2).value;
	ports(0).idata <= ia;
	oa <= ports(0).odata;
	ports(1).idata <= ib;
	ob <= ports(1).odata;

	-- bus modes
	process(bdir,bc1,bc2)
		variable bb : std_logic_vector(2 downto 0);
	begin
		bb := (bdir, bc2, bc1);
		bus_address <= '0';
		bus_read <= '0';
		bus_write <= '0';
		if bb = "001" or bb = "100" or bb = "111" then
			bus_address <= '1';
		end if;
		if bb = "011" then
			bus_read <= '1';
		end if;
		if bb = "110" then
			bus_write <= '1';
		end if;
	end process;

	-- address register
	process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				address <= (others => '0');
			elsif bus_address = '1' then
				address <= ida(3 downto 0);
			end if;
		end if;
	end process;

	-- ports and channels registers
	process(clk)
	begin
		if rising_edge(clk) then
			oda <= (others => '1');
			if resetn = '0' then
				port_reset(ports(0));
				port_reset(ports(1));
				chan_reset(chan(0));
				chan_reset(chan(1));
				chan_reset(chan(2));
				noise_period <= (others => '0');
				envel_period <= (others => '0');
				envel_shape <= (others => '0');
			elsif bus_read = '1' then
				case address is
				when x"0" =>
					oda <= std_logic_vector(chan(0).period(7 downto 0));
				when x"1" =>
					oda <= "0000" & std_logic_vector(chan(0).period(11 downto 8));
				when x"2" =>
					oda <= std_logic_vector(chan(1).period(7 downto 0));
				when x"3" =>
					oda <= "0000" & std_logic_vector(chan(1).period(11 downto 8));
				when x"4" =>
					oda <= std_logic_vector(chan(2).period(7 downto 0));
				when x"5" =>
					oda <= "0000" & std_logic_vector(chan(2).period(11 downto 8));
				when x"6" =>
					oda <= "000" & std_logic_vector(noise_period);
				when x"7" =>
					oda <= ports(1).ino & ports(0).ino & chan(2).noise & chan(1).noise
						& chan(0).noise & chan(2).tone & chan(1).tone & chan(0).tone;
				when x"8" =>
					oda <= "000" & chan(0).mode & chan(0).level;
				when x"9" =>
					oda <= "000" & chan(1).mode & chan(1).level;
				when x"a" =>
					oda <= "000" & chan(2).mode & chan(2).level;
				when x"b" =>
					oda <= std_logic_vector(envel_period(7 downto 0));
				when x"c" =>
					oda <= std_logic_vector(envel_period(15 downto 8));
				when x"d" =>
					oda <= "0000" & envel_shape;
				when x"e" =>
					if ports(0).ino = '0' then
						oda <= ports(0).idata;
					else
						oda <= ports(0).odata;
					end if;
				when x"f" =>
					if ports(1).ino = '0' then
						oda <= ports(1).idata;
					else
						oda <= ports(1).odata;
					end if;
				when others =>
					null;
				end case;
			elsif bus_write = '1' then
				case address is
				when x"0" =>
					chan(0).period(7 downto 0) <= unsigned(ida);
				when x"1" =>
					chan(0).period(11 downto 8) <= unsigned(ida(3 downto 0));
				when x"2" =>
					chan(1).period(7 downto 0) <= unsigned(ida);
				when x"3" =>
					chan(1).period(11 downto 8) <= unsigned(ida(3 downto 0));
				when x"4" =>
					chan(2).period(7 downto 0) <= unsigned(ida);
				when x"5" =>
					chan(2).period(11 downto 8) <= unsigned(ida(3 downto 0));
				when x"6" =>
					noise_period <= unsigned(ida(4 downto 0));
				when x"7" =>
					ports(1).ino <= ida(7);
					ports(0).ino <= ida(6);
					chan(2).noise <= ida(5);
					chan(1).noise <= ida(4);
					chan(0).noise <= ida(3);
					chan(2).tone <= ida(2);
					chan(1).tone <= ida(1);
					chan(0).tone <= ida(0);
				when x"8" =>
					chan(0).mode <= ida(4);
					chan(0).level <= ida(3 downto 0);
				when x"9" =>
					chan(1).mode <= ida(4);
					chan(1).level <= ida(3 downto 0);
				when x"a" =>
					chan(2).mode <= ida(4);
					chan(2).level <= ida(3 downto 0);
				when x"b" =>
					envel_period(7 downto 0) <= unsigned(ida);
				when x"c" =>
					envel_period(15 downto 8) <= unsigned(ida);
				when x"d" =>
					envel_shape <= ida(3 downto 0);
				when x"e" =>
					ports(0).odata <= ida;
				when x"f" =>
					ports(1).odata <= ida;
				when others =>
					null;
				end case;
			end if;
		end if;
	end process;

end architecture;
