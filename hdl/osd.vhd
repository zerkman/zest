-- osd.vhd - On-screen text display
--
-- Copyright (c) 2022,2023 Francois Galea <fgalea at free.fr>
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

-- This module implements a memory-mappable buffer of 1024 32bit words.
-- The address space is as follows:
-- 0x000-0x00f: configuration registers
-- 0x010-0x0ff: character colours (foreground and background)
-- 0x100-0x3ff: characters (first is the rightmost one)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.all;

entity on_screen_display is
	generic (
		-- Width of S_AXI data bus
		DATA_WIDTH : integer := 32;
		-- Width of S_AXI address bus
		ADDR_WIDTH : integer := 12
	);
	port (
		-- Global Clock Signal
		s_axi_aclk      : in std_logic;
		-- Global Reset Signal. This Signal is Active LOW
		s_axi_aresetn   : in std_logic;
		-- Write address (issued by master, acceped by Slave)
		s_axi_awaddr    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		-- Write channel Protection type. This signal indicates the
		-- privilege and security level of the transaction, and whether
		-- the transaction is a data access or an instruction access.
		s_axi_awprot    : in std_logic_vector(2 downto 0);
		-- Write address valid. This signal indicates that the master signaling
		-- valid write address and control information.
		s_axi_awvalid   : in std_logic;
		-- Write address ready. This signal indicates that the slave is ready
		-- to accept an address and associated control signals.
		s_axi_awready   : out std_logic;
		-- Write data (issued by master, acceped by Slave)
		s_axi_wdata     : in std_logic_vector(DATA_WIDTH-1 downto 0);
		-- Write strobes. This signal indicates which byte lanes hold
		-- valid data. There is one write strobe bit for each eight
		-- bits of the write data bus.
		s_axi_wstrb     : in std_logic_vector((DATA_WIDTH/8)-1 downto 0);
		-- Write valid. This signal indicates that valid write
		-- data and strobes are available.
		s_axi_wvalid    : in std_logic;
		-- Write ready. This signal indicates that the slave
		-- can accept the write data.
		s_axi_wready    : out std_logic;
		-- Write response. This signal indicates the status
		-- of the write transaction.
		s_axi_bresp     : out std_logic_vector(1 downto 0);
		-- Write response valid. This signal indicates that the channel
		-- is signaling a valid write response.
		s_axi_bvalid    : out std_logic;
		-- Response ready. This signal indicates that the master
		-- can accept a write response.
		s_axi_bready    : in std_logic;
		-- Read address (issued by master, acceped by Slave)
		s_axi_araddr    : in std_logic_vector(ADDR_WIDTH-1 downto 0);
		-- Protection type. This signal indicates the privilege
		-- and security level of the transaction, and whether the
		-- transaction is a data access or an instruction access.
		s_axi_arprot    : in std_logic_vector(2 downto 0);
		-- Read address valid. This signal indicates that the channel
		-- is signaling valid read address and control information.
		s_axi_arvalid   : in std_logic;
		-- Read address ready. This signal indicates that the slave is
		-- ready to accept an address and associated control signals.
		s_axi_arready   : out std_logic;
		-- Read data (issued by slave)
		s_axi_rdata     : out std_logic_vector(DATA_WIDTH-1 downto 0);
		-- Read response. This signal indicates the status of the
		-- read transfer.
		s_axi_rresp     : out std_logic_vector(1 downto 0);
		-- Read valid. This signal indicates that the channel is
		-- signaling the required read data.
		s_axi_rvalid    : out std_logic;
		-- Read ready. This signal indicates that the master can
		-- accept the read data and response information.
		s_axi_rready    : in std_logic;

		-- video signals
		pclk   : in std_logic;
		idata  : in std_logic_vector(15 downto 0);
		ivsync : in std_logic;
		ihsync : in std_logic;
		ide    : in std_logic;
		odata  : out std_logic_vector(15 downto 0);
		ovsync : out std_logic;
		ohsync : out std_logic;
		ode    : out std_logic;

		intr   : out std_logic
	);
end on_screen_display;

