-- mc68901.vhd - Implementation of the MC68901 Multi-Function Peripheral chip
--
-- Copyright (c) 2020-2024 Francois Galea <fgalea at free.fr>
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

	signal csn1		: std_logic;
	signal siackn	: std_logic_vector(2 downto 0);

	type prescale_t is array(1 to 7) of integer;
	signal prescale	: prescale_t := (2,5,8,25,32,50,100);
	signal xtldiv	: std_logic;

	type cntarray_t is array(0 to 3) of std_logic_vector(7 downto 0);
	signal tato		: std_logic;
	signal tapc		: integer range 0 to 100;
	signal tamc		: unsigned(7 downto 0);
	signal tamc_r	: cntarray_t;
	signal tai1		: std_logic_vector(2 downto 0);

	signal tbto		: std_logic;
	signal tbpc		: integer range 0 to 100;
	signal tbmc		: unsigned(7 downto 0);
	signal tbmc_r	: cntarray_t;
	signal tbi1		: std_logic_vector(2 downto 0);

	signal tcto		: std_logic;
	signal tcpc		: integer range 0 to 100;
	signal tcmc		: unsigned(7 downto 0);
	signal tcmc_r	: cntarray_t;

	signal tdto		: std_logic;
	signal tdpc		: integer range 0 to 100;
	signal tdmc		: unsigned(7 downto 0);
	signal tdmc_r	: cntarray_t;

	signal sirqn	: std_logic;
	signal intv		: std_logic_vector(15 downto 0);
	signal ipl		: std_logic_vector(3 downto 0);
	signal isr_ipl	: std_logic_vector(3 downto 0);
	signal dtackn_irq	: std_logic;
	signal dtackn_reg	: std_logic;

	signal sod		: std_logic_vector(7 downto 0);
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
	dtackn <= (dtackn_irq and dtackn_reg) or dsn;
	od <= sod when csn = '0' or iackn = '0' else x"ff";

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

	process(clk,resetn)
	begin
		if resetn = '0' then
			xtldiv <= '0';
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
			sod <= x"ff";
			dtackn_irq <= '1';
			dtackn_reg <= '1';

			tato <= '0';
			tapc <= 1;
			tamc <= x"01";
			tamc_r <= (others => x"00");
			tai1 <= (others => '0');

			tbto <= '0';
			tbpc <= 1;
			tbmc <= x"01";
			tbmc_r <= (others => x"00");
			tbi1 <= (others => '0');

			tcto <= '0';
			tcpc <= 1;
			tcmc <= x"01";
			tcmc_r <= (others => x"00");

			tdto <= '0';
			tdpc <= 1;
			tdmc <= x"01";
			tdmc_r <= (others => x"00");
			csn1 <= '1';
			siackn <= (others => '1');
		elsif rising_edge(clk) then
			if xtlcken = '1' then
				xtldiv <= not xtldiv;
			end if;
			if xtlcken = '1' and xtldiv = '0' then
				-- Timer A operation
				tai1 <= tai1(tai1'high-1 downto 0) & tai;
				if ierb(6) = '1' and tacr(3) = '1' and tai1(tai1'high) /= tai1(tai1'high-1) and tai = aer(4) then
					-- Pulse count interrupt, GPIP4 channel
					iprb(6) <= '1';
				end if;
				if tacr /= "0000" then
					-- Decrement counters in delay mode or pulse width measurement mode or event count mode
					if tacr(3) = '0' or (tacr = "1000" and tai1(tai1'high) /= tai1(tai1'high-1) and tai = aer(4)) then
						if tapc = 1 or tacr = "1000" then
							if tacr /= "1000" then
								tapc <= prescale(to_integer(unsigned(tacr(2 downto 0))));
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
				tbi1 <= tbi1(tbi1'high-1 downto 0) & tbi;
				if ierb(3) = '1' and tbcr(3) = '1' and tbi1(tbi1'high) /= tbi1(tbi1'high-1) and tbi = aer(3) then
					-- Pulse count interrupt, GPIP3 channel
					iprb(3) <= '1';
				end if;
				if tbcr /= "0000" then
					-- Decrement counters in delay mode or pulse width measurement mode or event count mode
					if tbcr(3) = '0' or (tbcr = "1000" and tbi1(tbi1'high) /= tbi1(tbi1'high-1) and tbi = aer(3)) then
						if tbpc = 1 or tbcr = "1000" then
							if tbcr /= "1000" then
								tbpc <= prescale(to_integer(unsigned(tbcr(2 downto 0))));
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
					if tcpc = 1 then
						tcpc <= prescale(to_integer(unsigned(tcdcr(5 downto 3))));
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
					if tdpc = 1 then
						tdpc <= prescale(to_integer(unsigned(tcdcr(2 downto 0))));
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
				tamc_r(0 to tamc_r'high-1) <= tamc_r(1 to tamc_r'high);
				tbmc_r(0 to tbmc_r'high-1) <= tbmc_r(1 to tbmc_r'high);
				tcmc_r(0 to tcmc_r'high-1) <= tcmc_r(1 to tcmc_r'high);
				tdmc_r(0 to tdmc_r'high-1) <= tdmc_r(1 to tdmc_r'high);
				tamc_r(tamc_r'high) <= std_logic_vector(tamc);
				tbmc_r(tbmc_r'high) <= std_logic_vector(tbmc);
				tcmc_r(tcmc_r'high) <= std_logic_vector(tcmc);
				tdmc_r(tdmc_r'high) <= std_logic_vector(tdmc);

				csn1 <= csn;
				siackn <= iackn & siackn(siackn'high downto 1);
				sod <= x"ff";
				dtackn_irq <= '1';
				dtackn_reg <= '1';
				if csn = '0' and csn1 = '0' then
					-- register access
					if rwn = '1' then
						-- register read access
						case addr is
							when x"01" => sod <= (gpip and ddr) or (ii and not ddr);
							when x"03" => sod <= aer;
							when x"05" => sod <= ddr;
							when x"07" => sod <= iera;
							when x"09" => sod <= ierb;
							when x"0b" => sod <= ipra;
							when x"0d" => sod <= iprb;
							when x"0f" => sod <= isra;
							when x"11" => sod <= isrb;
							when x"13" => sod <= imra;
							when x"15" => sod <= imrb;
							when x"17" => sod <= vr & "000";
							when x"19" => sod <= "0000" & tacr;
							when x"1b" => sod <= "0000" & tbcr;
							when x"1d" => sod <= '0' & tcdcr(5 downto 3) & '0' & tcdcr(2 downto 0);
							when x"1f" => sod <= std_logic_vector(tamc_r(0));
							when x"21" => sod <= std_logic_vector(tbmc_r(0));
							when x"23" => sod <= std_logic_vector(tcmc_r(0));
							when x"25" => sod <= std_logic_vector(tdmc_r(0));
							when x"27" => sod <= scr;
							when x"29" => sod <= ucr;
							when x"2b" => sod <= rsr;
							when x"2d" => sod <= tsr;
							when x"2f" => sod <= udr;
							when others =>
						end case;
					else
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
									tapc <= 1;
								elsif tacr = "0000" and id(3 downto 0) /= "1000" then
									tapc <= prescale(to_integer(unsigned(id(2 downto 0))));
								end if;
							when x"1b" =>
								tbcr <= id(3 downto 0);
								if id(4) = '1' then
									-- reset timer output
									tbto <= '0';
								end if;
								if id(3 downto 0) = "0000" then
									tbpc <= 1;
								elsif tbcr = "0000" and id(3 downto 0) /= "1000" then
									tbpc <= prescale(to_integer(unsigned(id(2 downto 0))));
								end if;
							when x"1d" =>
								tcdcr <= id(6 downto 4) & id(2 downto 0);
								if tcdcr(5 downto 3) = "000" and id(6 downto 4) /= "000" then
									tcpc <= prescale(to_integer(unsigned(id(6 downto 4))));
								end if;
								if tcdcr(2 downto 0) = "000" and id(2 downto 0) /= "000" then
									tdpc <= prescale(to_integer(unsigned(id(2 downto 0))));
								end if;
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
							when others => null;
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

				if sirqn = '0' and iackn = '0' and siackn(0) = '0' and dsn = '0' then
					-- begin interrupt acknowledge cycle
					dtackn_irq <= '0';
					sod <= vr(7 downto 4) & ipl;
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
			end if;
		end if;
	end process;

end behavioral;
