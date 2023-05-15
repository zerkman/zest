-- acsi.vhd - ACSI drive emulation (hardware part)
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

library work;
use work.all;

entity acsi_drive is
	port (
		clk		: in std_logic;
		resetn	: in std_logic;

		-- bridge bus signals
		bridge_addr		: in std_logic_vector(11 downto 2);
		bridge_r		: in std_logic;
		bridge_r_data	: out std_logic_vector(31 downto 0);
		bridge_w		: in std_logic;
		bridge_w_data	: in std_logic_vector(31 downto 0);
		bridge_w_strb	: in std_logic_vector(3 downto 0);

		-- host signals
		host_intr		: out std_logic;

		-- DMA port signals
		csn				: in std_logic;
		rwn				: in std_logic;
		a1				: in std_logic;
		intn			: out std_logic;
		drq				: out std_logic;
		ackn			: in std_logic;
		w_d				: in std_logic_vector(7 downto 0);
		r_d				: out std_logic_vector(7 downto 0)
	);
end acsi_drive;

architecture rtl of acsi_drive is
	constant DATA_WIDTH_BITS	: integer := 5;				-- 32-bit
	constant ADDR_MSB	: integer := 10;					-- 2048 bytes
	constant ADDR_LSB	: integer := DATA_WIDTH_BITS-3;		-- 32-bit access

	-- RAM signals
	signal ram_addr1	: std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_addr2	: std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_din1		: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_din2		: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_wsb1		: std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);
	signal ram_wsb2		: std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0);
	signal ram_dout1	: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_dout2	: std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
	signal ram_we1		: std_logic;
	signal ram_we2		: std_logic;
	signal ram_re1		: std_logic;
	signal ram_re2		: std_logic;

	type r_data_t is array (0 to 1) of std_logic_vector(31 downto 0);
	signal r_data		: r_data_t;
	signal r_data_idx	: integer range 0 to 1;

	signal reg			: std_logic_vector(8 downto 0);
	signal status		: std_logic_vector(7 downto 0);
	signal csn1			: std_logic;
	signal init_dma_rd	: std_logic;
	signal init_dma_wr	: std_logic;
	signal dma_buf_id	: std_logic;
	signal dma_maxblk	: unsigned(4 downto 0);
	signal rdhs			: std_logic_vector(7 downto 0);
	signal hs_hostintr	: std_logic;

	type dma_st_t is (IDLE,READ,READ1,READ2,READ3,READ4,WRITE,WRITE1);
	signal dma_st		: dma_st_t;
	signal dma_cnt		: integer range 0 to 511;
	signal sdrq			: std_logic;
	signal sintn		: std_logic;
	signal srd			: std_logic_vector(7 downto 0);
	signal rddma		: std_logic_vector(7 downto 0);
	signal rdreg		: std_logic_vector(23 downto 0);
	signal dma_hostintr	: std_logic;
	signal wrreg		: std_logic_vector(23 downto 0);