architecture arch_imp of on_screen_display is

	type axi_st_t is ( IDLE, WR, RD, RD1, RD2 );
	signal axi_st       : axi_st_t;

	-- Example-specific design signals
	-- local parameter for addressing 32 bit / 64 bit DATA_WIDTH
	-- ADDR_LSB is used for addressing 32/64 bit registers/memories
	-- ADDR_LSB = 2 for 32 bits (n downto 2)
	-- ADDR_LSB = 3 for 64 bits (n downto 3)
	constant ADDR_LSB	: integer := (DATA_WIDTH/32)+1;
	-- address bits are in range (ADDR_MSB downto ADDR_LSB)
	constant ADDR_MSB	: integer := ADDR_WIDTH-1;

	-- RAM signals
	signal ram_addr1 : std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_addr2 : std_logic_vector(ADDR_MSB-ADDR_LSB downto 0);
	signal ram_din1  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal ram_din2  : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal ram_wsb1  : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
	signal ram_wsb2  : std_logic_vector((DATA_WIDTH/8)-1 downto 0);
	signal ram_dout1 : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal ram_dout2 : std_logic_vector(DATA_WIDTH-1 downto 0);
	signal ram_we1   : std_logic;
	signal ram_we2   : std_logic;
	signal ram_re1   : std_logic;
	signal ram_re2   : std_logic;

	-- Bitmap font
	type font_t is array (0 to (256*8)-1) of std_logic_vector(7 downto 0);
	constant font : font_t := (
		x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",  -- 0
		x"18",x"3c",x"66",x"c3",x"e7",x"24",x"24",x"3c",  -- 1
		x"3c",x"24",x"24",x"e7",x"c3",x"66",x"3c",x"18",  -- 2
		x"18",x"1c",x"f6",x"83",x"83",x"f6",x"1c",x"18",  -- 3
		x"18",x"38",x"6f",x"c1",x"c1",x"6f",x"38",x"18",  -- 4
		x"3c",x"99",x"c3",x"e7",x"c3",x"99",x"3c",x"00",  -- 5
		x"ff",x"ff",x"fe",x"fc",x"f9",x"f3",x"e7",x"00",  -- 6
		x"e7",x"c3",x"99",x"3c",x"99",x"c3",x"e7",x"00",  -- 7
		x"01",x"03",x"06",x"8c",x"d8",x"70",x"20",x"00",  -- 8
		x"7e",x"c3",x"d3",x"d3",x"db",x"c3",x"c3",x"7e",  -- 9
		x"18",x"3c",x"3c",x"3c",x"7e",x"10",x"38",x"10",  -- 10
		x"18",x"1c",x"16",x"10",x"10",x"70",x"f0",x"60",  -- 11
		x"f0",x"c0",x"fe",x"d8",x"de",x"18",x"18",x"00",  -- 12
		x"f0",x"c0",x"df",x"db",x"ff",x"1e",x"1b",x"00",  -- 13
		x"05",x"05",x"05",x"0d",x"0d",x"19",x"79",x"71",  -- 14
		x"a0",x"a0",x"a0",x"b0",x"b0",x"98",x"9e",x"8e",  -- 15
		x"7c",x"c6",x"c6",x"00",x"c6",x"c6",x"7c",x"00",  -- 16
		x"06",x"06",x"06",x"00",x"06",x"06",x"06",x"00",  -- 17
		x"7c",x"06",x"06",x"7c",x"c0",x"c0",x"7c",x"00",  -- 18
		x"7c",x"06",x"06",x"7c",x"06",x"06",x"7c",x"00",  -- 19
		x"c6",x"c6",x"c6",x"7c",x"06",x"06",x"06",x"00",  -- 20
		x"7c",x"c0",x"c0",x"7c",x"06",x"06",x"7c",x"00",  -- 21
		x"7c",x"c0",x"c0",x"7c",x"c6",x"c6",x"7c",x"00",  -- 22
		x"7c",x"06",x"06",x"00",x"06",x"06",x"06",x"00",  -- 23
		x"7c",x"c6",x"c6",x"7c",x"c6",x"c6",x"7c",x"00",  -- 24
		x"7c",x"c6",x"c6",x"7c",x"06",x"06",x"7c",x"00",  -- 25
		x"00",x"00",x"3c",x"06",x"7e",x"66",x"3c",x"00",  -- 26
		x"78",x"60",x"78",x"60",x"7e",x"18",x"1e",x"00",  -- 27
		x"07",x"0f",x"1f",x"18",x"18",x"10",x"1e",x"17",  -- 28
		x"f0",x"f8",x"ec",x"04",x"04",x"04",x"3c",x"54",  -- 29
		x"11",x"0b",x"0d",x"06",x"07",x"2e",x"39",x"38",  -- 30
		x"04",x"28",x"d8",x"28",x"d0",x"10",x"e0",x"00",  -- 31
		x"00",x"00",x"00",x"00",x"00",x"00",x"00",x"00",  -- 32
		x"18",x"18",x"18",x"18",x"18",x"00",x"18",x"00",  -- 33
		x"66",x"66",x"66",x"00",x"00",x"00",x"00",x"00",  -- 34
		x"00",x"6c",x"fe",x"6c",x"6c",x"fe",x"6c",x"00",  -- 35
		x"18",x"3e",x"60",x"3c",x"06",x"7c",x"18",x"00",  -- 36
		x"00",x"66",x"6c",x"18",x"30",x"66",x"46",x"00",  -- 37
		x"38",x"6c",x"38",x"70",x"de",x"cc",x"76",x"00",  -- 38
		x"18",x"18",x"18",x"00",x"00",x"00",x"00",x"00",  -- 39
		x"0e",x"1c",x"18",x"18",x"18",x"1c",x"0e",x"00",  -- 40
		x"70",x"38",x"18",x"18",x"18",x"38",x"70",x"00",  -- 41
		x"00",x"66",x"3c",x"ff",x"3c",x"66",x"00",x"00",  -- 42
		x"00",x"18",x"18",x"7e",x"18",x"18",x"00",x"00",  -- 43
		x"00",x"00",x"00",x"00",x"00",x"30",x"30",x"60",  -- 44
		x"00",x"00",x"00",x"7e",x"00",x"00",x"00",x"00",  -- 45
		x"00",x"00",x"00",x"00",x"00",x"18",x"18",x"00",  -- 46
		x"02",x"06",x"0c",x"18",x"30",x"60",x"40",x"00",  -- 47
		x"3c",x"66",x"6e",x"76",x"66",x"66",x"3c",x"00",  -- 48
		x"18",x"38",x"18",x"18",x"18",x"18",x"7e",x"00",  -- 49
		x"3c",x"66",x"06",x"0c",x"18",x"30",x"7e",x"00",  -- 50
		x"7e",x"0c",x"18",x"0c",x"06",x"66",x"3c",x"00",  -- 51
		x"0c",x"1c",x"3c",x"6c",x"7e",x"0c",x"0c",x"00",  -- 52
		x"7e",x"60",x"7c",x"06",x"06",x"66",x"3c",x"00",  -- 53
		x"3c",x"60",x"60",x"7c",x"66",x"66",x"3c",x"00",  -- 54
		x"7e",x"06",x"0c",x"18",x"30",x"30",x"30",x"00",  -- 55
		x"3c",x"66",x"66",x"3c",x"66",x"66",x"3c",x"00",  -- 56
		x"3c",x"66",x"66",x"3e",x"06",x"0c",x"38",x"00",  -- 57
		x"00",x"18",x"18",x"00",x"18",x"18",x"00",x"00",  -- 58
		x"00",x"18",x"18",x"00",x"18",x"18",x"30",x"00",  -- 59
		x"06",x"0c",x"18",x"30",x"18",x"0c",x"06",x"00",  -- 60
		x"00",x"00",x"7e",x"00",x"00",x"7e",x"00",x"00",  -- 61
		x"60",x"30",x"18",x"0c",x"18",x"30",x"60",x"00",  -- 62
		x"3c",x"66",x"06",x"0c",x"18",x"00",x"18",x"00",  -- 63
		x"3c",x"66",x"6e",x"6a",x"6e",x"60",x"3e",x"00",  -- 64
		x"18",x"3c",x"66",x"66",x"7e",x"66",x"66",x"00",  -- 65
		x"7c",x"66",x"66",x"7c",x"66",x"66",x"7c",x"00",  -- 66
		x"3c",x"66",x"60",x"60",x"60",x"66",x"3c",x"00",  -- 67
		x"78",x"6c",x"66",x"66",x"66",x"6c",x"78",x"00",  -- 68
		x"7e",x"60",x"60",x"7c",x"60",x"60",x"7e",x"00",  -- 69
		x"7e",x"60",x"60",x"7c",x"60",x"60",x"60",x"00",  -- 70
		x"3e",x"60",x"60",x"6e",x"66",x"66",x"3e",x"00",  -- 71
		x"66",x"66",x"66",x"7e",x"66",x"66",x"66",x"00",  -- 72
		x"3c",x"18",x"18",x"18",x"18",x"18",x"3c",x"00",  -- 73
		x"06",x"06",x"06",x"06",x"06",x"66",x"3c",x"00",  -- 74
		x"66",x"6c",x"78",x"70",x"78",x"6c",x"66",x"00",  -- 75
		x"60",x"60",x"60",x"60",x"60",x"60",x"7e",x"00",  -- 76
		x"c6",x"ee",x"fe",x"d6",x"c6",x"c6",x"c6",x"00",  -- 77
		x"66",x"76",x"7e",x"7e",x"6e",x"66",x"66",x"00",  -- 78
		x"3c",x"66",x"66",x"66",x"66",x"66",x"3c",x"00",  -- 79
		x"7c",x"66",x"66",x"7c",x"60",x"60",x"60",x"00",  -- 80
		x"3c",x"66",x"66",x"66",x"76",x"6c",x"36",x"00",  -- 81
		x"7c",x"66",x"66",x"7c",x"6c",x"66",x"66",x"00",  -- 82
		x"3c",x"66",x"60",x"3c",x"06",x"66",x"3c",x"00",  -- 83
		x"7e",x"18",x"18",x"18",x"18",x"18",x"18",x"00",  -- 84
		x"66",x"66",x"66",x"66",x"66",x"66",x"3e",x"00",  -- 85
		x"66",x"66",x"66",x"66",x"66",x"3c",x"18",x"00",  -- 86
		x"c6",x"c6",x"c6",x"d6",x"fe",x"ee",x"c6",x"00",  -- 87
		x"66",x"66",x"3c",x"18",x"3c",x"66",x"66",x"00",  -- 88
		x"66",x"66",x"66",x"3c",x"18",x"18",x"18",x"00",  -- 89
		x"7e",x"06",x"0c",x"18",x"30",x"60",x"7e",x"00",  -- 90
		x"1e",x"18",x"18",x"18",x"18",x"18",x"1e",x"00",  -- 91
		x"40",x"60",x"30",x"18",x"0c",x"06",x"02",x"00",  -- 92
		x"78",x"18",x"18",x"18",x"18",x"18",x"78",x"00",  -- 93
		x"10",x"38",x"6c",x"c6",x"00",x"00",x"00",x"00",  -- 94
		x"00",x"00",x"00",x"00",x"00",x"00",x"fe",x"00",  -- 95
		x"00",x"c0",x"60",x"30",x"00",x"00",x"00",x"00",  -- 96
		x"00",x"00",x"3c",x"06",x"3e",x"66",x"3e",x"00",  -- 97
		x"60",x"60",x"7c",x"66",x"66",x"66",x"7c",x"00",  -- 98
		x"00",x"00",x"3c",x"60",x"60",x"60",x"3c",x"00",  -- 99
		x"06",x"06",x"3e",x"66",x"66",x"66",x"3e",x"00",  -- 100
		x"00",x"00",x"3c",x"66",x"7e",x"60",x"3c",x"00",  -- 101
		x"1c",x"30",x"7c",x"30",x"30",x"30",x"30",x"00",  -- 102
		x"00",x"00",x"3e",x"66",x"66",x"3e",x"06",x"7c",  -- 103
		x"60",x"60",x"7c",x"66",x"66",x"66",x"66",x"00",  -- 104
		x"18",x"00",x"38",x"18",x"18",x"18",x"3c",x"00",  -- 105
		x"18",x"00",x"18",x"18",x"18",x"18",x"18",x"70",  -- 106
		x"60",x"60",x"66",x"6c",x"78",x"6c",x"66",x"00",  -- 107
		x"38",x"18",x"18",x"18",x"18",x"18",x"3c",x"00",  -- 108
		x"00",x"00",x"ec",x"fe",x"d6",x"c6",x"c6",x"00",  -- 109
		x"00",x"00",x"7c",x"66",x"66",x"66",x"66",x"00",  -- 110
		x"00",x"00",x"3c",x"66",x"66",x"66",x"3c",x"00",  -- 111
		x"00",x"00",x"7c",x"66",x"66",x"66",x"7c",x"60",  -- 112
		x"00",x"00",x"3e",x"66",x"66",x"66",x"3e",x"06",  -- 113
		x"00",x"00",x"7c",x"66",x"60",x"60",x"60",x"00",  -- 114
		x"00",x"00",x"3e",x"60",x"3c",x"06",x"7c",x"00",  -- 115
		x"00",x"18",x"7e",x"18",x"18",x"18",x"0e",x"00",  -- 116
		x"00",x"00",x"66",x"66",x"66",x"66",x"3e",x"00",  -- 117
		x"00",x"00",x"66",x"66",x"66",x"3c",x"18",x"00",  -- 118
		x"00",x"00",x"c6",x"c6",x"d6",x"7c",x"6c",x"00",  -- 119
		x"00",x"00",x"66",x"3c",x"18",x"3c",x"66",x"00",  -- 120
		x"00",x"00",x"66",x"66",x"66",x"3e",x"06",x"7c",  -- 121
		x"00",x"00",x"7e",x"0c",x"18",x"30",x"7e",x"00",  -- 122
		x"0e",x"18",x"18",x"30",x"18",x"18",x"0e",x"00",  -- 123
		x"18",x"18",x"18",x"18",x"18",x"18",x"18",x"18",  -- 124
		x"70",x"18",x"18",x"0c",x"18",x"18",x"70",x"00",  -- 125
		x"00",x"60",x"f2",x"9e",x"0c",x"00",x"00",x"00",  -- 126
		x"00",x"18",x"18",x"34",x"34",x"62",x"7e",x"00",  -- 127
		x"00",x"3c",x"66",x"60",x"66",x"3c",x"08",x"38",  -- 128
		x"66",x"00",x"00",x"66",x"66",x"66",x"3e",x"00",  -- 129
		x"0c",x"18",x"00",x"3c",x"7e",x"60",x"3c",x"00",  -- 130
		x"18",x"66",x"00",x"3c",x"06",x"7e",x"3e",x"00",  -- 131
		x"66",x"00",x"3c",x"06",x"3e",x"66",x"3e",x"00",  -- 132
		x"30",x"18",x"00",x"3c",x"06",x"7e",x"3e",x"00",  -- 133
		x"18",x"18",x"00",x"3c",x"06",x"7e",x"3e",x"00",  -- 134
		x"00",x"00",x"3c",x"60",x"60",x"3c",x"08",x"18",  -- 135
		x"18",x"66",x"00",x"3c",x"7e",x"60",x"3c",x"00",  -- 136
		x"66",x"00",x"3c",x"66",x"7e",x"60",x"3c",x"00",  -- 137
		x"30",x"18",x"00",x"3c",x"7e",x"60",x"3c",x"00",  -- 138
		x"66",x"00",x"00",x"38",x"18",x"18",x"3c",x"00",  -- 139
		x"18",x"66",x"00",x"38",x"18",x"18",x"3c",x"00",  -- 140
		x"60",x"30",x"00",x"38",x"18",x"18",x"3c",x"00",  -- 141
		x"66",x"00",x"18",x"3c",x"66",x"7e",x"66",x"00",  -- 142
		x"18",x"00",x"18",x"3c",x"66",x"7e",x"66",x"00",  -- 143
		x"0c",x"18",x"7e",x"60",x"7c",x"60",x"7e",x"00",  -- 144
		x"00",x"00",x"7e",x"1b",x"7f",x"d8",x"7e",x"00",  -- 145
		x"3f",x"78",x"d8",x"de",x"f8",x"d8",x"df",x"00",  -- 146
		x"18",x"66",x"00",x"3c",x"66",x"66",x"3c",x"00",  -- 147
		x"66",x"00",x"00",x"3c",x"66",x"66",x"3c",x"00",  -- 148
		x"30",x"18",x"00",x"3c",x"66",x"66",x"3c",x"00",  -- 149
		x"18",x"66",x"00",x"66",x"66",x"66",x"3e",x"00",  -- 150
		x"30",x"18",x"00",x"66",x"66",x"66",x"3e",x"00",  -- 151
		x"66",x"00",x"66",x"66",x"66",x"3e",x"06",x"7c",  -- 152
		x"66",x"00",x"3c",x"66",x"66",x"66",x"3c",x"00",  -- 153
		x"66",x"00",x"66",x"66",x"66",x"66",x"3e",x"00",  -- 154
		x"18",x"18",x"3c",x"60",x"60",x"3c",x"18",x"18",  -- 155
		x"1c",x"3a",x"30",x"7c",x"30",x"30",x"7e",x"00",  -- 156
		x"66",x"66",x"3c",x"18",x"3c",x"18",x"18",x"00",  -- 157
		x"1c",x"36",x"66",x"7c",x"66",x"66",x"7c",x"60",  -- 158
		x"1e",x"30",x"7c",x"30",x"30",x"30",x"60",x"00",  -- 159
		x"0c",x"18",x"00",x"3c",x"06",x"7e",x"3e",x"00",  -- 160
		x"0c",x"18",x"00",x"38",x"18",x"18",x"3c",x"00",  -- 161
		x"0c",x"18",x"00",x"3c",x"66",x"66",x"3c",x"00",  -- 162
		x"0c",x"18",x"00",x"66",x"66",x"66",x"3e",x"00",  -- 163
		x"34",x"58",x"00",x"7c",x"66",x"66",x"66",x"00",  -- 164
		x"34",x"58",x"00",x"66",x"76",x"6e",x"66",x"00",  -- 165
		x"00",x"3c",x"06",x"3e",x"66",x"3e",x"00",x"3c",  -- 166
		x"00",x"3c",x"66",x"66",x"66",x"3c",x"00",x"3c",  -- 167
		x"00",x"18",x"00",x"18",x"30",x"60",x"66",x"3c",  -- 168
		x"00",x"00",x"00",x"3e",x"30",x"30",x"30",x"00",  -- 169
		x"00",x"00",x"00",x"7c",x"0c",x"0c",x"0c",x"00",  -- 170
		x"c6",x"cc",x"d8",x"36",x"6b",x"c3",x"86",x"0f",  -- 171
		x"c6",x"cc",x"d8",x"36",x"6e",x"d6",x"9f",x"06",  -- 172
		x"00",x"18",x"00",x"18",x"18",x"18",x"18",x"18",  -- 173
		x"1b",x"36",x"6c",x"d8",x"6c",x"36",x"1b",x"00",  -- 174
		x"d8",x"6c",x"36",x"1b",x"36",x"6c",x"d8",x"00",  -- 175
		x"34",x"58",x"00",x"3c",x"06",x"7e",x"3e",x"00",  -- 176
		x"34",x"58",x"00",x"3c",x"66",x"66",x"3c",x"00",  -- 177
		x"02",x"3c",x"66",x"6e",x"76",x"66",x"3c",x"40",  -- 178
		x"00",x"02",x"3c",x"6e",x"76",x"66",x"3c",x"40",  -- 179
		x"00",x"00",x"7e",x"db",x"df",x"d8",x"7e",x"00",  -- 180
		x"7f",x"d8",x"d8",x"de",x"d8",x"d8",x"7f",x"00",  -- 181
		x"30",x"18",x"00",x"18",x"3c",x"66",x"7e",x"66",  -- 182
		x"34",x"58",x"00",x"18",x"3c",x"66",x"7e",x"66",  -- 183
		x"34",x"58",x"3c",x"66",x"66",x"66",x"66",x"3c",  -- 184
		x"66",x"00",x"00",x"00",x"00",x"00",x"00",x"00",  -- 185
		x"0c",x"18",x"30",x"00",x"00",x"00",x"00",x"00",  -- 186
		x"00",x"10",x"38",x"10",x"10",x"10",x"00",x"00",  -- 187
		x"7a",x"ca",x"ca",x"ca",x"7a",x"0a",x"0a",x"0a",  -- 188
		x"7e",x"c3",x"bd",x"b1",x"b1",x"bd",x"c3",x"7e",  -- 189
		x"7e",x"c3",x"bd",x"a5",x"b9",x"ad",x"c3",x"7e",  -- 190
		x"f1",x"5b",x"5f",x"55",x"51",x"00",x"00",x"00",  -- 191
		x"66",x"00",x"e6",x"66",x"66",x"f6",x"06",x"1c",  -- 192
		x"f6",x"66",x"66",x"66",x"66",x"f6",x"06",x"1c",  -- 193
		x"00",x"66",x"76",x"3c",x"6e",x"66",x"00",x"00",  -- 194
		x"00",x"7c",x"0c",x"0c",x"0c",x"7e",x"00",x"00",  -- 195
		x"00",x"1e",x"06",x"0e",x"1e",x"36",x"00",x"00",  -- 196
		x"00",x"7e",x"0c",x"0c",x"0c",x"0c",x"00",x"00",  -- 197
		x"00",x"7c",x"06",x"66",x"66",x"66",x"00",x"00",  -- 198
		x"00",x"1c",x"0c",x"0c",x"0c",x"0c",x"00",x"00",  -- 199
		x"00",x"1e",x"0c",x"06",x"06",x"06",x"00",x"00",  -- 200
		x"00",x"7e",x"36",x"36",x"36",x"36",x"00",x"00",  -- 201
		x"60",x"6e",x"66",x"66",x"66",x"7e",x"00",x"00",  -- 202
		x"00",x"3c",x"0c",x"0c",x"00",x"00",x"00",x"00",  -- 203
		x"00",x"3e",x"06",x"06",x"06",x"3e",x"00",x"00",  -- 204
		x"60",x"7e",x"06",x"06",x"06",x"0e",x"00",x"00",  -- 205
		x"00",x"6c",x"3e",x"66",x"66",x"6e",x"00",x"00",  -- 206
		x"00",x"1c",x"0c",x"0c",x"0c",x"3c",x"00",x"00",  -- 207
		x"00",x"3e",x"36",x"36",x"36",x"1c",x"00",x"00",  -- 208
		x"00",x"36",x"36",x"36",x"36",x"7e",x"00",x"00",  -- 209
		x"00",x"7e",x"66",x"76",x"06",x"7e",x"00",x"00",  -- 210
		x"00",x"66",x"66",x"3c",x"0e",x"7e",x"00",x"00",  -- 211
		x"00",x"3e",x"06",x"36",x"36",x"34",x"30",x"00",  -- 212
		x"00",x"78",x"0c",x"0c",x"0c",x"0c",x"00",x"00",  -- 213
		x"00",x"d6",x"d6",x"d6",x"d6",x"fe",x"00",x"00",  -- 214
		x"00",x"7c",x"6c",x"6c",x"6c",x"ec",x"00",x"00",  -- 215
		x"00",x"1c",x"0c",x"0c",x"0c",x"0c",x"0c",x"00",  -- 216
		x"00",x"3e",x"06",x"06",x"06",x"06",x"06",x"00",  -- 217
		x"00",x"fe",x"66",x"66",x"66",x"7e",x"00",x"00",  -- 218
		x"00",x"7e",x"66",x"76",x"06",x"06",x"06",x"00",  -- 219
		x"00",x"36",x"36",x"1c",x"0c",x"0c",x"0c",x"00",  -- 220
		x"0e",x"1b",x"3c",x"66",x"66",x"3c",x"d8",x"70",  -- 221
		x"00",x"10",x"38",x"6c",x"c6",x"82",x"00",x"00",  -- 222
		x"66",x"f7",x"99",x"99",x"ef",x"66",x"00",x"00",  -- 223
		x"00",x"00",x"76",x"dc",x"c8",x"dc",x"76",x"00",  -- 224
		x"1c",x"36",x"66",x"7c",x"66",x"66",x"7c",x"60",  -- 225
		x"00",x"fe",x"66",x"62",x"60",x"60",x"60",x"f8",  -- 226
		x"00",x"00",x"fe",x"6c",x"6c",x"6c",x"6c",x"48",  -- 227
		x"fe",x"66",x"30",x"18",x"30",x"66",x"fe",x"00",  -- 228
		x"00",x"1e",x"38",x"6c",x"6c",x"6c",x"38",x"00",  -- 229
		x"00",x"00",x"6c",x"6c",x"6c",x"6c",x"7f",x"c0",  -- 230
		x"00",x"00",x"7e",x"18",x"18",x"18",x"18",x"10",  -- 231
		x"3c",x"18",x"3c",x"66",x"66",x"3c",x"18",x"3c",  -- 232
		x"00",x"3c",x"66",x"7e",x"66",x"66",x"3c",x"00",  -- 233
		x"00",x"3c",x"66",x"66",x"66",x"24",x"66",x"00",  -- 234
		x"1c",x"36",x"78",x"dc",x"cc",x"ec",x"78",x"00",  -- 235
		x"0c",x"18",x"38",x"54",x"54",x"38",x"30",x"60",  -- 236
		x"00",x"10",x"7c",x"d6",x"d6",x"d6",x"7c",x"10",  -- 237
		x"3e",x"70",x"60",x"7e",x"60",x"70",x"3e",x"00",  -- 238
		x"3c",x"66",x"66",x"66",x"66",x"66",x"66",x"00",  -- 239
		x"00",x"7e",x"00",x"7e",x"00",x"7e",x"00",x"00",  -- 240
		x"18",x"18",x"7e",x"18",x"18",x"00",x"7e",x"00",  -- 241
		x"30",x"18",x"0c",x"18",x"30",x"00",x"7e",x"00",  -- 242
		x"0c",x"18",x"30",x"18",x"0c",x"00",x"7e",x"00",  -- 243
		x"00",x"0e",x"1b",x"1b",x"18",x"18",x"18",x"18",  -- 244
		x"18",x"18",x"18",x"18",x"d8",x"d8",x"70",x"00",  -- 245
		x"18",x"18",x"00",x"7e",x"00",x"18",x"18",x"00",  -- 246
		x"00",x"32",x"4c",x"00",x"32",x"4c",x"00",x"00",  -- 247
		x"38",x"6c",x"38",x"00",x"00",x"00",x"00",x"00",  -- 248
		x"38",x"7c",x"38",x"00",x"00",x"00",x"00",x"00",  -- 249
		x"00",x"00",x"00",x"00",x"18",x"18",x"00",x"00",  -- 250
		x"00",x"00",x"0f",x"18",x"d8",x"70",x"30",x"00",  -- 251
		x"38",x"6c",x"6c",x"6c",x"6c",x"00",x"00",x"00",  -- 252
		x"38",x"6c",x"18",x"30",x"7c",x"00",x"00",x"00",  -- 253
		x"78",x"0c",x"38",x"0c",x"78",x"00",x"00",x"00",  -- 254
		x"00",x"fe",x"00",x"00",x"00",x"00",x"00",x"00"  -- 255
		);

	signal s_vsync   : std_logic;
	signal s_hsync   : std_logic;
	signal s_de      : std_logic;

	constant clr_offset : integer := 16;
	constant chr_offset : integer := 400;

	signal varcnt    : integer range 0 to 4;    -- variable load counter
	signal show      : std_logic;               -- show/hide the OSD
	signal xdstart   : integer range 0 to 4095; -- X display start (nb of pixels from the left border)
	signal ydstart   : integer range 0 to 4095; -- Y display start (nb of lines from the top border)
	signal xchars    : integer range 0 to 127;  -- number of characters per line
	signal ychars    : integer range 0 to 127;  -- number of lines of characters
	signal clrcnt    : integer range 0 to 5;    -- colours load counter
	type colr_t is array (0 to 3) of std_logic_vector(15 downto 0);
	signal colr      : colr_t;

	signal xcnt      : signed(12 downto 0); -- X pixel counter
	signal ycnt      : signed(12 downto 0); -- Y pixel counter
	signal pxok      : std_logic;

	signal cpx       : unsigned(2 downto 0);  -- X position of the pixel in the character grid
	signal cpy       : unsigned(3 downto 0);  -- Y position

	signal chrp      : integer range 0 to 2**(ADDR_WIDTH-1)-1;  -- character position
	signal clrp      : integer range 0 to 2**(ADDR_WIDTH-2)-1;  -- colours position
	signal transp    : std_logic;
	signal pix       : std_logic_vector(7 downto 0);
	signal cfg       : integer range 0 to 3;    -- foreground colour
	signal cbg       : integer range 0 to 3;    -- background colour

