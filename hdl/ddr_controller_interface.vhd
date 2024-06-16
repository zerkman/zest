-- ddr_controller_interface.vhd - Memory interface for the Zynq-7000's integrated DDR controller
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

entity ddr_controller_interface is
	generic (
		-- Users to add parameters here

		-- User parameters ends
		-- Do not modify the parameters beyond this line

		-- Base address of targeted slave
		-- C_M_TARGET_SLAVE_BASE_ADDR	: std_logic_vector	:= x"40000000";
		-- Burst Length. Supports 1, 2, 4, 8, 16, 32, 64, 128, 256 burst lengths
		C_M_AXI_BURST_LEN	: integer	:= 1;
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
		M_AXI_ACLK	: in std_logic;
		-- Global Reset Singal. This Signal is Active Low
		M_AXI_ARESETN	: in std_logic;
		-- Master Interface Write Address ID
		M_AXI_AWID	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Interface Write Address
		M_AXI_AWADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		M_AXI_AWLEN	: out std_logic_vector(3 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		M_AXI_AWSIZE	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information,
		-- determine how the address for each transfer within the burst is calculated.
		M_AXI_AWBURST	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
		-- atomic characteristics of the transfer.
		M_AXI_AWLOCK	: out std_logic_vector(1 downto 0);
		-- Memory type. This signal indicates how transactions
		-- are required to progress through a system.
		M_AXI_AWCACHE	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		M_AXI_AWPROT	: out std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that
		-- the channel is signaling valid write address and control information.
		M_AXI_AWVALID	: out std_logic;
		-- Write address ready. This signal indicates that
		-- the slave is ready to accept an address and associated control signals
		M_AXI_AWREADY	: in std_logic;
		-- Master Interface Write Data ID
		M_AXI_WID	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Interface Write Data.
		M_AXI_WDATA	: out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte
		-- lanes hold valid data. There is one write strobe
		-- bit for each eight bits of the write data bus.
		M_AXI_WSTRB	: out std_logic_vector(C_M_AXI_DATA_WIDTH/8-1 downto 0);
		-- Write last. This signal indicates the last transfer in a write burst.
		M_AXI_WLAST	: out std_logic;
		-- Write valid. This signal indicates that valid write
		-- data and strobes are available
		M_AXI_WVALID	: out std_logic;
		-- Write ready. This signal indicates that the slave
		-- can accept the write data.
		M_AXI_WREADY	: in std_logic;
		-- Master Interface Write Response.
		M_AXI_BID	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Write response. This signal indicates the status of the write transaction.
		M_AXI_BRESP	: in std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the
		-- channel is signaling a valid write response.
		M_AXI_BVALID	: in std_logic;
		-- Response ready. This signal indicates that the master
		-- can accept a write response.
		M_AXI_BREADY	: out std_logic;
		-- Master Interface Read Address.
		M_AXI_ARID	: out std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Read address. This signal indicates the initial
		-- address of a read burst transaction.
		M_AXI_ARADDR	: out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
		-- Burst length. The burst length gives the exact number of transfers in a burst
		M_AXI_ARLEN	: out std_logic_vector(3 downto 0);
		-- Burst size. This signal indicates the size of each transfer in the burst
		M_AXI_ARSIZE	: out std_logic_vector(2 downto 0);
		-- Burst type. The burst type and the size information,
		-- determine how the address for each transfer within the burst is calculated.
		M_AXI_ARBURST	: out std_logic_vector(1 downto 0);
		-- Lock type. Provides additional information about the
		-- atomic characteristics of the transfer.
		M_AXI_ARLOCK	: out std_logic_vector(1 downto 0);
		-- Memory type. This signal indicates how transactions
		-- are required to progress through a system.
		M_AXI_ARCACHE	: out std_logic_vector(3 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		M_AXI_ARPROT	: out std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that
		-- the channel is signaling valid read address and control information
		M_AXI_ARVALID	: out std_logic;
		-- Read address ready. This signal indicates that
		-- the slave is ready to accept an address and associated control signals
		M_AXI_ARREADY	: in std_logic;
		-- Read ID tag. This signal is the identification tag
		-- for the read data group of signals generated by the slave.
		M_AXI_RID	: in std_logic_vector(C_M_AXI_ID_WIDTH-1 downto 0);
		-- Master Read Data
		M_AXI_RDATA	: in std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the read transfer
		M_AXI_RRESP	: in std_logic_vector(1 downto 0);
		-- Read last. This signal indicates the last transfer in a read burst
		M_AXI_RLAST	: in std_logic;
		-- Read valid. This signal indicates that the channel
		-- is signaling the required read data.
		M_AXI_RVALID	: in std_logic;
		-- Read ready. This signal indicates that the master can
		-- accept the read data and response information.
		M_AXI_RREADY	: out std_logic
	);
end ddr_controller_interface;

architecture implementation of ddr_controller_interface is


	-- function called clogb2 that returns an integer which has the
	--value of the ceiling of the log base 2

	function clogb2 (bit_depth : integer) return integer is
		variable depth	: integer := bit_depth;
		variable count	: integer := 1;
	begin
		for clogb2 in 1 to bit_depth loop	-- Works for up to 32 bit integers
			if (bit_depth <= 2) then
				count := 1;
			else
				if(depth <= 1) then
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
	signal axi_arvalid_ff	: std_logic;
	signal axi_rready	: std_logic;

	signal init_read_ff		: std_logic;
	signal init_read		: std_logic;
	signal init_write_ff	: std_logic;
	signal init_write		: std_logic;
	signal write_resp_error	: std_logic;

	signal rdata	: std_logic_vector(15 downto 0);
	signal rdata_ff	: std_logic_vector(15 downto 0);
	signal rod		: std_logic_vector(15 downto 0);
	signal rdone	: std_logic;
	signal rdone_ff	: std_logic;
	signal wdone	: std_logic;
	signal wdone_ff	: std_logic;
	signal ds_rd	: std_logic_vector(1 downto 0);
	signal a1_rd	: std_logic;

begin

	--I/O Connections. Write Address (AW)
	M_AXI_AWID	<= (others => '0');
	--The AXI address is a concatenation of the target base address + active offset range
	M_AXI_AWADDR	<= std_logic_vector(unsigned(axi_awaddr)+OFFSET);
	--Burst LENgth is number of transaction beats, minus 1
	M_AXI_AWLEN	<= std_logic_vector( to_unsigned(C_M_AXI_BURST_LEN - 1, 4) );
	--Size should be C_M_AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
	M_AXI_AWSIZE	<= std_logic_vector( to_unsigned(clogb2((C_M_AXI_DATA_WIDTH/8)-1), 3) );
	--INCR burst type is usually used, except for keyhole bursts
	M_AXI_AWBURST	<= "01";
	M_AXI_AWLOCK	<= "00";
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	M_AXI_AWCACHE	<= "0010";
	M_AXI_AWPROT	<= "000";
	M_AXI_AWVALID	<= axi_awvalid;
	--I/O Connections. Write Data (W)
	M_AXI_WID	<= (others => '0');
	--Write Data(W)
	M_AXI_WDATA	<= axi_wdata;
	--All bursts are complete and aligned in this example
	M_AXI_WSTRB	<= axi_wstrb;
	M_AXI_WLAST	<= axi_wlast;
	M_AXI_WVALID	<= axi_wvalid;
	--Write Response (B)
	M_AXI_BREADY	<= axi_bready;
	--Read Address (AR)
	M_AXI_ARID	<= (others => '0');
	M_AXI_ARADDR	<= std_logic_vector(unsigned(axi_araddr)+OFFSET);
	--Burst LENgth is number of transaction beats, minus 1
	M_AXI_ARLEN	<= std_logic_vector( to_unsigned(C_M_AXI_BURST_LEN - 1, 4) );
	--Size should be C_M_AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
	M_AXI_ARSIZE	<= std_logic_vector( to_unsigned( clogb2((C_M_AXI_DATA_WIDTH/8)-1),3 ));
	--INCR burst type is usually used, except for keyhole bursts
	M_AXI_ARBURST	<= "01";
	M_AXI_ARLOCK	<= "00";
	--Update value to 4'b0011 if coherent accesses to be used via the Zynq ACP port. Not Allocated, Modifiable, not Bufferable. Not Bufferable since this example is meant to test memory, not intermediate cache.
	M_AXI_ARCACHE	<= "0010";
	M_AXI_ARPROT	<= "000";
	M_AXI_ARVALID	<= axi_arvalid;
	--Read and Read Response (R)
	M_AXI_RREADY	<= axi_rready;
	-- transfer done status
	w_done <= wdone;
	r_done <= rdone_ff;
	r_d <= rod;
	ERROR <= write_resp_error;

	----------------------
	-- Detection of transaction request
	----------------------

	process(M_AXI_ACLK)
	begin
		if rising_edge(M_AXI_ACLK) then
			init_read_ff <= init_read_ff;
			init_write_ff <= init_write_ff;
			if M_AXI_ARESETN = '0' then
				init_read_ff <= '0';
				init_write_ff <= '0';
			else
				init_read_ff <= r;
				init_write_ff <= w;
			end if;
		end if;
	end process;

	----------------------
	-- Write Channels
	----------------------

	init_write <= (not init_write_ff) and w and not axi_awvalid_ff and not axi_wvalid;
	axi_awaddr(31 downto 2) <= a(31 downto 2);
	axi_awaddr(1 downto 0) <= "00";
	axi_awvalid <= M_AXI_ARESETN and (init_write or axi_awvalid_ff) and not axi_wvalid;
	wdone <= (axi_bready and M_AXI_BVALID) or (init_write_ff and wdone_ff);

	process(M_AXI_ACLK)
	begin
		if rising_edge(M_AXI_ACLK) then
			if (M_AXI_ARESETN = '0') then
				axi_awvalid_ff <= '0';
				axi_wvalid <= '0';
				axi_wlast <= '0';
				axi_bready <= '0';
				axi_wdata <= (others => '0');
				axi_wstrb <= (others => '0');
				write_resp_error <= '0';
				wdone_ff <= '0';
			else
				axi_awvalid_ff <= axi_awvalid;
				axi_wvalid <= axi_wvalid;
				axi_wlast <= axi_wlast;
				axi_bready <= axi_bready;
				axi_wdata <= axi_wdata;
				axi_wstrb <= axi_wstrb;
				write_resp_error <= write_resp_error;
				wdone_ff <= wdone;
				if axi_awvalid = '1' and M_AXI_AWREADY = '1' then
					-- send data
					axi_wvalid <= '1';
					axi_wlast <= '1';
					-- enforce big endian writes
					if a(1) = '0' then
						-- address ends with 00
						axi_wdata(31 downto 16) <= x"0000";
						axi_wdata(15 downto 8) <= w_d(7 downto 0);
						axi_wdata(7 downto 0) <= w_d(15 downto 8);
						axi_wstrb(3 downto 2) <= "00";
						axi_wstrb(1) <= ds(0);
						axi_wstrb(0) <= ds(1);
					else
						-- address ends with 10
						axi_wdata(31 downto 24) <= w_d(7 downto 0);
						axi_wdata(23 downto 16) <= w_d(15 downto 8);
						axi_wdata(15 downto 0) <= x"0000";
						axi_wstrb(3) <= ds(0);
						axi_wstrb(2) <= ds(1);
						axi_wstrb(1 downto 0) <= "00";
					end if;
				end if;
				if axi_wvalid = '1' and M_AXI_WREADY = '1' then
					-- data received, now we wait for response
					axi_wvalid <= '0';
					axi_wlast <= '0';
					axi_bready <= '1';
					axi_wdata <= (others => '0');
					axi_wstrb <= (others => '0');
				end if;
				if axi_bready = '1' and M_AXI_BVALID = '1' then
					-- write response received
					if M_AXI_BRESP(1) = '1' then
						write_resp_error <= '1';
					end if;
					axi_bready <= '0';
				end if;
			end if;
		end if;
	end process;


	------------------------------
	-- Read Channels
	------------------------------
	init_read <= (not init_read_ff) and r and not axi_arvalid_ff;
	axi_araddr(31 downto 2) <= a(31 downto 2);
	axi_araddr(1 downto 0) <= "00";
	axi_arvalid <= M_AXI_ARESETN and (init_read or axi_arvalid_ff) and not axi_rready;
	rdone <= (axi_rready and M_AXI_RVALID) or (r and rdone_ff);
	rod <= rdata_ff;

	rdata(15 downto 8) <= (7 downto 0 => ds_rd(1)) and ((M_AXI_RDATA(7 downto 0) and (7 downto 0 => not a1_rd)) or (M_AXI_RDATA(23 downto 16) and (7 downto 0 => a1_rd)));
	rdata(7 downto 0) <= (7 downto 0 => ds_rd(0)) and ((M_AXI_RDATA(15 downto 8) and (7 downto 0 => not a1_rd)) or (M_AXI_RDATA(31 downto 24) and (7 downto 0 => a1_rd)));

	process(M_AXI_ACLK)
	begin
		if rising_edge(M_AXI_ACLK) then
			if (M_AXI_ARESETN = '0') then
				axi_arvalid_ff <= '0';
				axi_rready <= '0';
				rdata_ff <= (others => '1');
				rdone_ff <= '0';
				ds_rd <= "00";
				a1_rd <= '0';
			else
				axi_arvalid_ff <= axi_arvalid;
				axi_rready <= axi_rready;
				rdone_ff <= rdone;
				rdata_ff <= rdata_ff;
				if axi_arvalid = '1' and M_AXI_ARREADY = '1' then
					axi_rready <= '1';
				end if;
				if axi_rready = '1' and M_AXI_RVALID = '1' then
					rdata_ff <= rdata;
					axi_rready <= '0';
				end if;
				if init_read = '1' then
					ds_rd <= ds;
					a1_rd <= a(1);
				end if;
			end if;
		end if;
	end process;


end implementation;
