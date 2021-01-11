-- mc68901.vhd - Implementation of the MC68901 Multi-Function Peripheral chip
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

entity mc68901 is
	port (
		clk		: in std_logic;
		clkren	: in std_logic;
		clkfen	: in std_logic;
		xtlcken	: in std_logic;
		resetn	: in std_logic;

		-- cpu bus I/O
		id		: in std_logic_vector(7 downto 0);
		od		: out std_logic_vector(7 downto 0);
		rs		: in std_logic_vector(5 downto 1);
		csn		: in std_logic;
		rwn		: in std_logic;
		dsn		: in std_logic;
		dtackn	: out std_logic;

		-- interrupt control
		irqn	: out std_logic;
		iackn	: in std_logic;
		iein	: in std_logic;
		ieon	: out std_logic;

		-- general purpose I/O -- interrupts
		ii		: in std_logic_vector(7 downto 0);
		io		: out std_logic_vector(7 downto 0);

		-- timer control
		tai		: in std_logic;
		tbi		: in std_logic;
		tao		: out std_logic;
		tbo		: out std_logic;
		tco		: out std_logic;
		tdo		: out std_logic;

		-- serial I/O control
		si		: in std_logic;
		rc		: in std_logic;
		so		: out std_logic;
		tc		: in std_logic;

		-- DMA control
		rrn		: out std_logic;
		trn		: out std_logic
	);
end mc68901;


architecture behavioral of mc68901 is
	signal gpip 	: std_logic_vector(7 downto 0);
	signal aer		: std_logic_vector(7 downto 0);
	signal ddr		: std_logic_vector(7 downto 0);
	signal iera		: std_logic_vector(7 downto 0);
	signal ierb		: std_logic_vector(7 downto 0);
	signal ipra		: std_logic_vector(7 downto 0);
	signal iprb		: std_logic_vector(7 downto 0);
	signal isra		: std_logic_vector(7 downto 0);
	signal isrb		: std_logic_vector(7 downto 0);
	signal imra		: std_logic_vector(7 downto 0);
	signal imrb		: std_logic_vector(7 downto 0);
	signal vr		: std_logic_vector(7 downto 3);
	signal tacr		: std_logic_vector(3 downto 0);
	signal tbcr		: std_logic_vector(3 downto 0);
	signal tcdcr	: std_logic_vector(5 downto 0);
	signal tadr		: std_logic_vector(7 downto 0);
	signal tbdr		: std_logic_vector(7 downto 0);
	signal tcdr		: std_logic_vector(7 downto 0);
	signal tddr		: std_logic_vector(7 downto 0);
	signal scr		: std_logic_vector(7 downto 0);
	signal ucr		: std_logic_vector(7 downto 0);
	signal rsr		: std_logic_vector(7 downto 0);
	signal tsr		: std_logic_vector(7 downto 0);
	signal udr		: std_logic_vector(7 downto 0);

	signal addr		: std_logic_vector(7 downto 0);

	type prescale_t is array(1 to 7) of integer;
	signal prescale	: prescale_t := (4,10,16,50,64,100,200);

	signal tato		: std_logic;
	signal tapc		: unsigned(7 downto 0);
	signal tamc		: unsigned(7 downto 0);
	signal tai1		: std_logic;

	signal tbto		: std_logic;
	signal tbpc		: unsigned(7 downto 0);
	signal tbmc		: unsigned(7 downto 0);
	signal tbi1		: std_logic;

	signal tcto		: std_logic;
	signal tcpc		: unsigned(7 downto 0);
	signal tcmc		: unsigned(7 downto 0);

	signal tdto		: std_logic;
	signal tdpc		: unsigned(7 downto 0);
	signal tdmc		: unsigned(7 downto 0);

	signal sirqn	: std_logic;
	signal intv		: std_logic_vector(15 downto 0);
	signal ipl		: std_logic_vector(3 downto 0);
	signal isr_ipl	: std_logic_vector(3 downto 0);
	signal dtackn_irq	: std_logic;
	signal dtackn_reg	: std_logic;

	signal ii1		: std_logic_vector(7 downto 0);

	-- priority encoder. Return the index of the highest set bit
	function priority(v : std_logic_vector(15 downto 0))
		return std_logic_vector is
	begin
		for i in v'range loop
			if v(i) = '1' then
				return std_logic_vector(to_unsigned(i,4));
			end if;
		end loop;
		return "0000";
	end priority;