begin

	ram: entity ram_tdp
		generic map (
			DATA_WIDTH => DATA_WIDTH,
			ADDR_WIDTH => (ADDR_MSB-ADDR_LSB+1)
		)
		port map (
			clk1 => s_axi_aclk,
			clk2 => pclk,
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

	-- Implement AXI4-Lite access to the internal memory buffer.
	-- Reads and writes are not treated simultaneously, so the same RAM channel
	-- can be used for read and write, leaving the other channel to the
	-- OSD system.
	process(s_axi_aclk,s_axi_aresetn)
	begin
		if s_axi_aresetn = '0' then
			axi_st <= IDLE;
			s_axi_awready <= '0';
			s_axi_wready <= '0';
			s_axi_bvalid <= '0';
			s_axi_bresp <= "00";
			ram_addr1 <= (others => '0');
			ram_din1 <= (others => '0');
			ram_wsb1 <= (others => '0');
			ram_we1 <= '0';
			s_axi_arready <= '0';
			s_axi_rvalid <= '0';
			s_axi_rdata <= (others => '0');
			s_axi_rresp <= "00";
			ram_re1 <= '0';
		elsif rising_edge(s_axi_aclk) then
			case axi_st is
				when IDLE =>
					if s_axi_awvalid = '1' and s_axi_wvalid = '1' then
						s_axi_awready <= '1';
						s_axi_wready <= '1';
						s_axi_bvalid <= '1';
						s_axi_bresp <= "00";
						ram_addr1 <= s_axi_awaddr(ADDR_MSB downto ADDR_LSB);
						ram_din1 <= s_axi_wdata;
						ram_we1 <= '1';
						ram_wsb1 <= s_axi_wstrb;
						axi_st <= WR;
					elsif s_axi_arvalid = '1' then
						s_axi_arready <= '1';
						ram_addr1 <= s_axi_araddr(ADDR_MSB downto ADDR_LSB);
						ram_re1 <= '1';
						axi_st <= RD;
					end if;

				when WR =>
					s_axi_awready <= '0';
					s_axi_wready <= '0';
					ram_addr1 <= (others => '0');
					ram_din1 <= (others => '0');
					ram_we1 <= '0';
					ram_wsb1 <= (others => '0');
					if s_axi_bready = '1' then
						s_axi_bvalid <= '0';
						axi_st <= IDLE;
					end if;

				when RD =>
					s_axi_arready <= '0';
					ram_re1 <= '0';
					ram_addr1 <= (others => '0');
					axi_st <= RD1;

				when RD1 =>
					s_axi_rvalid <= '1';
					s_axi_rdata <= ram_dout1;
					s_axi_rresp <= "00";    -- OKAY response
					axi_st <= RD2;

				when RD2 =>
					if s_axi_rready = '1' then
						s_axi_rvalid <= '0';
						s_axi_rdata <= (others => '0');
						axi_st <= IDLE;
					end if;

			end case;
		end if;
	end process;

	-- video management
	ovsync <= s_vsync;
	ohsync <= s_hsync;
	ode <= s_de;
	cpx <= unsigned(xcnt(cpx'length-1 downto 0));
	cpy <= unsigned(ycnt(cpy'length-1 downto 0));

	process(pclk,s_axi_aresetn) is
		variable chrd    : std_logic_vector(15 downto 0);   -- character data
		variable chr     : integer range 0 to 255;          -- current character
		variable vs_busy : std_logic;

	begin
		if s_axi_aresetn = '0' then
			odata <= x"0000";
			s_vsync <= '0';
			s_hsync <= '0';
			s_de <= '0';
			xcnt <= to_signed(-xdstart,xcnt'length);
			ycnt <= to_signed(-ydstart,ycnt'length);
			pxok <= '0';
			intr <= '0';
			chrp <= chr_offset*2;
			transp <= '0';
			pix <= x"00";
			cfg <= 0;
			cbg <= 0;
			ram_re2 <= '0';
			ram_addr2 <= (others => '0');
			varcnt <= 0;
			show <= '0';
			xdstart <= 0;
			ydstart <= 0;
			xchars <= 0;
			ychars <= 0;
			clrp <= clr_offset;
			clrcnt <= 0;
		elsif rising_edge(pclk) then
			s_vsync <= ivsync;
			s_hsync <= ihsync;
			s_de <= ide;
			odata <= idata;
			vs_busy := '0';

			if ivsync = '1' and s_vsync = '0' then
				ycnt <= to_signed(-ydstart,ycnt'length);
				chrp <= chr_offset*2;
				clrp <= clr_offset;
				clrcnt <= 1;

				-- load variable values from the RAM
				vs_busy := '1';
				ram_addr2 <= (others => '0');
				ram_re2 <= '1';
				varcnt <= 1;
			elsif varcnt > 0 then
				vs_busy := '1';
				ram_addr2 <= std_logic_vector(unsigned(ram_addr2)+1);
				varcnt <= varcnt + 1;
				if varcnt = 2 then
					show <= ram_dout2(0);
				elsif varcnt = 3 then
					xchars <= to_integer(unsigned(ram_dout2(6 downto 0)));
					ychars <= to_integer(unsigned(ram_dout2(22 downto 16)));
					ram_addr2 <= (others => '0');
					ram_re2 <= '0';
				elsif varcnt = 4 then
					xdstart <= to_integer(unsigned(ram_dout2(11 downto 0)));
					ydstart <= to_integer(unsigned(ram_dout2(27 downto 16)));
					varcnt <= 0;
				end if;
			end if;

			if ihsync = '1' and s_hsync = '0' then
				xcnt <= to_signed(-xdstart,xcnt'length);
				if pxok = '1' then
					-- end of row with pixels
					ycnt <= ycnt + 1;
					intr <= '0';
					if ycnt+1 = ychars*8*2 then
						intr <= '1';
					end if;
					if ycnt >= 0 and ycnt < ychars*8*2 then
						if ycnt(3 downto 0) /= "1111" then
							chrp <= chrp - xchars;
						end if;
						if ycnt(0) = '1' then
							clrcnt <= 1;
						end if;
					end if;
				end if;
				pxok <= '0';
			elsif clrcnt > 0 and vs_busy = '0' then
				clrcnt <= clrcnt + 1;
				if clrcnt = 1 then
					ram_re2 <= '1';
					ram_addr2 <= std_logic_vector(to_unsigned(clrp,ram_addr2'length));
					clrp <= clrp + 1;
				elsif clrcnt = 2 then
					ram_addr2 <= std_logic_vector(to_unsigned(clrp,ram_addr2'length));
					clrp <= clrp + 1;
				elsif clrcnt = 3 then
					ram_addr2 <= (others => '0');
					ram_re2 <= '0';
					colr(0) <= ram_dout2(15 downto 0);
					colr(1) <= ram_dout2(31 downto 16);
				elsif clrcnt = 4 then
					colr(2) <= ram_dout2(15 downto 0);
					colr(3) <= ram_dout2(31 downto 16);
					clrcnt <= 0;
				end if;
			elsif ide = '1' and show = '1' then
				pxok <= '1';
				xcnt <= xcnt + 1;
				if xcnt >= -3 and xcnt < xchars*8 and ycnt >= 0 and ycnt < ychars*8*2 then
					if xcnt < xchars*8-3 then
						if xcnt(2 downto 0) = "101" then
							ram_re2 <= '1';
							ram_addr2 <= std_logic_vector(to_unsigned(chrp/2,ram_addr2'length));
						elsif xcnt(2 downto 0) = "110" then
							ram_re2 <= '0';
						elsif xcnt(2 downto 0) = "111" then
							chrd := ram_dout2((chrp mod 2)*16+15 downto (chrp mod 2)*16);
							chr := to_integer(unsigned(chrd(7 downto 0)));
							cfg <= to_integer(unsigned(chrd(9 downto 8)));
							cbg <= to_integer(unsigned(chrd(11 downto 10)));
							if chr = 0 then
								transp <= '1';
							else
								pix <= font(chr*8+to_integer(cpy)/2);
								transp <= '0';
							end if;
							chrp <= chrp + 1;
						end if;
					end if;
					if xcnt >= 0 and transp = '0' then
						if pix(7-to_integer(cpx)) = '1' then
							odata <= colr(cfg);
						else
							odata <= colr(cbg);
						end if;
					end if;
				end if;
			end if;
		end if;
	end process;



end arch_imp;
