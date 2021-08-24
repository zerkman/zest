-- hdmi_signaling.vhd - HDMI signal generator
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

entity hdmi_sig is
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
end hdmi_sig;

architecture rtl of hdmi_sig is

	component hdmi_packet_gen is
		port (
			clk    : in std_logic;
			reset  : in std_logic;

			if_tr  : in std_logic;		-- infoframe island trigger

			data   : out std_logic_vector(7 downto 0);		-- packet data
			dvalid : out std_logic;
			dready : in std_logic
		);
	end component;

	component hdmi_island_encoder is
		port (
			clk      : in std_logic;
			reset    : in std_logic;

			data     : in std_logic_vector(7 downto 0);
			dvalid   : in std_logic;
			dready   : out std_logic;

			busy     : out std_logic;
			preamble : out std_logic;
			guard    : out std_logic;
			packet   : out std_logic;
			aux0     : out std_logic;
			aux1     : out std_logic_vector(3 downto 0);
			aux2     : out std_logic_vector(3 downto 0)
		);
	end component;

	signal packet_data  : std_logic_vector(7 downto 0);
	signal packet_valid : std_logic;
	signal packet_ready : std_logic;

	-- shift register for input signals
	type sdelay_e_t is record
		data  : std_logic_vector(23 downto 0);
		de    : std_logic;
	end record;
	type sdelay_t is array (0 to 10) of sdelay_e_t;
	signal sdelay       : sdelay_t;

	-- signals for preamble and guard band generation
	signal pr_cnt       : unsigned(3 downto 0);
	signal old_de       : std_logic;

	-- signals to trigger the generation of the infoframe data island
	signal vsync0       : std_logic;
	signal info_ready   : std_logic;
	signal if_trig      : std_logic;

	signal packet0      : std_logic;	-- determines 1st char of data island packet

	-- data island encoder status
	signal enc_busy     : std_logic;
	signal enc_preamble : std_logic;
	signal enc_guard    : std_logic;
	signal enc_packet   : std_logic;
	-- BCH encoded auxiliary data
	signal aux0         : std_logic;
	signal aux1         : std_logic_vector(3 downto 0);
	signal aux2         : std_logic_vector(3 downto 0);

begin

	pkgen : hdmi_packet_gen port map (
		clk => clk,
		reset => reset,
		if_tr => if_trig,
		data => packet_data,
		dvalid => packet_valid,
		dready => packet_ready
	);

	isl_enc : hdmi_island_encoder port map (
		clk => clk,
		reset => reset,

		data => packet_data,
		dvalid => packet_valid,
		dready => packet_ready,

		busy => enc_busy,
		preamble => enc_preamble,
		guard => enc_guard,
		packet => enc_packet,
		aux0 => aux0,
		aux1 => aux1,
		aux2 => aux2
	);


process(clk)
	variable dly : sdelay_e_t;
begin
	if rising_edge(clk) then
		if reset = '1' then
			sdelay <= (others => ((others => '0'), '0'));
		else
			if ide = '1' then
				dly.data := rgb;
			else
				dly.data := x"03030" & "00" & vsync & hsync;
			end if;
			dly.de := ide;
			sdelay <= sdelay(1 to sdelay'high) & dly;
		end if;
	end if;
end process;

-- preamble counter management
process(clk)
begin
	if rising_edge(clk) then
		if reset = '1' then
			old_de <= '0';
			pr_cnt <= x"0";
		else
			old_de <= ide;
			if ide = '1' and old_de = '0' then
				pr_cnt <= x"a";
			elsif pr_cnt > 0 then
				pr_cnt <= pr_cnt - 1;
			end if;
		end if;
	end if;
end process;

process(clk)
	variable dly : sdelay_e_t;
begin
	if rising_edge(clk) then
		if reset = '1' then
			data <= (others => '0');
			de <= '0';
			ae <= '0';
			vgb <= '0';
			dgb <= '0';
			vsync0 <= '0';
			info_ready <= '1';
			if_trig <= '0';
			packet0 <= '0';
		else
			dly := sdelay(0);
			data <= dly.data;
			de <= dly.de;
			ae <= '0';
			vgb <= '0';
			dgb <= '0';
			if_trig <= '0';
			if dly.de = '0' then
				-- default: only output vsync & hsync
				if enc_busy = '1' then
					-- data island mode
					if enc_preamble = '1' then
						-- preamble for data island period
						data(17 downto 16) <= "01";
						data(9 downto 8) <= "01";
						packet0 <= '0';
					elsif enc_guard = '1' then
						-- leading or trailing guard band
						ae <= '1';
						dgb <= '1';
						data(3 downto 2) <= "11";
					elsif enc_packet = '1' then
						ae <= '1';
						data(2) <= aux0;
						data(3) <= packet0;
						packet0 <= '1';
						data(11 downto 8) <= aux1;
						data(19 downto 16) <= aux2;
					end if;
				elsif pr_cnt > 2 then
					-- preamble for video data period
					data(17 downto 16) <= "00";
					data(9 downto 8) <= "01";
				elsif pr_cnt > 0 then
					-- video leading guard band
					vgb <= '1';
				end if;
				vsync0 <= dly.data(1);
				if dly.data(1) /= vsync0 then
					if info_ready = '1' then
						info_ready <= '0';
					else
						-- second vsync value change after video display => trigger data island for InfoFrames
						if_trig <= '1';
					end if;
				end if;
			else
				info_ready <= '1';
			end if;
		end if;
	end if;
end process;


end architecture;