begin
	so <= '1';
	rrn <= '1';
	trn <= '1';
	addr <= "00" & rs & '1';
	ieon <= '1';
	io <= gpip or not ddr;
	tao <= tato;
	tbo <= tbto;
	tco <= tcto;
	tdo <= tdto;
	irqn <= sirqn;
	dtackn <= dtackn_irq and dtackn_reg;

	process(intv,vr,ipl,isr_ipl,dtackn_irq)
	begin
		sirqn <= '1';
		if (intv /= x"0000" and vr(3) = '0') or ipl > isr_ipl or dtackn_irq = '0' then
			sirqn <= '0';
		end if;
	end process;

	intv <= (ipra and imra) & (iprb and imrb);
	ipl <= priority(intv);
	isr_ipl <= priority(isra&isrb);

	process(clk)
	begin
		if rising_edge(clk) then
			if resetn = '0' then
				gpip <= x"00";
				aer <= x"00";
				ddr <= x"00";
				iera <= x"00";
				ierb <= x"00";
				ipra <= x"00";
				iprb <= x"00";
				isra <= x"00";
				isrb <= x"00";
				imra <= x"00";
				imrb <= x"00";
				vr <= "00001";
				tacr <= "0000";
				tbcr <= "0000";
				tcdcr <= "000000";
				scr <= x"00";
				ucr <= x"00";
				rsr <= x"00";
				od <= x"ff";
				dtackn_irq <= '1';
				dtackn_reg <= '1';

				tato <= '0';
				tapc <= x"01";
				tamc <= x"01";
				tai1 <= '0';

				tbto <= '0';
				tbpc <= x"01";
				tbmc <= x"01";
				tbi1 <= '0';

				tcto <= '0';
				tcpc <= x"01";
				tcmc <= x"01";

				tdto <= '0';
				tdpc <= x"01";
				tdmc <= x"01";
			else
				if xtlcken = '1' then
					-- Timer A operation
					tai1 <= tai;
					if ierb(6) = '1' and tacr(3) = '1' and tai /= tai1 and tai = aer(4) then
						-- Pulse count interrupt, GPIP4 channel
						iprb(6) <= '1';
					end if;
					if tacr /= "0000" then
						-- Decrement counters in delay mode or pulse width measurement mode or event count mode
						if tacr(3) = '0' or (tacr = "1000" and tai /= tai1 and tai = aer(4)) then
							if tapc = x"01" or tacr = "1000" then
								if tacr /= "1000" then
									tapc <= to_unsigned(prescale(to_integer(unsigned(tacr(2 downto 0)))),tapc'length);
								end if;
								if tamc = x"01" then
									tamc <= unsigned(tadr);
									tato <= not tato;
									if iera(5) = '1' then
										-- Time out interrupt, Timer A channel
										ipra(5) <= '1';
									end if;
								else
									tamc <= tamc-1;
								end if;
							else
								tapc <= tapc-1;
							end if;
						end if;
					end if;

					-- Timer B operation
					tbi1 <= tbi;
					if ierb(3) = '1' and tbcr(3) = '1' and tbi /= tbi1 and tbi = aer(3) then
						-- Pulse count interrupt, GPIP3 channel
						iprb(3) <= '1';
					end if;
					if tbcr /= "0000" then
						-- Decrement counters in delay mode or pulse width measurement mode or event count mode
						if tbcr(3) = '0' or (tbcr = "1000" and tbi /= tbi1 and tbi = aer(3)) then
							if tbpc = x"01" or tbcr = "1000" then
								if tbcr /= "1000" then
									tbpc <= to_unsigned(prescale(to_integer(unsigned(tbcr(2 downto 0)))),tbpc'length);
								end if;
								if tbmc = x"01" then
									tbmc <= unsigned(tbdr);
									tbto <= not tbto;
									if iera(0) = '1' then
										-- Time out interrupt, Timer B channel
										ipra(0) <= '1';
									end if;
								else
									tbmc <= tbmc-1;
								end if;
							else
								tbpc <= tbpc-1;
							end if;
						end if;
					end if;

					-- Timer C operation
					if tcdcr(5 downto 3) /= "000" then
						-- Decrement counters in delay mode
						if tcpc = x"01" then
							tcpc <= to_unsigned(prescale(to_integer(unsigned(tcdcr(5 downto 3)))),tcpc'length);
							if tcmc = x"01" then
								tcmc <= unsigned(tcdr);
								tcto <= not tcto;
								if ierb(5) = '1' then
									-- Time out interrupt, Timer C channel
									iprb(5) <= '1';
								end if;
							else
								tcmc <= tcmc-1;
							end if;
						else
							tcpc <= tcpc-1;
						end if;
					end if;

					-- Timer D operation
					if tcdcr(2 downto 0) /= "000" then
						-- Decrement counters in delay mode
						if tdpc = x"01" then
							tdpc <= to_unsigned(prescale(to_integer(unsigned(tcdcr(2 downto 0)))),tdpc'length);
							if tdmc = x"01" then
								tdmc <= unsigned(tddr);
								tdto <= not tdto;
								if ierb(4) = '1' then
									-- Time out interrupt, Timer D channel
									iprb(4) <= '1';
								end if;
							else
								tdmc <= tdmc-1;
							end if;
						else
							tdpc <= tdpc-1;
						end if;
					end if;
				end if;

				if clkren = '1' then
					od <= x"ff";
					dtackn_irq <= '1';
					dtackn_reg <= '1';
					if csn = '0' then
						-- register access
						if rwn = '1' then
							-- register read access
							case addr is
								when x"01" => od <= (gpip and ddr) or (ii and not ddr);
								when x"03" => od <= aer;
								when x"05" => od <= ddr;
								when x"07" => od <= iera;
								when x"09" => od <= ierb;
								when x"0b" => od <= ipra;
								when x"0d" => od <= iprb;
								when x"0f" => od <= isra;
								when x"11" => od <= isrb;
								when x"13" => od <= imra;
								when x"15" => od <= imrb;
								when x"17" => od <= vr & "000";
								when x"19" => od <= "0000" & tacr;
								when x"1b" => od <= "0000" & tbcr;
								when x"1d" => od <= '0' & tcdcr(5 downto 3) & '0' & tcdcr(2 downto 0);
								when x"1f" => od <= std_logic_vector(tamc);
								when x"21" => od <= std_logic_vector(tbmc);
								when x"23" => od <= std_logic_vector(tcmc);
								when x"25" => od <= std_logic_vector(tdmc);
								when x"27" => od <= scr;
								when x"29" => od <= ucr;
								when x"2b" => od <= rsr;
								when x"2d" => od <= tsr;
								when x"2f" => od <= udr;
								when others =>
							end case;
						end if;
						dtackn_reg <= '0';
					end if;

					ii1 <= ii;
					if ddr(7) = '0' and ii(7) /= ii1(7) and ii(7) = aer(7) and iera(7) = '1' then ipra(7) <= '1'; end if;
					if ddr(6) = '0' and ii(6) /= ii1(6) and ii(6) = aer(6) and iera(6) = '1' then ipra(6) <= '1'; end if;
					if ddr(5) = '0' and ii(5) /= ii1(5) and ii(5) = aer(5) and ierb(7) = '1' then iprb(7) <= '1'; end if;
					if ddr(4) = '0' and ii(4) /= ii1(4) and ii(4) = aer(4) and ierb(6) = '1' then iprb(6) <= '1'; end if;
					if ddr(3) = '0' and ii(3) /= ii1(3) and ii(3) = aer(3) and ierb(3) = '1' then iprb(3) <= '1'; end if;
					if ddr(2) = '0' and ii(2) /= ii1(2) and ii(2) = aer(2) and ierb(2) = '1' then iprb(2) <= '1'; end if;
					if ddr(1) = '0' and ii(1) /= ii1(1) and ii(1) = aer(1) and ierb(1) = '1' then iprb(1) <= '1'; end if;
					if ddr(0) = '0' and ii(0) /= ii1(0) and ii(0) = aer(0) and ierb(0) = '1' then iprb(0) <= '1'; end if;

					if sirqn = '0' and iackn = '0' and dsn = '0' then
						-- begin interrupt acknowledge cycle
						dtackn_irq <= '0';
						od <= vr(7 downto 4) & ipl;
						if ipl(3) = '1' then
							ipra(to_integer(unsigned(ipl(2 downto 0)))) <= '0';
						else
							iprb(to_integer(unsigned(ipl(2 downto 0)))) <= '0';
						end if;
						if vr(3) = '1' then
							-- software end of interrupt mode
							if ipl(3) = '1' then
								isra(to_integer(unsigned(ipl(2 downto 0)))) <= '1';
							else
								isrb(to_integer(unsigned(ipl(2 downto 0)))) <= '1';
							end if;
						end if;
					end if;
				elsif clkfen = '1' then
					if csn = '0' and dsn = '0' and rwn = '0' then
						-- register write access
						case addr is
							when x"01" => gpip <= id;
							when x"03" => aer <= id;
							when x"05" => ddr <= id;
							when x"07" =>
								iera <= id;
								ipra <= ipra and id;
								if ddr(7) = '0' and iera(7) = '0' and id(7) = '1' and ii(7) = aer(7) then ipra(7) <= '1'; end if;
								if ddr(6) = '0' and iera(6) = '0' and id(6) = '1' and ii(6) = aer(6) then ipra(6) <= '1'; end if;
							when x"09" =>
								ierb <= id;
								iprb <= iprb and id;
								if ddr(5) = '0' and ierb(7) = '0' and id(7) = '1' and ii(5) = aer(5) then iprb(7) <= '1'; end if;
								if ddr(4) = '0' and ierb(6) = '0' and id(6) = '1' and ii(4) = aer(4) then iprb(6) <= '1'; end if;
								if ddr(3) = '0' and ierb(3) = '0' and id(3) = '1' and ii(3) = aer(3) then iprb(3) <= '1'; end if;
								if ddr(2) = '0' and ierb(2) = '0' and id(2) = '1' and ii(2) = aer(2) then iprb(2) <= '1'; end if;
								if ddr(1) = '0' and ierb(1) = '0' and id(1) = '1' and ii(1) = aer(1) then iprb(1) <= '1'; end if;
								if ddr(0) = '0' and ierb(0) = '0' and id(0) = '1' and ii(0) = aer(0) then iprb(0) <= '1'; end if;
							when x"0b" => ipra <= ipra and id;
							when x"0d" => iprb <= iprb and id;
							when x"0f" => isra <= isra and id;
							when x"11" => isrb <= isrb and id;
							when x"13" => imra <= id;
							when x"15" => imrb <= id;
							when x"17" =>
								vr <= id(7 downto 3);
								if id(3) = '0' then
									isra <= x"00";
									isrb <= x"00";
								end if;
							when x"19" =>
								tacr <= id(3 downto 0);
								if id(4) = '1' then
									-- reset timer output
									tato <= '0';
								end if;
								if id(3 downto 0) = "0000" then
									tapc <= x"01";
								end if;
							when x"1b" =>
								tbcr <= id(3 downto 0);
								if id(4) = '1' then
									-- reset timer output
									tbto <= '0';
								end if;
								if id(3 downto 0) = "0000" then
									tbpc <= x"01";
								end if;
							when x"1d" => tcdcr <= id(6 downto 4) & id(2 downto 0);
							when x"1f" =>
								tadr <= id;
								if tacr = "0000" then
									tamc <= unsigned(id);
								end if;
							when x"21" =>
								tbdr <= id;
								if tbcr = "0000" then
									tbmc <= unsigned(id);
								end if;
							when x"23" =>
								tcdr <= id;
								if tcdcr(5 downto 3) = "000" then
									tcmc <= unsigned(id);
								end if;
							when x"25" =>
								tddr <= id;
								if tcdcr(2 downto 0) = "000" then
									tdmc <= unsigned(id);
								end if;
							when x"27" => scr <= id;
							when x"29" => ucr <= id;
							when x"2b" => rsr <= id;
							when x"2d" => tsr <= id;
							when x"2f" => udr <= id;
							when others =>
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;

end behavioral;
