-- clock_enabler.vhd - Generator for the clock enables corresponding to the ST clocks
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

entity clock_enabler is
	generic (
		-- system clock frequency
		CLK_FREQ_NUM	: integer := 100;
		CLK_FREQ_DIV	: integer := 1;		-- 100/1 = 100 MHz
		-- clock we want to simulate
		CPU_FREQ_NUM	: integer := 8000;
		CPU_FREQ_DIV	: integer := 1000;	-- 8.017 MHz
		-- counter bits
		CPT_BITS	: integer := 28
	);
	port (
		clk			: in std_logic;
		reset		: in std_logic;
		wakestate	: in std_logic_vector(1 downto 0);
		enNC1		: in std_logic;		-- enable 8 MHz rising edges
		enNC2		: in std_logic;		-- enable 8 MHz falling edges
		en8rck		: out std_logic;	-- 8 MHz rising edge
		en8fck		: out std_logic;	-- 8 MHz falling edge
		en16rck		: out std_logic;	-- 16 MHz rising edge
		en16fck		: out std_logic;	-- 16 MHz falling edge
		en32ck		: out std_logic;	-- 32 MHz rising edge
		en4rck		: out std_logic;	-- 4 MHz rising edge
		en4fck		: out std_logic;	-- 4 MHz falling edge
		en2rck		: out std_logic;	-- 2 MHz rising edge
		en2fck		: out std_logic;	-- 2 MHz falling edge
		en2_4576	: out std_logic;	-- 2.4576 MHz rising edge
		ck05		: out std_logic;	-- 500 kHz clock
		error		: out std_logic		-- time out error
	);
end clock_enabler;

architecture behavioral of clock_enabler is

	-- increment to add to counter so that half period is reached
	-- at proper number of cycles when counter reaches CLK_FREQ_NUM
	constant incr	: integer := 2*CLK_FREQ_DIV*CPU_FREQ_NUM;

	signal cnt			: unsigned(CPT_BITS-1 downto 0);
	signal cnt24		: unsigned(15 downto 0);
	signal cnt05		: unsigned(3 downto 0);
	signal cnt2			: unsigned(1 downto 0);
	signal delay		: std_logic;
	signal phase		: std_logic;
	signal en1			: std_logic;
	signal en2			: std_logic;
	signal en24			: std_logic;
	signal err			: std_logic;
	signal new_phase	: std_logic;

begin
	-- TODO remove the 1 cycle delay between enNC and enPhi

	en8rck <= en1;
	en8fck <= en2;
	en4rck <= en1 and cnt05(0);
	en4fck <= en1 and not cnt05(0);
	en2rck <= en2 and not cnt2(1) and not cnt2(0);
	en2fck <= en2 and cnt2(1) and not cnt2(0);
	en2_4576 <= en24;
	ck05 <= cnt05(3);
	cnt2 <= cnt05(1 downto 0) + unsigned(wakestate);
	error <= err;

	process(phase,enNC1,enNC2,delay,cnt)
	begin
		if ((phase = '0' and enNC1 = '1') or (phase = '1' and enNC2 = '1')) and delay = '0' and cnt + incr >= CLK_FREQ_NUM*CPU_FREQ_DIV then
			new_phase <= '1';
		else
			new_phase <= '0';
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) then
			if reset = '1' then
				cnt05 <= (others => '0');
			elsif en1 = '1' then
				cnt05 <= cnt05 + 1;
			end if;
		end if;
	end process;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if (reset = '1') then
				cnt <= (others => '0');
				cnt24 <= (others => '0');
				delay <= '0';
				phase <= '0';
				en1 <= '0';
				en2 <= '0';
				en32ck <= '0';
				en24 <= '0';
				err <= '0';
				en16fck <= '0';
				en16rck <= '0';
			else
				en1 <= '0';
				en2 <= '0';
				en32ck <= '0';
				en24 <= '0';
				en16fck <= '0';
				en16rck <= '0';
				if new_phase = '1' then
					if phase = '0' then
						en1 <= '1';
					else
						en2 <= '1';
					end if;
					en32ck <= '1';
					en16fck <= '1';
					phase <= not phase;
					cnt <= cnt + incr - CLK_FREQ_NUM*CPU_FREQ_DIV;
					delay <= '1';
				else
					cnt <= cnt + incr;
					if delay = '1' then
						en32ck <= '1';
						en16rck <= '1';
					end if;
					delay <= '0';
				end if;
				if cnt(CPT_BITS-1) = '1' then
					err <= '1';
				end if;
				if new_phase = '1' or delay = '1' then
					-- 32*2400/31333 ~= 2.451 MHz
					if cnt24+2400 >= 31333 then
						en24 <= '1';
						cnt24 <= cnt24 + 2400 - 31333;
					else
						cnt24 <= cnt24 + 2400;
					end if;
				end if;
			end if;
		end if;
	end process;

end behavioral;
