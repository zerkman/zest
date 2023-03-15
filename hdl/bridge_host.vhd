-- bridge_host.vhd - bridge bus host with AXI4-Lite control interface
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

entity bridge_host is
	generic (
		DATA_WIDTH_BITS	: integer := 5;		-- log2(width of data bus)
		ADDR_WIDTH		: integer := 16		-- Width of address bus (S_AXI and bridge)
	);
	port (
		-- Global Clock Signal
		s_axi_aclk		: in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		s_axi_aresetn	: in std_logic;
		-- Write address (issued by master, acceped by Slave)
		s_axi_awaddr	: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. This signal indicates the
		-- privilege and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		s_axi_awprot	: in std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that the master signaling
		-- valid write address and control information.
		s_axi_awvalid	: in std_logic;
		-- Write address ready. This signal indicates that the slave is ready
		-- to accept an address and associated control signals.
		s_axi_awready	: out std_logic;
		-- Write data (issued by master, acceped by Slave)
		s_axi_wdata		: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		-- Write strobes. This signal indicates which byte lanes hold
		-- valid data. There is one write strobe bit for each eight
		-- bits of the write data bus.
		s_axi_wstrb		: in std_logic_vector((2**DATA_WIDTH_BITS/8)-1 downto 0);
		-- Write valid. This signal indicates that valid write
		-- data and strobes are available.
		s_axi_wvalid	: in std_logic;
		-- Write ready. This signal indicates that the slave
		-- can accept the write data.
		s_axi_wready	: out std_logic;
		-- Write response. This signal indicates the status
		-- of the write transaction.
		s_axi_bresp		: out std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the channel
		-- is signaling a valid write response.
		s_axi_bvalid	: out std_logic;
		-- Response ready. This signal indicates that the master
		-- can accept a write response.
		s_axi_bready	: in std_logic;
		-- Read address (issued by master, acceped by Slave)
		s_axi_araddr	: in std_logic_vector(ADDR_WIDTH-1 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether the
		-- transaction is a data access or an instruction access.
		s_axi_arprot	: in std_logic_vector(2 downto 0);
		-- Read address valid. This signal indicates that the channel
		-- is signaling valid read address and control information.
		s_axi_arvalid	: in std_logic;
		-- Read address ready. This signal indicates that the slave is
		-- ready to accept an address and associated control signals.
		s_axi_arready	: out std_logic;
		-- Read data (issued by slave)
		s_axi_rdata		: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		-- Read response. This signal indicates the status of the
		-- read transfer.
		s_axi_rresp		: out std_logic_vector(1 downto 0);
		-- Read valid. This signal indicates that the channel is
		-- signaling the required read data.
		s_axi_rvalid	: out std_logic;
		-- Read ready. This signal indicates that the master can
		-- accept the read data and response information.
		s_axi_rready	: in std_logic;

		-- bridge host signals
		bridge_addr		: out std_logic_vector(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
		bridge_r		: out std_logic;
		bridge_r_data	: in std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w		: out std_logic;
		bridge_w_data	: out std_logic_vector(2**DATA_WIDTH_BITS-1 downto 0);
		bridge_w_strb	: out std_logic_vector(2**(DATA_WIDTH_BITS-3)-1 downto 0)
	);
end bridge_host;

architecture arch_imp of bridge_host is

	constant r_delay	: integer := 2;
	signal r_delay_cnt	: integer range 0 to r_delay-1;
	signal rvalid		: std_logic;

	type axi_st_t is ( IDLE, WR, RD, RD1 );
	signal axi_st		: axi_st_t;

begin
	s_axi_bresp <= "00";	-- no write error
	s_axi_rresp <= "00";	-- OKAY response

	process(axi_st,s_axi_awvalid,s_axi_wvalid,s_axi_awaddr,s_axi_wdata,s_axi_wstrb,
			s_axi_arvalid,s_axi_araddr,bridge_r_data)
	begin
		s_axi_awready <= '0';
		s_axi_wready <= '0';
		s_axi_bvalid <= '0';
		bridge_addr <= (others => '1');
		bridge_w <= '0';
		bridge_w_data <= (others => '1');
		bridge_w_strb <= (others => '1');
		bridge_r <= '0';
		s_axi_arready <= '0';

		if axi_st = IDLE then
			if s_axi_awvalid = '1' and s_axi_wvalid = '1' then
				s_axi_awready <= '1';
				s_axi_wready <= '1';
				s_axi_bvalid <= '1';
				bridge_addr <= s_axi_awaddr(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
				bridge_w <= '1';
				bridge_w_data <= s_axi_wdata;
				bridge_w_strb <= s_axi_wstrb;
			elsif s_axi_arvalid = '1' then
				s_axi_arready <= '1';
				bridge_addr <= s_axi_araddr(ADDR_WIDTH-1 downto DATA_WIDTH_BITS-3);
				bridge_r <= '1';
			end if;
		end if;
		if axi_st = WR then
			s_axi_bvalid <= '1';
		end if;
	end process;

	s_axi_rvalid <= rvalid;
	s_axi_rdata <= bridge_r_data when rvalid = '1' else (others => '1');
	process(s_axi_aclk,s_axi_aresetn)
	begin
		if s_axi_aresetn = '0' then
			axi_st <= IDLE;
			r_delay_cnt <= 0;
			rvalid <= '0';
		elsif rising_edge(s_axi_aclk) then
			case axi_st is
				when IDLE =>
					if s_axi_awvalid = '1' and s_axi_wvalid = '1' and s_axi_bready = '0' then
						-- maintain bvalid as long as bready is not set
						axi_st <= WR;
					elsif s_axi_arvalid = '1' then
						r_delay_cnt <= r_delay-1;
						axi_st <= RD;
					end if;

				when WR =>
					if s_axi_bready = '1' then
						axi_st <= IDLE;
					end if;

				when RD =>
					if r_delay_cnt > 0 then
						r_delay_cnt <= r_delay_cnt - 1;
					else
						rvalid <= '1';
						axi_st <= RD1;
					end if;

				when RD1 =>
					if s_axi_rready = '1' then
						rvalid <= '0';
						axi_st <= IDLE;
					end if;

			end case;
		end if;
	end process;



end arch_imp;
