-- vclkconvert.vhd - Convertor for a clock-enabled video signal to a steady pixel clock
--
-- Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
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

entity vclkconvert is
	port (
		clk     : in std_logic;
		clken	: in std_logic;
		pclk    : in std_logic;
		resetn	: in std_logic;

		ivsync  : in std_logic;
		ihsync  : in std_logic;
		ide     : in std_logic;
		ipix    : in std_logic_vector(15 downto 0);

		ovsync  : out std_logic;
		ohsync  : out std_logic;
		ode     : out std_logic;
		opix    : out std_logic_vector(15 downto 0)
	);
end vclkconvert;

architecture behavioral of vclkconvert is
	component aFifo is
		generic (
			DATA_WIDTH :integer := 8;
			ADDR_WIDTH :integer := 4
		);
		port (
			-- Reading port.
			Data_out    :out std_logic_vector (DATA_WIDTH-1 downto 0);
			Empty_out   :out std_logic;
			ReadEn_in   :in  std_logic;
			RClk        :in  std_logic;
			-- Writing port.
			Data_in     :in  std_logic_vector (DATA_WIDTH-1 downto 0);
			Full_out    :out std_logic;
			WriteEn_in  :in  std_logic;
			WClk        :in  std_logic;

			Clear_in	:in  std_logic
		);
	end component;

	signal idata : std_logic_vector(18 downto 0);
	signal odata : std_logic_vector(18 downto 0);
	signal ifull : std_logic;
	signal oempty : std_logic;
	signal readen : std_logic;
	signal writeen : std_logic;
	signal clear : std_logic;

begin
	idata <= ivsync & ihsync & ide & ipix;
	ovsync <= odata(18);
	ohsync <= odata(17);
	ode <= odata(16);
	opix <= odata(15 downto 0);

	fifo:aFifo
	generic map (DATA_WIDTH => 19, ADDR_WIDTH => 8)
	port map (
		Data_out => odata,
		Empty_out => oempty,
		ReadEn_in => readen,
		RClk => pclk,
		Data_in => idata,
		Full_out => ifull,
		WriteEn_in => writeen,
		WClk => clk,
		Clear_in => clear
	);

	process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				clear <= '1';
				writeen <= '0';
			else
				clear <= '0';
				writeen <= '0';
				if clken = '1' and ifull = '0' then
					writeen <= '1';
				end if;
			end if;
		end if;
	end process;

	process(pclk)
	begin
		if rising_edge(pclk) then
			if resetn = '0' then
				readen <= '0';
			else
				readen <= '0';
				if oempty = '0' then
					readen <= '1';
				end if;
			end if;
		end if;
	end process;


end behavioral;
