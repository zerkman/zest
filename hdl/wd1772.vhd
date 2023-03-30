-- wd1772.vhd - Floppy disk controller
--
-- Copyright (c) 2020-2023 Francois Galea <fgalea at free.fr>
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

entity wd1772 is
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
end wd1772;

architecture behavioral of wd1772 is
	signal status	: std_logic_vector(7 downto 0);
	signal command	: std_logic_vector(7 downto 0);
	signal TR		: std_logic_vector(7 downto 0);
	signal SR		: std_logic_vector(7 downto 0);
	signal DR		: std_logic_vector(7 downto 0);
	signal DSR		: std_logic_vector(7 downto 0);
	signal sod		: std_logic_vector(7 downto 0);
	signal crc		: std_logic_vector(15 downto 0);
	signal ipcnt	: std_logic_vector(3 downto 0);
	signal delaycnt : unsigned(16 downto 0);
	signal ds_cnt	: unsigned(7 downto 0);		-- 7:5 => bit number, 4:0 => cycle counter
	signal ds_full	: std_logic;
	signal ipn_ff	: std_logic;
	signal DIR		: std_logic;
	type amd_t is ( init,am1,am2,am3 );
	signal amd_st	: amd_t;
	signal amd_cnt	: unsigned(1 downto 0);
	signal byte_cnt	: unsigned(4 downto 0);
	signal crc0		: std_logic_vector(7 downto 0);
	signal dat_btc	: unsigned(9 downto 0);		-- byte counter for sector read/write
	type cmd_t is (
		idle,idle1,
		c1_init,c1_wait_ip,c1_a,c1_b,c1_c,c1_step,c1_delay,c1_d,c1_vlp,c1_dtr,c1_dsi,c1_dse,c1_dsl,c1_dc1,c1_dc2,
		c2_init,c2_wait_ip,c2_delay,c2_4,c2_1,c2_1dtr,c2_1dsi,c2_1dse,c2_1dsl,c2_1dc1,c2_1dc2,
		c2_2,c2_2fb,c2_2nb,c2_2crc0,c2_2crc1,c2_5,
		c2_3,c2_3wt1,c2_3wt2,c2_3wt3,c2_3wr0,c2_3wram,c2_3wrdata,c2_3wrcrc1,c2_3wrcrc2,c2_3wrff,c2_3wrend,
		c3_init,c3_wl1,c3_wl2,
		c3_rdad,c3_rdad1,c3_rdad2,c3_rdad3,
		c3_rdtr,c3_rdtrwip,c3_rdtrlp,
		c3_wrtr,c3_wrtr1,c3_wrtrwip,c3_wrtr_a,c3_wrtr_b,c3_wrtrwb,c3_wrtrwb1,c3_wrtrwf5,c3_wrtrwcrc,
		c4_init,c4_wip,c4_trig
	);
	signal amd_dtam	: std_logic;	-- detected address mark
	signal cmd_st	: cmd_t;
	signal upd_crc	: std_logic;	-- 1 iff CRC is being updated
	signal wgs		: std_logic;	-- 1 iff writing to disk
	signal motor_on	: std_logic;
	signal spin_up	: std_logic;
begin

	MO <= motor_on;
	status(7) <= motor_on;
	WG <= wgs;
	DIRC <= DIR;
	oDAL <= sod when CSn = '0' and RWn = '1' else x"ff";

