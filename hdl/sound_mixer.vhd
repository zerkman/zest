-- sound_mixer.vhd - Atari ST sound mixer
--
-- Copyright (c) 2023 Francois Galea <fgalea at free.fr>
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

entity sound_mixer is
	port (
		clk			: in std_logic;
		cken		: in std_logic;
		reset		: in std_logic;

		vol			: in std_logic_vector(4 downto 0);

		psg_cken	: in std_logic;
		psg_a		: in std_logic_vector(15 downto 0);
		psg_b		: in std_logic_vector(15 downto 0);
		psg_c		: in std_logic_vector(15 downto 0);

		snd_clk		: in std_logic;
		osnd		: out std_logic_vector(15 downto 0)
	);
end sound_mixer;

architecture rtl of sound_mixer is
	type alu_mode_t is ( ALU_NOP, ALU_MOVE, ALU_ADD, ALU_SUB );
	signal alu_mode	: alu_mode_t;
	signal alu_i	: integer range -2**25 to 2**25-1;
	signal alu_o	: integer range -2**25 to 2**25-1;

	signal mix_st	: integer range 0 to 36;

	signal snd_clk1	: std_logic;
	signal sndc		: integer range -2**15 to 2**15-1;
	signal x0		: integer range -2**16 to 2**16-1;
	signal x1		: integer range -2**15 to 2**15-1;
	signal y0		: integer range -2**15 to 2**15-1;
	signal y1		: integer range -2**15 to 2**15-1;
	signal z0		: integer range -2**15 to 2**15-1;
	signal z1		: integer range -2**25 to 2**25-1;
	signal sound	: integer range -2**20 to 2**20-1;
	signal bid		: integer range 0 to 4;

begin

	osnd <= std_logic_vector(to_signed(sound/16,16));

	-- Simple ALU logic
	process(clk)
	begin
		if rising_edge(clk) then
			case alu_mode is
			when ALU_NOP =>
				null;
			when ALU_MOVE =>
				alu_o <= alu_i;
			when ALU_ADD =>
				alu_o <= alu_o + alu_i;
			when ALU_SUB =>
				alu_o <= alu_o - alu_i;
			end case;
		end if;
	end process;

	-- Low pass filter simulating the STF's YM output RC circuitry
	-- + DC adjuster as a IIR HPF
	-- methods taken from the Hatari ST emulator
	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				snd_clk1 <= '0';
				alu_mode <= ALU_NOP;
				x0 <= 0;
				x1 <= 0;
				y0 <= 0;
				y1 <= 0;
				z0 <= 0;
				z1 <= 0;
				mix_st <= 0;
				sound <= 0;
			else
				mix_st <= mix_st + 1;
				case mix_st is
				when 0 =>
					if psg_cken = '0' then
						mix_st <= 0;
					end if;
				when 1 =>
					alu_i <= to_integer(signed(psg_a));
					alu_mode <= ALU_MOVE;
					x0 <= to_integer(signed(psg_b));
					sndc <= to_integer(signed(psg_c));
				when 2 =>
					alu_i <= x0;		-- psg_b
					alu_mode <= ALU_ADD;
				when 3 =>
					-- psg_a
					alu_i <= sndc;		-- psg_c
				when 4 =>
					-- psg_a + psg_b
					alu_mode <= ALU_NOP;
				when 5 =>
					-- psg_a + psg_b + psg_c
					alu_i <= 4*alu_o;
					alu_mode <= ALU_ADD;
				when 6 =>
					-- psg_a + psg_b + psg_c
					alu_mode <= ALU_NOP;
				when 7 =>
					-- 5*(psg_a + psg_b + psg_c)
					x0 <= alu_o/16;		-- x0 <= 5*(psg_a + psg_b + psg_c)/16
				when 8 =>
					alu_i <= x0;
					alu_mode <= ALU_MOVE;
				when 9 =>
					alu_i <= x1;
					alu_mode <= ALU_ADD;
				when 10 =>
					-- x0
					alu_mode <= ALU_NOP;
				when 11 =>
					-- x0 + x1
					x0 <= alu_o;
					x1 <= x0;
					if x0 < y0 then
						mix_st <= 16;
					end if;
				when 12 =>
					-- x0 >= y0 -> pullup
					alu_i <= alu_o;		-- x0 + x1
					alu_mode <= ALU_ADD;
				when 13 =>
					null;
				when 14 =>
					-- 2*(x0 + x1)
					alu_i <= 2*y0;
				when 15 =>
					-- 3*(x0 + x1)
					alu_mode <= ALU_NOP;
					mix_st <= 21;
				when 16 =>
					-- x0 < y0 -> pulldown
					alu_i <= 2*y0;
					alu_mode <= ALU_MOVE;
				when 17 =>
					alu_mode <= ALU_ADD;
				when 18 =>
					-- 2*y0
					null;
				when 19 =>
					-- 4*y0
					alu_i <= x0;		-- x0 + x1
				when 20 =>
					-- 6*y0
					alu_mode <= ALU_NOP;
				when 21 =>
					-- from 15: 3*(x0 + x1) + 2*y0
					-- from 20: x0 + x1 + 6*y0
					y0 <= alu_o/8;
					snd_clk1 <= snd_clk;
					if snd_clk = '0' and snd_clk1 = '1' then	-- low edge of sound clock
						-- proceed to next step
						null;
					else
						-- go to idle state
						mix_st <= 0;
					end if;
				when 22 =>
					alu_i <= y0;
					alu_mode <= ALU_MOVE;
				when 23 =>
					alu_i <= y1;
					alu_mode <= ALU_SUB;
				when 24 =>
					-- y0
					alu_mode <= ALU_NOP;
				when 25 =>
					-- y0 - y1
					alu_i <= alu_o*(2**9);
					alu_mode <= ALU_MOVE;
				when 26 =>
					alu_i <= z1;
					alu_mode <= ALU_ADD;
				when 27 =>
					-- (y0 - y1)<<9
					alu_i <= z0;
					alu_mode <= ALU_SUB;
				when 28 =>
					-- z1 + (y0 - y1)<<9
					alu_i <= 0;
					alu_mode <= ALU_MOVE;
				when 29 =>
					-- z1 + (y0 - y1)<<9 - z0;
					z1 <= alu_o;
					z0 <= alu_o/(2**9);
					y1 <= y0;
					alu_i <= alu_o/(2**9);
					alu_mode <= ALU_NOP;
					bid <= 0;
				when 30 to 34 =>
					if vol(bid) = '1' then
						alu_mode <= ALU_ADD;
					else
						alu_mode <= ALU_NOP;
					end if;
					alu_i <= alu_i*2;
					bid <= bid+1;
				when 35 =>
					alu_mode <= ALU_NOP;
				when 36 =>
					sound <= alu_o;
					mix_st <= 0;
				end case;
			end if;
		end if;
	end process;


end architecture;
