-- dma_controller.vhd - Implementation of the Atari ST DMA chip
--
-- Copyright (c) 2020-2025 Francois Galea <fgalea at free.fr>
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

entity dma_controller is
	port (
		clk		: in std_logic;
		cken	: in std_logic;
		resetn	: in std_logic;

		FCSn	: in std_logic;
		iRDY	: in std_logic;
		oRDY	: out std_logic;
		RWn		: in std_logic;

		A1		: in std_logic;
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0);

		HDCSn	: out std_logic;
		HDRQ	: in std_logic;
		ACKn	: out std_logic;

		FDCSn	: out std_logic;
		FDRQ	: in std_logic;
		CRWn	: out std_logic;
		CA		: out std_logic_vector(1 downto 0);
		oCD		: out std_logic_vector(7 downto 0);
		iCD		: in std_logic_vector(7 downto 0)
	);
end dma_controller;

architecture behavioral of dma_controller is
	type buf_t is array (0 to 15) of std_logic_vector(15 downto 0);
	signal buff		: buf_t;
	signal buf_bi	: unsigned(2 downto 0);		-- index for bus operations (word index)
	signal buf_di	: unsigned(3 downto 0);		-- index for controller operations (byte index)
	signal buf_wl	: std_logic;				-- buffer line to write to
	signal sec_cnt	: unsigned(16 downto 0);	-- 8 high bits: sector count, 9 low: byte count
	signal sca		: std_logic_vector(1 downto 0);	-- user selected FDC register
	signal seccnt0	: std_logic;
	signal hdc_fdcn	: std_logic;				-- redirect FCSn to 0:floppy, 1:DMA port
	signal reg_sel	: std_logic;
	signal dma_fdc	: std_logic;				-- DRQ/ACK on 0:ACSI, 1:floppy
	signal dma_w	: std_logic;
	signal dma_err	: std_logic;
	signal dma_on	: std_logic;
	signal dma_rst	: std_logic;
	signal dma_d	: std_logic_vector(15 downto 0);
	signal sicd		: std_logic_vector(7 downto 0);
	signal socd		: std_logic_vector(7 downto 0);
	signal sfdcsn	: std_logic;
	signal scrwn	: std_logic;
	signal rdreg_ff	: std_logic;
	type bus_st_t is ( idle, start, running, running_w, running_r, done );
	signal bus_st	: bus_st_t;
	type dc_st_t is ( idle, warmup, running, run_read, run_inc, done );
	signal dc_st	: dc_st_t;

