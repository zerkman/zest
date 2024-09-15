-- memory_if_axi.vhd - Memory interface for the Zynq-7000's integrated DDR controller
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

entity cache_block is
	generic (
		DATA_WIDTH : integer := 32;
		ADDR_WIDTH : integer := 10
	);
	port (
		clk  : in std_logic;
		addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		din  : in std_logic_vector(DATA_WIDTH-1 downto 0);
		dout : out std_logic_vector(DATA_WIDTH-1 downto 0);
		en   : in std_logic;
		we   : in std_logic
	);
end cache_block;

architecture behavioral of cache_block is
	type mem_t is array (2**ADDR_WIDTH-1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
	signal mem : mem_t;

begin

process(clk)
begin
	if rising_edge(clk) then
		if en = '1' then
			if we = '1' then
				mem(to_integer(unsigned(addr))) <= din;
				dout <= din;
			else
				dout <= mem(to_integer(unsigned(addr)));
			end if;
		end if;
	end if;
end process;

end architecture;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity cache_mem is
	generic (
		ADDR_WIDTH : integer := 10
	);
	port (
		clk  : in std_logic;
		addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		din  : in std_logic_vector(288-1 downto 0);
		dout : out std_logic_vector(288-1 downto 0);
		en   : in std_logic;
		we   : in std_logic
	);
end cache_mem;

architecture behavioral of cache_mem is
begin
	mem: for i in 0 to 7 generate
		blk: entity cache_block generic map (
			DATA_WIDTH => 36,
			ADDR_WIDTH => ADDR_WIDTH
		)
		port map (
			clk => clk,
			addr => addr,
			din => din(i*36+35 downto i*36),
			dout => dout(i*36+35 downto i*36),
			en => en,
			we => we
		);
	end generate;
end architecture;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity memory_if_axi is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Base address of targeted slave
		-- C_M_TARGET_SLAVE_BASE_ADDR	: std_logic_vector	:= x"40000000";
		-- Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		-- C_M_AXI_BURST_LEN	: integer	:= 8;
		-- Thread ID Width
		C_M_AXI_ID_WIDTH	: integer	:= 6;
		-- Width of Address Bus
		C_M_AXI_ADDR_WIDTH	: integer	:= 32;
		-- Width of Data Bus
		C_M_AXI_DATA_WIDTH	: integer	:= 32;
		-- RAM address offset
		OFFSET				: unsigned(31 downto 0)	:= x"10000000"
	);
	port (
		-- address
		a		: in std_logic_vector(31 downto 0);
		-- write data
		w_d		: in std_logic_vector(15 downto 0);
		-- read data
		r_d		: out std_logic_vector(15 downto 0);
		-- initiate write transaction
		w		: in std_logic;
		-- initiate read transaction
		r		: in std_logic;
		-- data strobe (for each byte of the data bus)
		ds		: in std_logic_vector(1 downto 0);

		-- Write done signal
		w_done	: out std_logic;
		-- Read done signal
		r_done	: out std_logic;

		-- Asserts when ERROR is detected
		ERROR	: out std_logic;
		-- Global Clock Signal.
		m_axi_aclk	: in std_logic;
		-- Global Reset Singal. This Signal is Active Low
		m_axi_aresetn	: in std_logic;
		-- Master Interface Write Address ID
		m_axi_awid	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Interface Write Address
		m_axi_awaddr	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		m_axi_awlen	: out std_logic_vector(3 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		m_axi_awsize	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information,
		-- determine how the address for each transfer within the burst is calculated.
		m_axi_awburst	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
		-- atomic characteristics of the transfer.
		m_axi_awlock	: out std_logic_vector(1 downto 0);
		-- Memory type. This signal indicates how transactions
		-- are required to progress through a system.
		m_axi_awcache	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		m_axi_awprot	: out std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that
		-- the channel is signaling valid write address and control information.
		m_axi_awvalid	: out std_logic;
		-- Write address ready. This signal indicates that
		-- the slave is ready to accept an address and associated control signals
		m_axi_awready	: in std_logic;
		-- Master Interface Write Data ID
		m_axi_wid	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Interface Write Data.
		m_axi_wdata	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte
		-- lanes hold valid data. There is one write strobe
		-- bit for each eight bits of the write data bus.
		m_axi_wstrb	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		-- Write last. This signal indicates the last transfer in a write burst.
		m_axi_wlast	: out std_logic;
		-- Write valid. This signal indicates that valid write
		-- data and strobes are available
		m_axi_wvalid	: out std_logic;
		-- Write ready. This signal indicates that the slave
		-- can accept the write data.
		m_axi_wready	: in std_logic;
		-- Master Interface Write Response.
		m_axi_bid	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Write response. This signal indicates the status of the write transaction.
		m_axi_bresp	: in std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the
		-- channel is signaling a valid write response.
		m_axi_bvalid	: in std_logic;
		-- Response ready. This signal indicates that the master
		-- can accept a write response.
		m_axi_bready	: out std_logic;
		-- Master Interface Read Address.
		m_axi_arid	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Read address. This signal indicates the initial
		-- address of a read burst transaction.
		m_axi_araddr	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		m_axi_arlen	: out std_logic_vector(3 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		m_axi_arsize	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information,
		-- determine how the address for each transfer within the burst is calculated.
		m_axi_arburst	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
		-- atomic characteristics of the transfer.
		m_axi_arlock	: out std_logic_vector(1 downto 0);
		-- Memory type. This signal indicates how transactions
		-- are required to progress through a system.
		m_axi_arcache	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		m_axi_arprot	: out std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that
		-- the channel is signaling valid read address and control information
		m_axi_arvalid	: out std_logic;
		-- Read address ready. This signal indicates that
		-- the slave is ready to accept an address and associated control signals
		m_axi_arready	: in std_logic;
		-- Read ID tag. This signal is the identification tag
		-- for the read data group of signals generated by the slave.
		m_axi_rid	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Read Data
		m_axi_rdata	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the read transfer
		m_axi_rresp	: in std_logic_vector(1 downto 0);
		-- Read last. This signal indicates the last transfer in a read burst
		m_axi_rlast	: in std_logic;
		-- Read valid. This signal indicates that the channel
		-- is signaling the required read data.
		m_axi_rvalid	: in std_logic;
		-- Read ready. This signal indicates that the master can
		-- accept the read data and response information.
		m_axi_rready	: out std_logic
	);
end memory_if_axi;

architecture implementation of memory_if_axi is
	-- cache signals
	type cline_state_t is (EMPTY,VALID,RES1,RES2);
	type rd_state_t is (INIT,CLEAR,IDLE,READ_CACHE1,READ_CACHE2,READ_BURST1,READ_BURST2,READ_BURST3,READ_HIT,WRITE_CACHE1,WRITE_CACHE2,WRITE_END);
	constant C_ADDR_WIDTH : integer := 9;
	signal c_addr	: std_logic_vector(C_ADDR_WIDTH-1 downto 0);
	signal c_en		: std_logic;
	signal c_we		: std_logic;
	signal c_iline	: std_logic_vector(288-1 downto 0);
	signal c_oline	: std_logic_vector(288-1 downto 0);
	-- line ID = address[C_ADDR_WIDTH+5-1:5]
	-- line format:
	-- - bits 0-255 : line data
	-- - 32-5-C_ADDR_WIDTH next bits : address
	-- - topmost 2 bits : line state
	signal rd_state		: rd_state_t;
	signal line_state	: cline_state_t;
	signal line_addr	: std_logic_vector(31 downto C_ADDR_WIDTH+5);
	signal r_idx		: integer range 0 to 15;
	signal r_burst_cnt	: integer range 0 to 7;


	-- function called clogb2 that returns an integer which has the
	--value of the ceiling of the log base 2

	function clogb2 (bit_depth : integer) return integer is
		variable depth	: integer := bit_depth;
		variable count	: integer := 1;
	begin
		for i in 1 to bit_depth loop	-- Works for up to 32 bit integers
			if bit_depth <= 2 then
				count := 1;
			else
				if depth <= 1 then
					count := count;
				else
					depth := depth / 2;
					count := count + 1;
				end if;
			end if;
		end loop;
		return(count);
	end;

	-- AXI3 signals
	--AXI3 internal temp signals
	signal axi_awaddr	: std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_awvalid	: std_logic;
	signal axi_awvalid_ff	: std_logic;
	signal axi_wdata	: std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
	signal axi_wstrb	: std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
	signal axi_wlast	: std_logic;
	signal axi_wvalid	: std_logic;
	signal axi_bready	: std_logic;
	signal axi_araddr	: std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
	signal axi_arvalid	: std_logic;
	signal axi_rready	: std_logic;

	signal rdata	: std_logic_vector(15 downto 0);

begin
	-- cache memory
	cache: entity cache_mem generic map (
			ADDR_WIDTH => C_ADDR_WIDTH
		)
		port map (
			clk => m_axi_aclk,
			addr => c_addr,
			din => c_iline,
			dout => c_oline,
			en => c_en,
			we => c_we
		);


	--I/O Connections. Write Address (AW)
	m_axi_awid	<= (others => '0');
	--The AXI address is a concatenation of the target base address + active offset range
	m_axi_awaddr	<= std_logic_vector(unsigned(axi_awaddr)+OFFSET);
	--Burst LENgth is number of transaction beats, minus 1
	m_axi_awlen	<= std_logic_vector(to_unsigned(0,4));
	--Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
	m_axi_awsize	<= std_logic_vector( to_unsigned(clogb2((C_M_AXI_DATA_WIDTH/8)-1), 3) );
	--INCR burst type is usually used, except for keyhole bursts
	m_axi_awburst	<= "01";
	m_axi_awlock	<= "00";
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	m_axi_awcache	<= "0010";
	m_axi_awprot	<= "000";
	m_axi_awvalid	<= axi_awvalid;
	--I/O Connections. Write Data (W)
	m_axi_wid	<= (others => '0');
	--Write Data(W)
	m_axi_wdata	<= axi_wdata;
	--All bursts are complete and aligned in this example
	m_axi_wstrb	<= axi_wstrb;
	m_axi_wlast	<= axi_wlast;
	m_axi_wvalid	<= axi_wvalid;
	--Write Response (B)
	m_axi_bready	<= axi_bready;
	--Read Address (AR)
	m_axi_arid	<= (others => '0');
	m_axi_araddr	<= std_logic_vector(unsigned(axi_araddr)+OFFSET);
	--Burst LENgth is number of transaction beats, minus 1
	m_axi_arlen	<= std_logic_vector(to_unsigned(7,4));
	--Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	m_axi_arsize	<= std_logic_vector( to_unsigned( clogb2((C_M_AXI_DATA_WIDTH/8)-1),3 ));
	--INCR burst type is usually used, except for keyhole bursts
	m_axi_arburst	<= "01";
	m_axi_arlock	<= "00";
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	m_axi_arcache	<= "0010";
	m_axi_arprot	<= "000";
	m_axi_arvalid	<= axi_arvalid;
	--Read and Read Response (R)
	m_axi_rready	<= axi_rready;

	ERROR <= '0';

	------------------------------
	-- State machine for read and write channels
	------------------------------

	line_state <= cline_state_t'val(to_integer(unsigned(c_oline(288-1 downto 288-2))));
	line_addr <= c_oline(256+32-C_ADDR_WIDTH-5-1 downto 256);
	r_d <= rdata(7 downto 0) & rdata(15 downto 8);
	r_idx <= to_integer(unsigned(a(4 downto 1)));

	process(m_axi_aclk,m_axi_aresetn)
	begin
		if m_axi_aresetn = '0' then
			axi_rready <= '0';
			rd_state <= INIT;
			c_iline <= (others => '0');
			c_addr <= (others => '0');
			c_en <= '0';
			c_we <= '0';
			rdata <= (others => '0');
			r_done <= '0';
			r_burst_cnt <= 0;
			axi_wvalid <= '0';
			axi_wlast <= '0';
			axi_bready <= '0';
			axi_wdata <= (others => '0');
			axi_wstrb <= (others => '0');
			axi_awaddr <= (others => '0');
			axi_awvalid <= '0';
			w_done <= '0';
		elsif rising_edge(m_axi_aclk) then
			case rd_state is
				when INIT =>
					c_en <= '1';
					c_we <= '1';
					rd_state <= CLEAR;
				when CLEAR =>
					if unsigned(c_addr) /= 2**C_ADDR_WIDTH-1 then
						c_addr <= std_logic_vector(unsigned(c_addr) + 1);
					else
						c_en <= '0';
						c_we <= '0';
						c_addr <= (others => '0');
						rd_state <= IDLE;
					end if;
				when IDLE =>
					if r = '1' or w = '1' then
						c_addr <= a(C_ADDR_WIDTH+5-1 downto 5);
						c_en <= '1';
						if r = '1' then
							rd_state <= READ_CACHE1;
						else
							rd_state <= WRITE_CACHE1;
						end if;
					end if;
				when READ_CACHE1 =>
					c_addr <= (others => '0');
					c_en <= '0';
					rd_state <= READ_CACHE2;
				when READ_CACHE2 =>
					if line_state = VALID and line_addr = a(31 downto C_ADDR_WIDTH+5) then
						rdata <= c_oline((r_idx+1)*16-1 downto r_idx*16);
						r_done <= '1';
						rd_state <= READ_HIT;
					else
						axi_araddr <= a(31 downto 5) & "00000";
						axi_arvalid <= '1';
						axi_rready <= '1';
						r_burst_cnt <= 0;
						rd_state <= READ_BURST1;
					end if;
				when READ_BURST1 =>
					if m_axi_arready = '1' then
						axi_arvalid <= '0';
					end if;
					if m_axi_rvalid = '1' then
						c_iline(255 downto 0) <= m_axi_rdata & c_iline(255 downto 32);
						if r_burst_cnt = 7 then
							c_iline(288-1 downto 288-2) <= std_logic_vector(to_unsigned(cline_state_t'pos(VALID),2));
							c_iline(256+32-C_ADDR_WIDTH-5-1 downto 256) <= a(31 downto C_ADDR_WIDTH+5);
							c_addr <= a(C_ADDR_WIDTH+5-1 downto 5);
							c_en <= '1';
							c_we <= '1';
							axi_rready <= '0';
							rd_state <= READ_BURST2;
						else
							r_burst_cnt <= r_burst_cnt + 1;
						end if;
					end if;
				when READ_BURST2 =>
					c_addr <= (others => '0');
					c_en <= '0';
					c_we <= '0';
					rd_state <= READ_BURST3;
				when READ_BURST3 =>
					rdata <= c_oline((r_idx+1)*16-1 downto r_idx*16);
					r_done <= '1';
					rd_state <= READ_HIT;
				when READ_HIT =>
					if r = '0' then
						rdata <= (others => '0');
						r_done <= '0';
						rd_state <= IDLE;
					end if;
				when WRITE_CACHE1 =>
					c_addr <= (others => '0');
					c_en <= '0';
					rd_state <= WRITE_CACHE2;
				when WRITE_CACHE2 =>
					if line_state = VALID and line_addr = a(31 downto C_ADDR_WIDTH+5) then
						c_iline <= c_oline;
						if ds(1) = '1' then
							c_iline(r_idx*16+7 downto r_idx*16) <= w_d(15 downto 8);
						end if;
						if ds(0) = '1' then
							c_iline(r_idx*16+15 downto r_idx*16+8) <= w_d(7 downto 0);
						end if;
						c_addr <= a(C_ADDR_WIDTH+5-1 downto 5);
						c_en <= '1';
						c_we <= '1';
					end if;
					axi_awaddr <= a(31 downto 2) & "00";
					axi_awvalid <= '1';
					axi_wdata <= w_d(7 downto 0) & w_d(15 downto 8) & w_d(7 downto 0) & w_d(15 downto 8);
					if a(1) = '0' then
						axi_wstrb <= "00" & ds(0) & ds(1);
					else
						axi_wstrb <= ds(0) & ds(1) & "00";
					end if;
					axi_wlast <= '1';
					axi_wvalid <= '1';
					axi_bready <= '1';
					w_done <= '1';
					rd_state <= WRITE_END;
				when WRITE_END =>
					c_addr <= (others => '0');
					c_en <= '0';
					c_we <= '0';
					if w = '0' then
						w_done <= '0';
					end if;
					if m_axi_awready = '1' then
						axi_awaddr <= (others => '0');
						axi_awvalid <= '0';
					end if;
					if m_axi_wready = '1' then
						axi_wdata <= (others => '0');
						axi_wstrb <= "0000";
						axi_wlast <= '0';
						axi_wvalid <= '0';
					end if;
					if m_axi_bvalid = '1' then
						axi_bready <= '0';
					end if;
					if w = '0' and (m_axi_awready = '1' or axi_awvalid = '0') and (m_axi_wready = '1' or axi_wvalid = '0') and (m_axi_bvalid = '1' or axi_bready = '0') then
						rd_state <= IDLE;
					end if;
			end case;

		end if;
	end process;


end implementation;
