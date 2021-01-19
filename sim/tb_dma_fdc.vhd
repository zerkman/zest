-- tb_dma_fdc.vhd - testbench for DMA, fdc and floppy drive
--
-- Copyright (c) 2020,2021 Francois Galea <fgalea at free.fr>
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

entity tb_dma_fdc is
end tb_dma_fdc;

architecture dut of tb_dma_fdc is
	component sim_host is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			intr		: in std_logic;
			din			: in std_logic_vector(31 downto 0);
			dout		: out std_logic_vector(31 downto 0);
			r			: in std_logic;
			w			: in std_logic;
			addr		: in std_logic_vector(10 downto 0);
			track		: in std_logic_vector(7 downto 0)
		);
	end component;

	component floppy_drive is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			read_datan	: out std_logic;
			side0		: in std_logic;
			indexn		: out std_logic;
			drv_select	: in std_logic;
			motor_on	: in std_logic;
			direction	: in std_logic;
			stepn		: in std_logic;
			write_data	: in std_logic;
			write_gate	: in std_logic;
			track0n		: out std_logic;
			write_protn	: out std_logic;

			host_intr	: out std_logic;
			host_din	: out std_logic_vector(31 downto 0);
			host_dout	: in std_logic_vector(31 downto 0);
			host_r		: out std_logic;
			host_w		: out std_logic;
			host_addr	: out std_logic_vector(10 downto 0);
			host_track	: out std_logic_vector(7 downto 0)
		);
	end component;

	component wd1772 is
		port (
			clk			: in std_logic;
			clken		: in std_logic;
			resetn		: in std_logic;

			CSn			: in std_logic;
			RWn			: in std_logic;
			A			: in std_logic_vector(1 downto 0);
			iDAL		: in std_logic_vector(7 downto 0);
			oDAL		: out std_logic_vector(7 downto 0);
			INTRQ		: out std_logic;
			DRQ			: out std_logic;
			DDENn		: in std_logic;
			WPRTn		: in std_logic;
			IPn			: in std_logic;
			TR0n		: in std_logic;
			WD			: out std_logic;
			WG			: out std_logic;
			MO			: out std_logic;
			RDn			: in std_logic;
			DIRC		: out std_logic;
			STEP		: out std_logic
		);
	end component;

	component dma_controller is
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

			FDCSn	: out std_logic;
			FDRQ	: in std_logic;
			CRWn	: out std_logic;
			CA		: out std_logic_vector(1 downto 0);
			oCD		: out std_logic_vector(7 downto 0);
			iCD		: in std_logic_vector(7 downto 0)
		);
	end component;

	signal clk			: std_logic := '1';
	signal clken		: std_logic;
	signal resetn		: std_logic;

	signal dma_FCSn		: std_logic;
	signal dma_iRDY		: std_logic;
	signal dma_oRDY		: std_logic;
	signal bus_RWn		: std_logic;

	signal bus_A1		: std_logic;
	signal bus_iD		: std_logic_vector(15 downto 0);
	signal bus_oD		: std_logic_vector(15 downto 0);

	signal HDCSn		: std_logic;
	signal HDRQ			: std_logic;

	signal FD_CSn		: std_logic;
	signal FD_RWn		: std_logic;
	signal FD_A			: std_logic_vector(1 downto 0);
	signal iDAL			: std_logic_vector(7 downto 0);
	signal oDAL			: std_logic_vector(7 downto 0);
	signal INTRQ		: std_logic;
	signal DRQ			: std_logic;
	signal DDENn		: std_logic;

	signal read_datan	: std_logic;
	signal side0		: std_logic;
	signal indexn		: std_logic;
	signal drv_select	: std_logic;
	signal motor_on		: std_logic;
	signal direction	: std_logic;
	signal stepn		: std_logic;
	signal write_data	: std_logic;
	signal write_gate	: std_logic;
	signal track0n		: std_logic;
	signal write_protn	: std_logic;

	signal host_intr	: std_logic;
	signal host_din		: std_logic_vector(31 downto 0);
	signal host_dout	: std_logic_vector(31 downto 0);
	signal host_r		: std_logic;
	signal host_w		: std_logic;
	signal host_addr	: std_logic_vector(10 downto 0);
	signal host_track	: std_logic_vector(7 downto 0);