begin

	dma_rst <= '1' when FCSn = '0' and RWn = '0' and A1 = '1' and dma_w /= iD(8) else '0';
	seccnt0 <= '0' when sec_cnt = 0 else '1';

	-- asynchronous register I/O
	process(sfdcsn,socd,scrwn,FCSn,RWn,socd,A1,reg_sel,sca,hdc_fdcn,iD,rdreg_ff,iCD,FDRQ,seccnt0,dma_err,iRDY,dma_w,dma_d)
	begin
		CA <= "11";
		HDCSn <= '1';
		FDCSn <= sfdcsn;
		oD <= x"ffff";
		oCD <= socd;
		CRWn <= scrwn;
		if FCSn = '0' then
			if RWn = '0' then
				if A1 = '0' then
					if reg_sel = '0' then
						-- write to FDC/HDC register
						CRWn <= '0';
						CA <= sca;
						HDCSn <= not hdc_fdcn;
						FDCSn <= hdc_fdcn;
						oCD <= iD(7 downto 0);
					end if;
				end if;
			else
				if A1 = '0' then
					if reg_sel = '0' then
						-- read register from FDC/HDC
						CRWn <= '1';
						CA <= sca;
						HDCSn <= not hdc_fdcn;
						FDCSn <= hdc_fdcn;
						if rdreg_ff = '1' then
							oD <= x"00" & sicd;
						end if;
					end if;
				else
					oD <= (15 downto 3 => '0', 2 => FDRQ, 1 => seccnt0, 0 => not dma_err);
				end if;
			end if;
		end if;
		if dma_w = '0' and iRDY = '0' then
			oD <= dma_d;
		end if;
	end process;

	process(resetn,clk)
	begin
		if resetn = '0' then
			oRDY <= '0';
			dma_w <= '0';
			bus_st <= idle;
			dc_st <= idle;
			buf_bi <= (others => '0');
			buf_di <= (others => '0');
			buf_wl <= '0';
			sca <= "00";
			socd <= x"ff";
			scrwn <= '1';
			sfdcsn <= '1';
			rdreg_ff <= '0';
			ACKn <= '1';
			dma_fdc <= '0';
			hdc_fdcn <= '0';
		elsif rising_edge(clk) then
		if cken = '1' then
			socd <= x"ff";
			scrwn <= '1';
			sfdcsn <= '1';
			rdreg_ff <= '0';
			sicd <= iCD;
			if FCSn = '0' then
				-- register access
				if RWn = '0' then
					-- write to internal registers
					if A1 = '0' then
						if reg_sel = '1' then
							-- sector count register
							sec_cnt <= unsigned(std_logic_vector'(iD(7 downto 0) & (8 downto 0 => '0')));
							if dma_w = '1' then
								bus_st <= running;
								dc_st <= warmup;
							else
								bus_st <= idle;
								dc_st <= running;
							end if;
						end if;
					else
						sca <= iD(2 downto 1);
						hdc_fdcn <= iD(3);
						reg_sel <= iD(4);
						dma_on <= not iD(6);
						dma_fdc <= iD(7);
						dma_w <= iD(8);
						if dma_rst = '1' then
							-- reset DMA
							dma_err <= '0';
							bus_st <= idle;
							dc_st <= idle;
							sec_cnt <= (others => '0');
							buf_bi <= (others => '0');
							buf_di <= (others => '0');
							buf_wl <= '0';
							oRDY <= '0';
						end if;
					end if;
				else
					if A1 = '0' and reg_sel = '0' then
						rdreg_ff <= '1';
					end if;
				end if;
			end if;

			if dma_on = '1' and dma_rst = '0' then
				-- state machine for bus operations
				case bus_st is
				when idle =>
					null;
				when start =>
					if dma_w = '0' then
						dma_d <= buff(to_integer(not buf_wl & buf_bi));
					end if;
					bus_st <= running;
				when running =>
					oRDY <= '1';
					if iRDY = '0' then
						if dma_w = '1' then
							-- read from memory, write to hdc/fdc
							bus_st <= running_w;
						else
							-- read from hdc/fdc, write to memory
							-- handled in data bus output process
							bus_st <= running_r;
							buf_bi <= buf_bi + 1;
							if buf_bi + 1 = 0 then
								oRDY <= '0';
								bus_st <= done;
							end if;
						end if;
					end if;
				when running_w =>
					buff(to_integer(buf_wl & buf_bi)) <= iD;
					bus_st <= running_r;
					buf_bi <= buf_bi + 1;
					if buf_bi + 1 = 0 then
						oRDY <= '0';
						bus_st <= done;
					end if;
				when running_r =>
					if iRDY = '1' then
						if dma_w = '0' then
							dma_d <= buff(to_integer(not buf_wl & buf_bi));
						end if;
						bus_st <= running;
					end if;
				when done =>
					null;
				end case;

				-- state machine for disk controller operations
				case dc_st is
				when idle =>
					null;
				when warmup =>
					-- read first data burst from memory before sending to fdc
					-- dma_w must be 1
					if bus_st = done then
						buf_wl <= not buf_wl;
						bus_st <= running;
						dc_st <= running;
					end if;
				when running =>
					if (FDRQ = '1' and dma_fdc = '1') or (HDRQ = '1' and dma_fdc = '0') then
						if seccnt0 = '0' then
							dma_err <= '1';
						else
							sfdcsn <= not dma_fdc;
							ACKn <= dma_fdc;
							if dma_w = '1' then
								-- write to fdc
								scrwn <= '0';
								if buf_di(0) = '0' then
									socd <= buff(to_integer(not buf_wl & buf_di(3 downto 1)))(15 downto 8);
								else
									socd <= buff(to_integer(not buf_wl & buf_di(3 downto 1)))(7 downto 0);
								end if;
								dc_st <= run_inc;
							else
								scrwn <= '1';
								if HDRQ = '1' then
									-- read from acsi
									if buf_di(0) = '0' then
										buff(to_integer(buf_wl & buf_di(3 downto 1)))(15 downto 8) <= iCD;
									else
										buff(to_integer(buf_wl & buf_di(3 downto 1)))(7 downto 0) <= iCD;
									end if;
									dc_st <= run_inc;
								else
									-- read from fdc
									dc_st <= run_read;
								end if;
							end if;
						end if;
					end if;
				when run_read =>
					if buf_di(0) = '0' then
						buff(to_integer(buf_wl & buf_di(3 downto 1)))(15 downto 8) <= iCD;
					else
						buff(to_integer(buf_wl & buf_di(3 downto 1)))(7 downto 0) <= iCD;
					end if;
					dc_st <= run_inc;
				when run_inc =>
					ACKn <= '1';
					if buf_di + 1 /= 0 or bus_st = done or bus_st = idle then
						sec_cnt <= sec_cnt - 1;
						buf_di <= buf_di + 1;
						if buf_di + 1 = 0 then
							buf_wl <= not buf_wl;
							if dma_w = '0' or sec_cnt - 1 >= 32 then
								-- read: always flush buffer to memory
								-- write: need to fetch at least 16 more bytes apart from the 16 already in buffer
								bus_st <= start;
							end if;
						end if;
						dc_st <= running;
					end if;
				when done =>
					null;
				end case;
			end if;
		end if;
		end if;
	end process;
end architecture;
