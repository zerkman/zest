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
	generic (
		SAMPLE_FREQ : integer := 48000
	);
	port (
		clk      : in std_logic;	-- pixel clock
		sclk     : in std_logic;	-- serial clock = 5x clk frequency
		reset    : in std_logic;
		rgb      : in std_logic_vector(23 downto 0);	-- pixel data
		vsync    : in std_logic;
		hsync    : in std_logic;
		de       : in std_logic;

		audio_en     : in std_logic;		-- audio enable
		audio_l      : in std_logic_vector(23 downto 0);	-- left channel
		audio_r      : in std_logic_vector(23 downto 0);	-- right channel
		audio_clk    : in std_logic;		-- sample clock

		tx_clk_n : out std_logic;	-- TMDS clock channel
		tx_clk_p : out std_logic;
		tx_d_n   : out std_logic_vector(2 downto 0);	-- TMDS data channels
		tx_d_p   : out std_logic_vector(2 downto 0)		-- 0:blue, 1:green, 2:red
	);
end hdmi_tx;


architecture rtl of hdmi_tx is
	component tmds_encoder is
		generic (
			CHN    : integer := 0		-- TMDS channel number 0:blue, 1:green, 2:red
		);
		port (
			clk    : in std_logic;
			reset  : in std_logic;
			data   : in std_logic_vector(7 downto 0);
			de     : in std_logic;		-- display enable
			ae     : in std_logic;		-- auxiliary channel enable
			vgb    : in std_logic;		-- video leading guard band
			dgb    : in std_logic;		-- data island leading or trailing guard band
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
		generic (
			SAMPLE_FREQ : integer := 48000
		);
		port (
			clk   : in std_logic;
			reset : in std_logic;
			rgb   : in std_logic_vector(23 downto 0);
			vsync : in std_logic;
			hsync : in std_logic;
			ide   : in std_logic;

			audio_en     : in std_logic;		-- audio enable
			audio_l      : in std_logic_vector(23 downto 0);	-- left channel
			audio_r      : in std_logic_vector(23 downto 0);	-- right channel
			audio_clk    : in std_logic;		-- sample clock

			data  : out std_logic_vector(23 downto 0);
			de    : out std_logic;		-- display enable
			ae    : out std_logic;		-- aux enable
			vgb   : out std_logic;		-- video leading guard band
			dgb   : out std_logic		-- data island leading or trailing guard band
		);
	end component;

	type tmds_d_t is array(0 to 2) of std_logic_vector(9 downto 0);
	signal tmds_d : tmds_d_t;

	signal data : std_logic_vector(23 downto 0);
	signal sde  : std_logic;
	signal sae  : std_logic;
	signal vgb  : std_logic;
	signal dgb  : std_logic;

begin

	signaller: hdmi_sig generic map (
			SAMPLE_FREQ => SAMPLE_FREQ
		)
		port map (
			clk => clk,
			reset => reset,
			rgb => rgb,
			vsync => vsync,
			hsync => hsync,
			ide => de,
			audio_en => audio_en,
			audio_l => audio_l,
			audio_r => audio_r,
			audio_clk => audio_clk,
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
		encoder: tmds_encoder generic map (
			CHN => i
		) port map (
			clk => clk,
			reset => reset,
			data => data(i*8+7 downto i*8),
			de => sde,
			ae => sae,
			vgb => vgb,
			dgb => dgb,
			tmds_d => tmds_d(i)
		);

		serial: tmds_serializer port map (
			clk => clk,
			sclk => sclk,
			reset => reset,
			tmds_d => tmds_d(i),
			tx_d_n => tx_d_n(i),
			tx_d_p => tx_d_p(i)
		);
	end generate chn;

end architecture;