begin
	ram : entity ram_tdp generic map (
			DATA_WIDTH => 32,
			ADDR_WIDTH => 9
		)
		port map (
			clk1 => clk,
			clk2 => clk,
			addr1 => ram_addr1,
			addr2 => ram_addr2,
			din1 => ram_din1,
			din2 => ram_din2,
			wsb1 => ram_wsb1,
			wsb2 => ram_wsb2,
			dout1 => ram_dout1,
			dout2 => ram_dout2,
			we1 => ram_we1,
			we2 => ram_we2,
			re1 => ram_re1,
			re2 => ram_re2
		);

	-- Bridge bus access to memory buffer
	process(bridge_addr,bridge_r,bridge_w)
	begin
		ram_re1 <= '0';
		ram_we1 <= '0';
		-- test address top bit
		if bridge_addr(ADDR_MSB+1) = '1' then
			-- ram access
			ram_re1 <= bridge_r;
			ram_we1 <= bridge_w;
		end if;
	end process;
	bridge_r_data <= r_data(r_data_idx);
	r_data(1) <= ram_dout1;
	r_data(0) <= (31 downto 9 => '0') & reg;
	ram_addr1 <= bridge_addr(ADDR_MSB downto ADDR_LSB);
	ram_din1 <= bridge_w_data;
	ram_wsb1 <= bridge_w_strb;
	drq <= sdrq;
	intn <= sintn;
	srd <= rdhs when dma_st = IDLE else rddma;
	r_d <= srd when (sdrq = '1' or csn = '0') else x"ff";
	host_intr <= hs_hostintr or dma_hostintr;

	-- Handshake register, Status register, DMA interrupt
	process(clk,resetn)
		variable addr : integer range 0 to 511;
	begin
		if resetn = '0' then
			csn1 <= '1';
			reg <= (others => '1');
			status <= x"00";
			sintn <= '1';
			rdhs <= x"00";
			hs_hostintr <= '0';
			init_dma_rd <= '0';
			init_dma_wr <= '0';
			dma_buf_id <= '0';
			dma_maxblk <= (others => '0');
			r_data_idx <= 0;
		elsif rising_edge(clk) then
			csn1 <= csn;
			init_dma_rd <= '0';
			init_dma_wr <= '0';
			if csn = '0' and csn1 = '1' then
				if rwn = '0' then
					-- we received a byte from the DMA host
					reg <= a1 & w_d;
					hs_hostintr <= '1';
				else
					rdhs <= status;
				end if;
				sintn <= '1';
			end if;
			if bridge_r = '1' then
				if bridge_addr(ADDR_MSB+1) = '0' then
					r_data_idx <= 0;
				else
					r_data_idx <= 1;
				end if;
			end if;
			if bridge_addr(ADDR_MSB+1) = '0' and (bridge_r = '1' or bridge_w = '1') then
				-- register access from PL
				addr := to_integer(unsigned(bridge_addr(ADDR_MSB downto ADDR_LSB)));
				if addr = 0 then
					hs_hostintr <= '0';
					if bridge_w = '1' then
						case bridge_w_data(9 downto 8) is
							when "00" =>
								-- write status register
								status <= bridge_w_data(7 downto 0);
								sintn <= '0';
							when "01" =>
								-- initiate DMA read transfer (send to DMA)
								init_dma_rd <= '1';
								dma_buf_id <= bridge_w_data(0);
								dma_maxblk <= unsigned(bridge_w_data(7 downto 3));
							when "10" =>
								-- initiate DMA write transfer (read from DMA)
								init_dma_wr <= '1';
								dma_buf_id <= bridge_w_data(0);
								dma_maxblk <= unsigned(bridge_w_data(7 downto 3));
							when others =>
								null;
						end case;
					end if;
				end if;
			end if;
		end if;
	end process;

	-- DMA management
	process(clk,resetn)
		variable id : integer range 0 to 3;
	begin
		if resetn = '0' then
			dma_st <= IDLE;
			dma_cnt <= 0;
			ram_addr2 <= (others => '1');
			ram_din2 <= (others => '0');
			ram_wsb2 <= (others => '0');
			ram_re2 <= '0';
			ram_we2 <= '0';
			rddma <= x"00";
			rdreg <= x"000000";
			sdrq <= '0';
			dma_hostintr <= '0';
			wrreg <= x"000000";
		elsif rising_edge(clk) then
			case dma_st is
				when IDLE =>
					if unsigned(bridge_addr) = 0 and bridge_w = '1' then
						dma_hostintr <= '0';
					end if;
					if init_dma_rd = '1' then
						dma_cnt <= 0;
						dma_st <= READ;
					end if;
					if init_dma_wr = '1' then
						dma_cnt <= 0;
						dma_st <= WRITE;
					end if;

				when READ =>
					if dma_cnt rem 4 = 0 then
						ram_addr2 <= '0' & dma_buf_id & std_logic_vector(to_unsigned(dma_cnt/4,7));
						ram_re2 <= '1';
						dma_st <= READ1;
					else
						dma_st <= READ2;
					end if;
				when READ1 =>
					ram_addr2 <= (others => '1');
					ram_re2 <= '0';
					dma_st <= READ2;
				when READ2 =>
					id := dma_cnt rem 4;
					if id = 0 then
						rddma <= ram_dout2(7 downto 0);
						rdreg <= ram_dout2(31 downto 8);
					else
						rddma <= rdreg(7 downto 0);
						rdreg <= x"00" & rdreg(23 downto 8);
					end if;
					sdrq <= '1';
					dma_st <= READ3;
				when READ3 =>
					if ackn = '0' then
						sdrq <= '0';
						dma_st <= READ4;
					end if;
				when READ4 =>
					if ackn = '1' then
						if (dma_cnt+1)/16 <= dma_maxblk then
							dma_cnt <= dma_cnt + 1;
							dma_st <= READ;
						else
							dma_cnt <= 0;
							dma_hostintr <= '1';
							dma_st <= IDLE;
						end if;
					end if;

				when WRITE =>
					sdrq <= '1';
					if ackn = '0' then
						sdrq <= '0';
						if dma_cnt rem 4 = 3 then
							ram_addr2 <= '0' & dma_buf_id & std_logic_vector(to_unsigned(dma_cnt/4,7));
							ram_din2 <= w_d & wrreg;
							ram_wsb2 <= "1111";
							ram_we2 <= '1';
						else
							wrreg <= w_d & wrreg(23 downto 8);
						end if;
						dma_st <= WRITE1;
					end if;
				when WRITE1 =>
					ram_addr2 <= (others => '1');
					ram_din2 <= (others => '0');
					ram_wsb2 <= "0000";
					ram_we2 <= '0';
					if ackn = '1' then
						if (dma_cnt+1)/16 <= dma_maxblk then
							dma_cnt <= dma_cnt + 1;
							dma_st <= WRITE;
						else
							dma_cnt <= 0;
							dma_hostintr <= '1';
							dma_st <= IDLE;
						end if;
					end if;
			end case;
		end if;
	end process;

end architecture;
