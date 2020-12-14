-- dma_controller.vhd - Implementation of the Atari ST DMA chip
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

entity dma_controller is
	port (
		clk		: in std_logic;
		cken	: in std_logic;

		FCSn	: in std_logic;
		iRDY	: in std_logic;
		oRDY	: out std_logic;
		RWn		: in std_logic;

		A1		: in std_logic;
		iD		: in std_logic_vector(15 downto 0);
		oD		: out std_logic_vector(15 downto 0);

		HDCSn	: out std_logic;
		HDRQ	: in std_logic;

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
	signal buf		: buf_t;
	signal buf_bi	: unsigned(2 downto 0);		-- index for bus operations (word index)
	signal buf_di	: unsigned(3 downto 0);		-- index for controller operations (byte index)
	signal buf_wl	: std_logic;				-- buffer line to write to
	signal sec_cnt	: std_logic_vector(15 downto 0);
	signal seccnt0	: std_logic;
	signal hdc_fdcn	: std_logic;
	signal reg_sel	: std_logic;
	signal dma_on	: std_logic;
	signal dma_fdc	: std_logic;
	signal dma_w	: std_logic;
	signal dma_err	: std_logic;
	type bus_st_t is ( idle, running, done );
	signal bus_st	: bus_st_t;
	type dc_st_t is ( idle, warmup, running, done );
	signal dc_st	: dc_st_t;
	signal rdy		: std_logic := '0';

begin

	oRDY <= rdy;
	dma_err <= '0';

	process(sec_cnt)
	begin
		if sec_cnt = x"0000" then
			seccnt0 <= '1';
		else
			seccnt0 <= '0';
		end if;
	end process;

	process(clk)
	begin
		if rising_edge(clk) and cken = '1' then
			oD <= x"ffff";
			oCD <= x"ff";
			FDCSn <= '1';
			CRWn <= '1';
			if FCSn = '0' then
				-- register access
				if RWn = '0' then
					-- write to internal registers
					if A1 = '0' then
						if reg_sel = '0' then
							FDCSn <= '0';
							CRWn <= '0';
							oCD <= iD(7 downto 0);
						else
							sec_cnt <= iD;
						end if;
					else
						CA <= iD(2 downto 1);
						hdc_fdcn <= iD(3);
						reg_sel <= iD(4);
						dma_on <= iD(6);
						dma_fdc <= iD(7);
						if dma_w /= iD(8) then
							-- reset DMA
							bus_st <= idle;
							dc_st <= idle;
							buf_bi <= (others => '0');
							buf_di <= (others => '0');
							buf_wl <= '0';
							rdy <= '0';
						end if;
						if dma_on = '0' and iD(6) = '1' then
							CA <= "11";
							bus_st <= running;
							if dma_w = '1' then
								dc_st <= warmup;
							else
								dc_st <= running;
							end if;
						end if;
						if dma_on = '1' and iD(6) = '0' then
							bus_st <= idle;
							dc_st <= idle;
						end if;
						dma_w <= iD(8);
					end if;
				else
					-- read registers
					if A1 = '0' then
						if reg_sel = '0' then
							FDCSn <= '0';
							-- FIXME will not work (1 cycle delay)
							oD <= x"00" & iCD;
						else
							oD <= sec_cnt;
						end if;
					else
						oD <= (15 downto 3 => '0', 2 => FDRQ, 1 => seccnt0, 0 => dma_err);
					end if;
				end if;
			end if;

			-- state machine for bus operations
			case bus_st is
			when idle =>
				null;
			when running =>
				rdy <= '1';
				if iRDY = '0' then
					if dma_w = '1' then
						-- write to hdc/fdc, so read from memory
						buf(to_integer(buf_wl & buf_bi)) <= iD;
					else
						-- read from hdc/fdc, so write to memory
						oD <= buf(to_integer(not buf_wl & buf_bi));
					end if;
					buf_bi <= buf_bi + 1;
					if buf_bi + 1 = 0 then
						rdy <= '0';
						bus_st <= done;
					end if;
				end if;
			when done =>
				null;
			end case;

			-- state machine for disk controller operations
			case dc_st is
			when idle =>
				null;
			when warmup =>
				-- read fisrt data burst
				-- dma_w must be 1
				if bus_st = done then
					buf_wl <= not buf_wl;
					bus_st <= running;
					dc_st <= running;
				end if;
			when running =>
				if FDRQ = '1' then
					FDCSn <= '0';
					if dma_w = '1' then
						-- write to fdc
						CRWn <= '0';
						if buf_di(0) = '0' then
							oCD <= buf(to_integer(not buf_wl & buf_di(3 downto 1)))(15 downto 8);
						else
							oCD <= buf(to_integer(not buf_wl & buf_di(3 downto 1)))(7 downto 0);
						end if;
					else
						-- read from fdc
						if buf_di(0) = '0' then
							buf(to_integer(buf_wl & buf_di(3 downto 1)))(15 downto 8) <= iCD;
						else
							buf(to_integer(buf_wl & buf_di(3 downto 1)))(7 downto 0) <= iCD;
						end if;
					end if;
					buf_di <= buf_di + 1;
					if buf_di + 1 = 0 then
						buf_wl <= not buf_wl;
						bus_st <= running;
					end if;
				end if;
			when done =>
				null;
			end case;
		end if;
	end process;
end architecture;