process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			status(6 downto 0) <= (others => '0');
			command <= (others => '0');
			TR <= (others => '0');
			SR <= (others => '0');
			DR <= (others => '0');
			DSR <= (others => '0');
			sod <= x"00";
			crc <= (others => '0');
			ds_cnt <= x"00";
			ds_full <= '0';
			ipcnt <= "0000";
			DIR <= '0';
			INTRQ <= '0';
			cmd_st <= idle;
			STEP <= '0';
			amd_st <= init;
			amd_dtam <= '0';
			upd_crc <= '0';
			byte_cnt <= (others => '0');
			delaycnt <= (others => '0');
			wgs <= '0';
			WD <= '0';
			motor_on <= '0';
			spin_up <= '0';
		elsif clken = '1' then
			ipn_ff <= IPn;
			-- index pulse detection and counter decrement
			if motor_on = '1' then
				if IPn = '0' and ipn_ff = '1' then
					if ipcnt /= x"0" then
						ipcnt <= std_logic_vector(unsigned(ipcnt) - 1);
					end if;
					-- sync data shift register load with index pulse
					ds_cnt <= x"01";
				else
					ds_cnt <= ds_cnt + 1;
				end if;
			end if;
			ds_full <= '0';
			if ds_cnt(4 downto 0) = "01111" then
				WD <= DSR(7);
				DSR <= DSR(6 downto 0) & not RDn;
				if upd_crc = '1' then
					if wgs = '1' then
						crc <= (crc(14 downto 0) & '0') xor (x"1021" and (15 downto 0 => (crc(15) xor DSR(7))));
					else
						crc <= (crc(14 downto 0) & '0') xor (x"1021" and (15 downto 0 => (crc(15) xor not RDn)));
					end if;
				end if;
				if ds_cnt(7 downto 5) = "111" then
					ds_full <= '1';
					if byte_cnt > 0 then
						byte_cnt <= byte_cnt - 1;
					end if;
				end if;
			end if;
			if ds_full = '1' then
				-- a full byte has been read
				amd_dtam <= '0';
				-- AM detection state machine
				case amd_st is
				when init =>
					amd_cnt <= to_unsigned(1,amd_cnt'length);
					amd_st <= am1;
				when am1 =>
					if DSR = x"4e" then
						if amd_cnt > 0 then
							amd_cnt <= amd_cnt - 1;
						end if;
					elsif DSR = x"00" and amd_cnt = 0 then
						amd_cnt <= to_unsigned(2,amd_cnt'length);
						amd_st <= am2;
					else
						amd_cnt <= to_unsigned(1,amd_cnt'length);
					end if;
				when am2 =>
					if DSR = x"00" then
						if amd_cnt > 0 then
							amd_cnt <= amd_cnt - 1;
						end if;
					elsif DSR = x"a1" and amd_cnt = 0 then
						amd_cnt <= to_unsigned(2,amd_cnt'length);
						amd_st <= am3;
						if upd_crc = '1' then
							crc <= x"cdb4";
						end if;
					else
						amd_st <= init;
					end if;
				when am3 =>
					if DSR = x"a1" then
						if upd_crc = '1' then
							crc <= x"cdb4";
						end if;
						amd_cnt <= amd_cnt - 1;
						if amd_cnt - 1 = 0 then
							amd_dtam <= '1';
							amd_st <= init;
						end if;
					else
						amd_st <= init;
					end if;
				end case;
			end if;

			-- host access to registers
			if CSn = '0' and RWn = '1' then
				case A is
					when "00" =>
						sod <= status;
						INTRQ <= '0';
					when "01" => sod <= TR;
					when "10" => sod <= SR;
					when "11" =>
						status(1) <= '0';	-- DRQ (S1)
						DRQ <= '0';
						sod <= DR;
					when others =>
				end case;
			elsif CSn = '0' and RWn = '0' then
				case A is
					when "00" =>
						command <= iDAL;
						if iDAL(7) = '0' then
							-- type I command
							cmd_st <= c1_init;
						elsif iDAL(6) = '0' then
							-- type II command
							cmd_st <= c2_init;
						elsif iDAL(5 downto 4) = "01" then
							-- type IV command
							cmd_st <= c4_init;
						else
							-- type III command
							cmd_st <= c3_init;
						end if;
					when "01" => TR <= iDAL;
					when "10" => SR <= iDAL;
					when "11" =>
						status(1) <= '0';	-- DRQ (S1)
						DRQ <= '0';
						DR <= iDAL;
					when others =>
				end case;
			end if;

			-- delay counter
			if delaycnt > 0 then
				delaycnt <= delaycnt - 1;
			end if;

			-- commands state machine
			case cmd_st is
			when idle =>
				if motor_on = '1' then
					-- motor is on: wait 9 floppy rotations before turning motor off
					ipcnt <= x"9";
					cmd_st <= idle1;
				end if;
			when idle1 =>
				if motor_on = '1' and ipcnt = x"0" then
					-- turn motor off after the specified number of rotations
					motor_on <= '0';
					spin_up <= '0';
				end if;
			when c1_init =>
				status(0) <= '1';	-- busy (S0)
				status(1) <= '0';	-- DRQ (S1)
				status(2) <= '0';	-- Track 0 (S2)
				status(3) <= '0';	-- CRC error (S3)
				status(4) <= '0';	-- seek error (S4)
				status(5) <= spin_up;
				DRQ <= '0';
				INTRQ <= '0';
				ipcnt <= x"0";
				if motor_on = '0' then
					-- motor on (S7)
					motor_on <= '1';
					ipcnt <= x"6";
				end if;
				cmd_st <= c1_wait_ip;
			when c1_wait_ip =>
				if ipcnt = x"0" then
					if command(3) = '0' then
						-- set spin-up (S5)
						spin_up <= '1';
						status(5) <= '1';
					end if;
					if command(6 downto 5) = "00" then
						-- seek or restore
						if command(4) = '0' then
							-- restore
							TR <= x"ff";
							DR <= x"00";
						end if;
						cmd_st <= c1_a;
					else
						-- step
						if command(6 downto 5) = "10" then
							-- step-in
							DIR <= '1';
						elsif command(6 downto 5) = "11" then
							-- step-out
							DIR <= '0';
						end if;
						if command(4) = '1' then
							cmd_st <= c1_b;
						else
							cmd_st <= c1_c;
						end if;
					end if;
				end if;
			when c1_a =>
				if TR = DR then
					cmd_st <= c1_d;
				else
					if DR > TR then
						DIR <= '1';
					else
						DIR <= '0';
					end if;
					cmd_st <= c1_b;
				end if;
			when c1_b =>
				if DIR = '1' then
					TR <= std_logic_vector(unsigned(TR) + 1);
				else
					TR <= std_logic_vector(unsigned(TR) - 1);
				end if;
				cmd_st <= c1_c;
			when c1_c =>
				if DIR = '0' and TR0n = '0' then
					TR <= x"00";
					cmd_st <= c1_d;
				else
					STEP <= '1';
					-- step pulse = 4 us
					delaycnt <= to_unsigned(32,delaycnt'length);
					cmd_st <= c1_step;
				end if;
			when c1_step =>
				if delaycnt = 0 then
					STEP <= '0';
					case command(1 downto 0) is
					when "00" =>
						-- 6 ms
						delaycnt <= to_unsigned(48000,delaycnt'length);
					when "01" =>
						-- 12 ms
						delaycnt <= to_unsigned(96000,delaycnt'length);
					when "10" =>
						-- 2 ms
						delaycnt <= to_unsigned(16000,delaycnt'length);
					when "11" =>
						-- 3 ms
						delaycnt <= to_unsigned(24000,delaycnt'length);
					when others =>
					end case;
					cmd_st <= c1_delay;
				end if;
			when c1_delay =>
				if delaycnt = 0 then
					if command(6 downto 5) /= "00" then
						-- step, step-in, step-out
						cmd_st <= c1_d;
					else
						-- seek or restore
						cmd_st <= c1_a;
					end if;
				end if;
			when c1_d =>
				status(2) <= not TR0n;	-- Track 0 (S2)
				if command(2) = '1' then
					ipcnt <= x"6";
					amd_st <= init;
					cmd_st <= c1_vlp;
				else
					INTRQ <= '1';
					status(0) <= '0';	-- reset busy
					cmd_st <= idle;
				end if;
			when c1_vlp =>
				upd_crc <= '1';
				if ipcnt = x"0" then
					-- 6 index holes have passed
					INTRQ <= '1';
					status(0) <= '0';	-- reset busy
					status(4) <= '1';	-- set seek error
					cmd_st <= idle;
				elsif amd_dtam = '1' and ds_full = '1' and DSR = x"fe" then
					-- ID address mark detected
					cmd_st <= c1_dtr;
				end if;
			when c1_dtr =>
				if ds_full = '1' then
					if DSR = TR then
						cmd_st <= c1_dsi;
					else
						cmd_st <= c1_vlp;
					end if;
				end if;
			when c1_dsi =>
				if ds_full = '1' then
					cmd_st <= c1_dse;
				end if;
			when c1_dse =>
				if ds_full = '1' then
					cmd_st <= c1_dsl;
				end if;
			when c1_dsl =>
				if ds_full = '1' then
					upd_crc <= '0';
					cmd_st <= c1_dc1;
				end if;
			when c1_dc1	=>
				if ds_full = '1' then
					crc0 <= DSR;
					cmd_st <= c1_dc2;
				end if;
			when c1_dc2	=>
				if ds_full = '1' then
					if crc0 & DSR = crc then
						status(3) <= '0';	-- CRC error (S3)
						status(0) <= '0';	-- reset busy
						INTRQ <= '1';
						cmd_st <= idle;
					else
						status(3) <= '1';	-- CRC error (S3)
						cmd_st <= c1_vlp;
					end if;
				end if;
			when c2_init =>
				status(0) <= '1';	-- busy
				status(1) <= '0';	-- DRQ
				status(2) <= '0';	-- lost data
				status(4) <= '0';	-- record not found
				status(5) <= '0';	-- record type
				status(6) <= '0';	-- write protect
				DRQ <= '0';
				INTRQ <= '0';
				ipcnt <= x"0";
				if motor_on = '0' then
					-- enable spin-up sequence
					motor_on <= '1';	-- motor on
					ipcnt <= x"6";
				end if;
				cmd_st <= c2_wait_ip;
			when c2_wait_ip =>
				if ipcnt = x"0" then
					if command(3) = '0' then
						spin_up <= '1';
					end if;
					if command(2) = '1' then
						-- E, add 15 ms delay
						delaycnt <= to_unsigned(120000,delaycnt'length);
					end if;
					cmd_st <= c2_delay;
				end if;
			when c2_delay =>
				if delaycnt = 0 then
					cmd_st <= c2_4;
				end if;
			when c2_4 =>
				if command(5) = '1' and WPRTn = '0' then
					INTRQ <= '1';
					status(0) <= '0';	-- busy
					status(6) <= '1';	-- write protect
					cmd_st <= idle;
				else
					ipcnt <= x"5";
					amd_st <= init;
					cmd_st <= c2_1;
				end if;
			when c2_1 =>
				upd_crc <= '1';
				if ipcnt = x"0" then
					-- 5 index holes have passed
					INTRQ <= '1';
					status(0) <= '0';	-- busy
					status(4) <= '1';	-- record not found
					cmd_st <= idle;
				elsif amd_dtam = '1' and ds_full = '1' and DSR = x"fe" then
					-- ID address mark detected
					cmd_st <= c2_1dtr;
				end if;
			when c2_1dtr =>
				if ds_full = '1' then
					if DSR = TR then
						cmd_st <= c2_1dsi;
					else
						cmd_st <= c2_1;
					end if;
				end if;
			when c2_1dsi =>
				if ds_full = '1' then
					cmd_st <= c2_1dse;
				end if;
			when c2_1dse =>
				if ds_full = '1' then
					if DSR = SR then
						cmd_st <= c2_1dsl;
					else
						cmd_st <= c2_1;
					end if;
				end if;
			when c2_1dsl =>
				if ds_full = '1' then
					upd_crc <= '0';
					case DSR(1 downto 0) is
						when "00" => dat_btc <= to_unsigned(127,dat_btc'length);
						when "01" => dat_btc <= to_unsigned(255,dat_btc'length);
						when "10" => dat_btc <= to_unsigned(511,dat_btc'length);
						when "11" => dat_btc <= to_unsigned(1023,dat_btc'length);
						when others => null;
					end case;
					cmd_st <= c2_1dc1;
				end if;
			when c2_1dc1 =>
				if ds_full = '1' then
					crc0 <= DSR;
					cmd_st <= c2_1dc2;
				end if;
			when c2_1dc2 =>
				if ds_full = '1' then
					if crc0 & DSR = crc then
						-- no CRC error
						status(3) <= '0';	-- CRC error (S3)
						if command(5) = '1' then
							-- write sector
							cmd_st <= c2_3;
						else
							-- read sector
							cmd_st <= c2_2;
						end if;
					else
						status(3) <= '1';	-- CRC error (S3)
						cmd_st <= c2_1;
					end if;
				end if;
			when c2_2 =>
				upd_crc <= '1';
				if amd_dtam = '1' and ds_full = '1' then
					-- Address mark detected and next byte available in DSR
					if DSR = x"fb" then
						-- data address mark
						status(5) <= '0';	-- record type (S5)
						cmd_st <= c2_2fb;
					elsif DSR = x"f8" then
						-- deleted data address mark
						status(5) <= '1';	-- record type (S5)
						cmd_st <= c2_2fb;
					else
						cmd_st <= c2_1;
					end if;
				end if;
			when c2_2fb =>
				if ds_full = '1' then
					DR <= DSR;
					status(1) <= '1';	-- DRQ (S1)
					DRQ <= '1';
					dat_btc <= dat_btc - 1;
					cmd_st <= c2_2nb;
				end if;
			when c2_2nb =>
				if ds_full = '1' then
					DR <= DSR;
					status(1) <= '1';	-- DRQ (S1)
					DRQ <= '1';
					if status(1) = '1' then
						-- DRQ still set -> DR has not been read by host
						status(2) <= '1';	-- lost data (S2)
					end if;
					if dat_btc = 0 then
						-- all bytes have been inputted
						upd_crc <= '0';
						cmd_st <= c2_2crc0;
					else
						-- process next byte
						dat_btc <= dat_btc - 1;
					end if;
				end if;
			when c2_2crc0 =>
				if ds_full = '1' then
					crc0 <= DSR;
					cmd_st <= c2_2crc1;
				end if;
			when c2_2crc1 =>
				if ds_full = '1' then
					if crc0 & DSR = crc then
						cmd_st <= c2_5;
					else
						-- CRC error
						INTRQ <= '1';
						status(0) <= '0';	-- busy (S0)
						status(3) <= '1';	-- CRC error (S3)
						cmd_st <= idle;
					end if;
				end if;
			when c2_5 =>
				if command(4) = '1' then
					-- multiple sectors flag is set
					SR <= std_logic_vector(unsigned(SR) + 1);
					cmd_st <= c2_4;
				else
					INTRQ <= '1';
					status(0) <= '0';	-- busy (S0)
					cmd_st <= idle;
				end if;
			when c2_3 =>
				-- delay 2 bytes of gap
				byte_cnt <= to_unsigned(2,byte_cnt'length);
				cmd_st <= c2_3wt1;
			when c2_3wt1 =>
				if byte_cnt = 0 then
					status(1) <= '1';	-- DRQ (S1)
					DRQ <= '1';
					byte_cnt <= to_unsigned(9,byte_cnt'length);
					cmd_st <= c2_3wt2;
				end if;
			when c2_3wt2 =>
				if byte_cnt = 0 then
					if status(1) = '0' then
						if DDENn = '0' then
							-- MFM format
							byte_cnt <= to_unsigned(11,byte_cnt'length);
							cmd_st <= c2_3wt3;
						else
							-- FM format
							wgs <= '1';
							DSR <= x"00";
							byte_cnt <= to_unsigned(6,byte_cnt'length);
							cmd_st <= c2_3wr0;
						end if;
					else
						-- lost data error
						INTRQ <= '1';
						status(0) <= '0';	-- busy (S0)
						status(2) <= '1';	-- lost data
						cmd_st <= idle;
					end if;
				end if;
			when c2_3wt3 =>
				if byte_cnt = 0 then
					wgs <= '1';
					DSR <= x"00";
					byte_cnt <= to_unsigned(12,byte_cnt'length);
					cmd_st <= c2_3wr0;
				end if;
			when c2_3wr0 =>
				if ds_full = '1' then
					if byte_cnt = 0 then
						DSR <= x"a1";
						byte_cnt <= to_unsigned(3,byte_cnt'length);
						cmd_st <= c2_3wram;
					else
						DSR <= x"00";
					end if;
				end if;
			when c2_3wram =>
				if ds_full = '1' then
					if byte_cnt = 0 then
						if command(0) = '1' then
							-- deleted data mark
							DSR <= x"f8";
						else
							-- normal data mark
							DSR <= x"fb";
						end if;
						upd_crc <= '1';
						crc <= x"cdb4";
						cmd_st <= c2_3wrdata;
					else
						DSR <= x"a1";
					end if;
				end if;
			when c2_3wrdata =>
				if ds_full = '1' then
					if status(1) = '1' then
						status(2) <= '1';	-- lost data
						DSR <= x"00";
					else
						DSR <= DR;
					end if;
					if dat_btc = 0 then
						cmd_st <= c2_3wrcrc1;
					else
						status(1) <= '1';	-- DRQ
						DRQ <= '1';
						dat_btc <= dat_btc - 1;
					end if;
				end if;
			when c2_3wrcrc1 =>
				if ds_full = '1' then
					upd_crc <= '0';
					DSR <= crc(15 downto 8);
					cmd_st <= c2_3wrcrc2;
				end if;
			when c2_3wrcrc2 =>
				if ds_full = '1' then
					DSR <= crc(7 downto 0);
					cmd_st <= c2_3wrff;
				end if;
			when c2_3wrff =>
				if ds_full = '1' then
					if DDENn = '0' then
						DSR <= x"4e";	-- MFM
					else
						DSR <= x"ff";	-- FM
					end if;
					cmd_st <= c2_3wrend;
				end if;
			when c2_3wrend =>
				if ds_full = '1' then
					wgs <= '0';
					cmd_st <= c2_5;
				end if;
			when c3_init =>
				INTRQ <= '0';
				status(0) <= '1';	-- busy
				status(1) <= '0';	-- DRQ
				status(2) <= '0';	-- lost data
				status(3) <= '0';	-- CRC error
				status(4) <= '0';	-- seek error
				status(5) <= '0';	-- record type
				status(6) <= '0';	-- write protect
				motor_on <= '1';	-- motor on
				DRQ <= '0';
				ipcnt <= x"0";
				if motor_on = '0' then
					-- enable spin-up sequence
					ipcnt <= x"6";
				end if;
				cmd_st <= c3_wl1;
			when c3_wl1 =>
				if ipcnt = x"0" then
					if command(3) = '0' then
						spin_up <= '1';
					end if;
					if command(2) = '1' then
						-- add 15 ms delay
						delaycnt <= to_unsigned(120000,delaycnt'length);
					end if;
					cmd_st <= c3_wl2;
				end if;
			when c3_wl2 =>
				if delaycnt = 0 then
					case command(5 downto 4) is
						when "00" => cmd_st <= c3_rdad;
						when "10" => cmd_st <= c3_rdtr;
						when "11" => cmd_st <= c3_wrtr;
						when others => null;
					end case;
				end if;
			when c3_rdad =>
				ipcnt <= x"6";
				upd_crc <= '1';
				cmd_st <= c3_rdad1;
			when c3_rdad1 =>
				if ipcnt = x"0" then
					-- 6 index holes have passed
					INTRQ <= '1';
					status(0) <= '0';	-- reset busy
					status(4) <= '1';	-- seek error
					cmd_st <= idle;
				elsif amd_dtam = '1' and ds_full = '1' and DSR = x"fe" then
					-- ID address mark detected
					cmd_st <= c3_rdad2;
				end if;
			when c3_rdad2 =>
				if ds_full = '1' then
					SR <= DSR;
					DR <= DSR;
					status(1) <= '1';	-- DRQ
					DRQ <= '1';
					dat_btc <= to_unsigned(4,dat_btc'length);
					cmd_st <= c3_rdad3;
				end if;
			when c3_rdad3 =>
				if ds_full = '1' then
					if status(1) = '1' then
						status(2) <= '1';	-- lost data
					else
						DR <= DSR;
					end if;
					status(1) <= '1';	-- DRQ
					DRQ <= '1';
					if dat_btc = 2 then
						upd_crc <= '0';
					end if;
					if dat_btc = 1 then
						crc0 <= DSR;
					end if;
					if dat_btc = 0 then
						if crc0 & DSR /= crc then
							status(3) <= '1';	-- CRC error
						end if;
						INTRQ <= '1';
						status(0) <= '0';	-- busy
						cmd_st <= idle;
					else
						dat_btc <= dat_btc - 1;
					end if;
				end if;
			when c3_rdtr =>
				ipcnt <= x"2";
				cmd_st <= c3_rdtrwip;
			when c3_rdtrwip =>
				if ipcnt = x"1" then
					cmd_st <= c3_rdtrlp;
				end if;
			when c3_rdtrlp =>
				if ds_full = '1' then
					if status(1) = '1' then
						status(2) <= '1';	-- lost data
					end if;
					DR <= DSR;
					status(1) <= '1';	-- DRQ
					DRQ <= '1';
					if ipcnt = x"0" then
						INTRQ <= '1';
						status(0) <= '0';	-- busy
						cmd_st <= idle;
					end if;
				end if;
			when c3_wrtr =>
				if WPRTn = '0' then
					INTRQ <= '1';
					status(0) <= '0';	-- busy
					status(6) <= '1';	-- write protect
					cmd_st <= idle;
				else
					status(1) <= '1';	-- DRQ
					DRQ <= '1';
					byte_cnt <= to_unsigned(3,byte_cnt'length);
					cmd_st <= c3_wrtr1;
				end if;
			when c3_wrtr1 =>
				if byte_cnt = 0 then
					if status(1) = '1' then
						INTRQ <= '1';
						status(0) <= '0';	-- busy
						status(2) <= '1';	-- lost data
						cmd_st <= idle;
					else
						ipcnt <= x"1";
						cmd_st <= c3_wrtrwip;
					end if;
				end if;
			when c3_wrtrwip =>
				if ipcnt = x"0" then
					ipcnt <= x"1";
					wgs <= '1';
					cmd_st <= c3_wrtr_a;
				end if;
			when c3_wrtr_a =>
				DSR <= DR;
				status(1) <= '1';	-- DRQ
				DRQ <= '1';
				cmd_st <= c3_wrtr_b;
			when c3_wrtr_b =>
				cmd_st <= c3_wrtrwb;
				if DSR = x"f5" then
					DSR <= x"a1";
					cmd_st <= c3_wrtrwf5;
				elsif DSR = x"f6" then
					DSR <= x"c2";
				elsif DSR = x"f7" then
					upd_crc <= '0';
					DSR <= crc(15 downto 8);
					cmd_st <= c3_wrtrwcrc;
				end if;
			when c3_wrtrwb =>
				if ds_full = '1' then
					cmd_st <= c3_wrtrwb1;
				end if;
			when c3_wrtrwb1 =>
				if ipcnt = x"0" then
					wgs <= '0';
					INTRQ <= '1';
					status(0) <= '0';	-- busy
					cmd_st <= idle;
				elsif status(1) = '1' then
					DSR <= x"00";
					status(2) <= '1';	-- lost data
					cmd_st <= c3_wrtrwb;
				else
					cmd_st <= c3_wrtr_a;
				end if;
			when c3_wrtrwf5 =>
				if ds_full = '1' then
					upd_crc <= '1';
					crc <= x"cdb4";
					cmd_st <= c3_wrtrwb1;
				end if;
			when c3_wrtrwcrc =>
				if ds_full = '1' then
					DSR <= crc(7 downto 0);
					cmd_st <= c3_wrtrwb;
				end if;
			when c4_init =>
				if status(0) = '1' then
					status(0) <= '0';	-- busy
				else
					status(1) <= IPn;	-- IP
					status(2) <= TR0n;	-- track 0
					status(3) <= '0';	-- CRC error
					status(4) <= '0';	-- record not found
					status(5) <= spin_up;	-- spin up
					status(6) <= '0';	-- write protect
				end if;
				DRQ <= '0';
				wgs <= '0';
				if command(3) = '1' then
					cmd_st <= c4_trig;
				elsif command(2) = '1' then
					-- wait for next index pulse
					if motor_on = '0' then
						motor_on <= '1';
						ipcnt <= x"6";
					else
						ipcnt <= x"1";
					end if;
					cmd_st <= c4_wip;
				else
					cmd_st <= idle;
				end if;
			when c4_wip =>
				if ipcnt = x"0" then
					cmd_st <= c4_trig;
				end if;
			when c4_trig =>
				INTRQ <= '1';
				cmd_st <= idle;
			end case;
		end if;
	end if;
end process;

end behavioral;
