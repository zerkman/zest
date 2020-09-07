-- zest_sim_top.vhd - Top level for zeST simulation
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

entity zest_sim_top is
end zest_sim_top;


architecture dut of zest_sim_top is

	component atarist_main is
		port (
			clk : in std_logic;
			resetn : in std_logic;

			clken_error : out std_logic;

			clken : out std_logic;
			de : out std_logic;
			hsync : out std_logic;
			vsync : out std_logic;
			rgb : out std_logic_vector(8 downto 0);
			monomon : in std_logic;

			a : out std_logic_vector(23 downto 1);
			ds : out std_logic_vector(1 downto 0);
			r : out std_logic;
			r_done : in std_logic;
			w : out std_logic;
			w_done : in std_logic;
			od : in std_logic_vector(15 downto 0);
			id : out std_logic_vector(15 downto 0)
		);
	end component;

	component simple_ram is
		generic (
			MEM_SIZE	: integer	:= 32768
		);
		port (
			clk		: in std_logic;
			resetn	: in std_logic;

			-- address
			A		: in std_logic_vector(23 downto 1);
			-- input data
			iD		: in std_logic_vector(15 downto 0);
			-- output data
			oD		: out std_logic_vector(15 downto 0);
			-- initiate write transaction
			W		: in std_logic;
			-- initiate read transaction
			R		: in std_logic;
			-- data strobe (for each byte of the data bus)
			DS		: in std_logic_vector(1 downto 0);

			-- Write done signal
			W_DONE	: out std_logic;
			-- Read done signal
			R_DONE	: out std_logic
		);
	end component;

	signal clk			: std_logic := '0';
	signal resetn		: std_logic;

	signal clken_err	: std_logic;
	signal rgb 			: std_logic_vector(8 downto 0);
	signal monomon		: std_logic := '0';

	signal ram_A		: std_logic_vector(23 downto 1);
	signal ram_iD		: std_logic_vector(15 downto 0);
	signal ram_oD		: std_logic_vector(15 downto 0);
	signal ram_W		: std_logic;
	signal ram_R		: std_logic;
	signal ram_DS		: std_logic_vector(1 downto 0);
	signal ram_W_DONE	: std_logic;
	signal ram_R_DONE	: std_logic;
	signal ram_offset	: std_logic_vector(31 downto 0);
	signal ram_offvald	: std_logic;
	signal ram_error	: std_logic;

	signal pclken		: std_logic;
	signal de			: std_logic;
	signal vsync		: std_logic;
	signal hsync		: std_logic;

begin
	atarist:atarist_main port map(
		clk => clk,
		resetn => resetn,
		clken_error => clken_err,
		clken => pclken,
		de => de,
		hsync => hsync,
		vsync => vsync,
		rgb => rgb,
		monomon => monomon,
		a => ram_A,
		ds => ram_DS,
		r => ram_R,
		r_done => ram_R_DONE,
		w => ram_W,
		w_done => ram_W_DONE,
		od => ram_oD,
		id => ram_iD
	);

	ram:simple_ram port map(
		clk => clk,
		resetn => resetn,
		A => ram_A,
		iD => ram_iD,
		oD => ram_oD,
		W => ram_W,
		R => ram_R,
		DS => ram_DS,
		W_DONE => ram_W_DONE,
		R_DONE => ram_R_DONE
	);

	clk <= not clk after 5 ns;		-- 100 MHz
	resetn <= '0', '1' after 442 ns;
	monomon <= not monomon after 100 us;

end dut;