begin
	host:sim_host port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		intr => host_intr,
		din => host_din,
		dout => host_dout,
		r => host_r,
		w => host_w,
		addr => host_addr,
		track => host_track
	);

	floppy:floppy_drive port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		read_datan => read_datan,
		side0 => side0,
		indexn => indexn,
		drv_select => drv_select,
		motor_on => motor_on,
		direction => direction,
		stepn => stepn,
		write_data => write_data,
		write_gate => write_gate,
		track0n => track0n,
		write_protn => write_protn,

		host_intr => host_intr,
		host_din => host_din,
		host_dout => host_dout,
		host_r => host_r,
		host_w => host_w,
		host_addr => host_addr,
		host_track => host_track
	);
	side0 <= '1';

	fdc:wd1772 port map (
		clk => clk,
		clken => clken,
		resetn => resetn,

		CSn => FD_CSn,
		RWn => FD_RWn,
		A => FD_A,
		iDAL => iDAL,
		oDAL => oDAL,
		INTRQ => INTRQ,
		DRQ => DRQ,
		DDENn => DDENn,
		WPRTn => write_protn,
		IPn => indexn,
		TR0n => track0n,
		WD => write_data,
		WG => write_gate,
		MO => motor_on,
		RDn => read_datan,
		DIRC => direction,
		STEP => stepn
	);
	DDENn <= '0';

	dma:dma_controller port map (
		clk => clk,
		cken => clken,
		resetn => resetn,

		FCSn => dma_FCSn,
		iRDY => dma_iRDY,
		oRDY => dma_oRDY,
		RWn => bus_RWn,

		A1 => bus_A1,
		iD => bus_iD,
		oD => bus_oD,

		HDCSn => HDCSn,
		HDRQ => HDRQ,

		FDCSn => FD_CSn,
		FDRQ => DRQ,
		CRWn => FD_RWn,
		CA => FD_A,
		oCD => iDAL,
		iCD => oDAL
	);
	HDRQ <= '0';

	clk <= not clk after 62500 ps;	-- 8 MHz
	clken <= '1';
	resetn <= '0', '1' after 30 us;

	tb1 : process
		constant cycle: time := 125 ns;
		constant instr: time := 1 us;
		procedure bus_w (constant a : in std_logic; constant d : in std_logic_vector(15 downto 0)) is
		begin
			wait for cycle;
			bus_RWn <= '0';
			bus_A1 <= a;
			wait for cycle;
			dma_FCSn <= '0';
			bus_iD <= d;
			wait for cycle;
			bus_RWn <= '1';
			dma_FCSn <= '1';
			bus_A1 <= '1';
			bus_iD <= x"ffff";
			wait for cycle;
		end bus_w;

		procedure bus_r (constant a : in std_logic) is
		begin
			wait for cycle;
			bus_RWn <= '1';
			bus_A1 <= a;
			dma_FCSn <= '0';
			wait for 2*cycle;
			bus_RWn <= '1';
			dma_FCSn <= '1';
			bus_A1 <= '1';
			wait for cycle;
		end bus_r;

		procedure dma_r (constant count : in integer) is
		begin
			for i in 0 to count-1 loop
				wait until dma_oRDY = '1';
				wait for 20*cycle;
				for j in 0 to 7 loop
					dma_iRDY <= '0';
					wait for cycle;
					dma_iRDY <= '1';
					wait for 3*cycle;
				end loop;
			end loop;
		end dma_r;
	begin
		drv_select <= '0';
		bus_RWn <= '1';
		dma_FCSn <= '1';
		bus_iD <= x"ffff";
		dma_iRDY <= '1';
		wait for 50 us;

		drv_select <= '1';
		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0080");		-- FDC command register
		bus_w('0',x"0003");		-- restore command, motor on/spin up, stepping rate=3 ms

		wait until INTRQ = '1';
		wait for 4*cycle;

		bus_w('1',x"0082");		-- FDC track register, DMA on
		bus_w('0',x"0042");
		bus_w('1',x"0084");		-- FDC sector register, DMA on
		bus_w('0',x"0043");
		bus_w('1',x"0082");		-- FDC track register, DMA on
		bus_r('0');
		bus_w('1',x"0084");		-- FDC sector register, DMA on
		bus_r('0');
		bus_w('1',x"0082");		-- FDC track register, DMA on
		bus_w('0',x"0000");

		bus_w('1',x"0086");		-- FDC data register
		bus_w('0',x"0002");		-- go to track 2
		bus_w('1',x"0080");		-- FDC command register
		bus_w('0',x"001f");		-- seek command, no motor on/spin up, verify, stepping rate=3 ms

		wait until INTRQ = '1';
		bus_w('1',x"0080");		-- FDC status register, DMA on
		bus_r('0');

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0090");		-- DMA sector count register
		bus_w('0',x"0014");		-- read size must be larger than track size
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"00EC");		-- read track, no spin-up, 15 ms delay
		dma_r(390);

		wait until INTRQ = '1';

		bus_w('1',x"0086");		-- FDC data register
		bus_w('0',x"0000");		-- go to track 0
		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"0013");		-- Seek

		wait until INTRQ = '1';

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"000b");		-- Restore

		wait until INTRQ = '1';

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0190");		-- DMA sector count register
		bus_w('0',x"0002");		-- write 2 sectors
		bus_w('1',x"0184");		-- FDC sector register
		bus_w('0',x"0002");		-- start from sector 2
		bus_w('1',x"0180");		-- FDC command register, DMA on
		bus_w('0',x"00B8");		-- write sector, multiple sector mode, disable spin-up

		for i in 0 to 63 loop
			if dma_oRDY = '0' then
				wait until dma_oRDY = '1';
			end if;
			wait for 20*cycle;
			for j in 0 to 7 loop
				bus_iD <= "0000000" & std_logic_vector(to_unsigned(i,6)) & std_logic_vector(to_unsigned(j,3));
				dma_iRDY <= '0';
				wait for cycle;
				bus_iD <= x"ffff";
				dma_iRDY <= '1';
				wait for 3*cycle;
			end loop;
		end loop;
		wait for 2 ms;

		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"00D8");		-- force interrupt, immediate

		wait until INTRQ = '1';

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0090");		-- DMA sector count register
		bus_w('0',x"0001");		-- read 1 sector
		bus_w('1',x"0084");		-- FDC sector register
		bus_w('0',x"0007");		-- read sector 7
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"0088");		-- read sector, single sector mode, disable spin-up
		dma_r(32);

		wait until INTRQ = '1';

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0090");		-- DMA sector count register
		bus_w('0',x"0003");		-- read 3 sectors
		bus_w('1',x"0084");		-- FDC sector register
		bus_w('0',x"0001");		-- read starting from sector 1
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"0098");		-- read sector, multiple sector mode, disable spin-up
		dma_r(96);
		-- no INTRQ in multiple sector mode

		bus_w('1',x"0180");		-- reset DMA by toggling write bit
		bus_w('1',x"0080");		-- FDC command register, DMA on
		bus_w('0',x"00D8");		-- force interrupt, immediate

		wait until INTRQ = '1';

		assert false report "end of test" severity note;
		wait;
	end process;
end architecture;
