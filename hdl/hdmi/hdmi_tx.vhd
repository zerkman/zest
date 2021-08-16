-- hdmi_tx.vhd - HDMI transmitter
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

entity hdmi_tx is
	port (
		clk      : in std_logic;	-- pixel clock
		sclk     : in std_logic;	-- serial clock = 5x clk frequency
		reset    : in std_logic;
		rgb      : in std_logic_vector(23 downto 0);	-- pixel data
		vsync    : in std_logic;
		hsync    : in std_logic;
		de       : in std_logic;

		tx_clk_n : out std_logic;	-- TMDS clock channel
		tx_clk_p : out std_logic;
		tx_d_n   : out std_logic_vector(2 downto 0);	-- TMDS data channels
		tx_d_p   : out std_logic_vector(2 downto 0)		-- 0:red, 1:green, 2:blue
	);
end hdmi_tx;


architecture rtl of hdmi_tx is
	component tmds_encoder is
		port (
			clk    : in std_logic;
			reset  : in std_logic;
			data   : in std_logic_vector(7 downto 0);
			de     : in std_logic;		-- display enable
			ae     : in std_logic;		-- auxiliary channel enable
			tmds_d : out std_logic_vector(9 downto 0)
		);
	end component;

	component tmds_serializer is
		port (
			clk    : in std_logic;
			sclk   : in std_logic;		-- serial clock; frequency = 5 times clk
			reset  : in std_logic;
			tmds_d : in std_logic_vector(9 downto 0);
			tx_d_n : out std_logic;
			tx_d_p : out std_logic
		);
	end component;

	component hdmi_sig is
		port (
			clk   : in std_logic;
			reset : in std_logic;
			rgb   : in std_logic_vector(23 downto 0);
			vsync : in std_logic;
			hsync : in std_logic;
			ide   : in std_logic;

			data  : out std_logic_vector(23 downto 0);
			de    : out std_logic;		-- display enable
			ae    : out std_logic;		-- aux enable
			vgb   : out std_logic;		-- video leading guard band
			dgb   : out std_logic		-- data island leading or trailing guard band
		);
	end component;

	signal tmds_clk : std_logic_vector(9 downto 0);
	type tmds_d_t is array(0 to 2) of std_logic_vector(9 downto 0);
	signal tmds_d : tmds_d_t;
	signal serial_i : tmds_d_t;

	signal data : std_logic_vector(23 downto 0);
	signal sde  : std_logic;
	signal sae  : std_logic;
	signal vgb  : std_logic;
	signal dgb  : std_logic;
	signal vgb1 : std_logic;
	signal dgb1 : std_logic;

begin

	process(clk)
	begin
		if rising_edge(clk) then
			-- one cycle delay to keep in sync wrt tmds_encoder latency
			vgb1 <= vgb;
			dgb1 <= dgb;
		end if;
	end process;

	process(tmds_d,vgb1,dgb1)
	begin
		serial_i <= tmds_d;
		if vgb1 = '1' then
			-- video guard band
			serial_i(0) <= "1011001100";
			serial_i(1) <= "0100110011";
			serial_i(2) <= "1011001100";
		elsif dgb1 = '1' then
			-- data island guard band
			serial_i(1) <= "0100110011";
			serial_i(2) <= "0100110011";
		end if;
	end process;

	signaller: hdmi_sig port map (
		clk => clk,
		reset => reset,
		rgb => rgb,
		vsync => vsync,
		hsync => hsync,
		ide => de,
		data => data,
		de => sde,
		ae => sae,
		vgb => vgb,
		dgb => dgb
	);

	-- send the clock through a serializer to keep in sync with the channels
	serial_clk : tmds_serializer port map (
		clk => clk,
		sclk => sclk,
		reset => reset,
		tmds_d => "1111100000",
		tx_d_n => tx_clk_n,
		tx_d_p => tx_clk_p
	);

	chn: for i in 0 to 2 generate
		encoder: tmds_encoder port map (
			clk => clk,
			reset => reset,
			data => data(i*8+7 downto i*8),
			de => sde,
			ae => sae,
			tmds_d => tmds_d(i)
		);

		serial: tmds_serializer port map (
			clk => clk,
			sclk => sclk,
			reset => reset,
			tmds_d => serial_i(i),
			tx_d_n => tx_d_n(i),
			tx_d_p => tx_d_p(i)
		);
	end generate chn;

end architecture;
