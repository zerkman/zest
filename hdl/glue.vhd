-- glue.vhd - Implementation of the Atari ST GLUE chip
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

entity glue is
	port (
		clk		: in std_logic;
		enPhi1	: in std_logic;
		enPhi2	: in std_logic;
		resetn	: in std_logic;

		iA		: in std_logic_vector(23 downto 1);
		iASn	: in std_logic;
		iRWn	: in std_logic;
		iD		: in std_logic_vector(1 downto 0);
		iUDSn	: in std_logic;
		iLDSn	: in std_logic;
		iDTACKn	: in std_logic;
		oRWn	: out std_logic;
		oDTACKn	: out std_logic;
		BEER	: out std_logic;
		oD		: out std_logic_vector(1 downto 0);

		FC		: in std_logic_vector(2 downto 0);
		IPLn	: out std_logic_vector(2 downto 1);
		VPAn	: out std_logic;
		VMAn	: in std_logic;
		cs6850	: out std_logic;
		FCSn	: out std_logic;
		iRDY	: in std_logic;
		oRDY	: out std_logic;
		RAMn	: out std_logic;
		DMAn	: out std_logic;
		DEVn	: out std_logic;

		BRn		: out std_logic;
		BGn		: in std_logic;
		BGACKn	: out std_logic;

		MFPCSn	: out std_logic;
		MFPINTn	: in std_logic;
		IACKn	: out std_logic;

		VSYNC	: out std_logic;
		HSYNC	: out std_logic;
		BLANKn	: out std_logic;
		DE		: out std_logic
	);
end glue;


architecture behavioral of glue is

	type sync_t is record
		cycles_per_line	: integer;
		n_lines			: integer;
		first_visible	: integer;
		vde_on			: integer;
		vde_off			: integer;
		vblank_on		: integer;
		hblank_off		: integer;
		hde_on			: integer;
		hde_off			: integer;
		hblank_on		: integer;
	end record;
	constant sync_50	: sync_t := (512,313,34,63,263,310,28,56,376,450);
	constant sync_60	: sync_t := (508,263,5,34,234,260,24,52,372,450);
	constant sync_hi	: sync_t := (224,501,34,34,434,434,28,4,164,184);

	type sync_array_t is array (0 to 2) of sync_t;
	constant sync_array : sync_array_t := (sync_60,sync_50,sync_hi);
	signal sync		: sync_t;
	constant vbl_delay	: integer := 68;

	-- resolution
	signal mono		: std_logic := '0';
	-- 0 -> 60 Hz, 1 -> 50 Hz
	signal hz50		: std_logic := '1';

	signal hcnt		: unsigned(8 downto 0);
	signal nexthcnt	: unsigned(8 downto 0);
	signal vcnt		: unsigned(8 downto 0);
	signal vblank	: std_logic;
	signal hblank	: std_logic;
	signal vde		: std_logic;
	signal hde		: std_logic;
	signal line_pal	: std_logic := '0';

	signal sync_id	: unsigned(1 downto 0);

	signal irq_vbl	: std_logic;
	signal irq_hbl	: std_logic;
	signal irq_mfp	: std_logic_vector(3 downto 0);
	signal svsync	: std_logic;
	signal shsync	: std_logic;
	signal iack_cnt	: unsigned(2 downto 0);
	signal ack_vbl	: std_logic;
	signal ack_hbl	: std_logic;
	signal vpa_irqn	: std_logic;
	signal vpa_acia	: std_logic;
	signal sdtackn	: std_logic;
	signal wdtackn	: std_logic;
	signal beercnt	: unsigned(5 downto 0);
	signal rwn_ff	: std_logic;
	signal dma_w	: std_logic;
	type dma_st_t is ( idle, wait_bg, wait_sync, running, wait_rdy );
	signal dma_st	: dma_st_t;
	signal dma_cnt	: unsigned(2 downto 0);
	signal sdma		: std_logic;
	signal mmuct	: unsigned(1 downto 0);
	signal idtackff	: std_logic;

begin

BLANKn <= vblank nor hblank;
DE <= vde and hde;
VSYNC <= svsync;
HSYNC <= shsync;
VPAn <= vpa_irqn and vpa_acia;
wdtackn <= '0' when iA(15 downto 2)&"00" = x"8604" or iA(15 downto 8) = x"88" else '1';
oDTACKn <= sdtackn;
oRDY <= sdma;
DMAn <= sdma;

sync_id <= mono & (line_pal and not mono);
sync <= sync_array(to_integer(sync_id));

-- 8-bit bus (ACIA) signal management
process(iA,iASn,VMAn)
begin
	vpa_acia <= '1';
	cs6850 <= '0';
	if iA(23 downto 9)&"000000000" = x"fffc00" and iASn = '0' then
		-- accept all addresses in $fffc00 -> $fffdff range
		vpa_acia <= '0';
		if iA(23 downto 3)&"000" = x"fffc00" and VMAn = '0' then
			-- enable ACIAs only for $fffc00 -> $fffc07 range
			cs6850 <= '1';
		end if;
	end if;
end process;

-- peripheral register access
process(clk)
begin
	if rising_edge(clk) then
	if resetn = '0' then
		sdtackn <= '1';
		mono <= '0';
		hz50 <= '0';
		dma_w <= '0';
		mmuct <= "00";
		idtackff <= '1';
	elsif enPhi2 = '1' then
		idtackff <= iDTACKn;
		if FC /= "111" and iASn = '0' and iUDSn = '0' and FC(2) = '1' and iRWn = '0' then
			if iA(23 downto 8) = x"ff82" then
				if iA(7 downto 1)&'0' = x"60" then
					-- resolution (write only - Read is managed by Shifter.)
					mono <= iD(1);
				end if;
				if iA(7 downto 1)&'0' = x"0a" then
					hz50 <= iD(1);
				end if;
			elsif iA(23 downto 1)&'0' = x"ff8606" then
				dma_w <= iD(0);
			end if;
		end if;
		if iDTACKn = '0' and idtackff = '1' then
			-- synchronize with MMU counter
			mmuct <= "11";
		else
			mmuct <= mmuct + 1;
		end if;
	elsif enPhi1 = '1' then
		oD <= (others => '1');
		sdtackn <= '1';
		if FC /= "111" and iASn = '0' and (iUDSn = '0' or iLDSn = '0' or (iRwn = '0' and rwn_ff = '1')) then
			if iA(23 downto 15) = "111111111" and FC(2) = '1' then
				-- hardware registers
				if iA(15 downto 6)&"000000" = x"8240" then
					if iA(15 downto 1)&'0' = x"820a" and iUDSn = '0' and iRWn = '1' then
						oD <= hz50&'0';
					end if;
				end if;
				if wdtackn = '0' then
					-- assert DTACKn for DMA and PSG access
					sdtackn <= '0';
				end if;
			end if;
		end if;
	end if;
	end if;
end process;

-- RAMn / DEVn bus signals to the MMU
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			rwn_ff <= '1';
		elsif enPhi1 = '1' then
			rwn_ff <= iRWn;
		end if;
	end if;
end process;
process(FC,iA,iASn,iUDSn,iLDSn,iRWn,rwn_ff)
begin
	RAMn <= '1';
	DEVn <= '1';
	if FC /= "111" and iASn = '0' and (iUDSn = '0' or iLDSn = '0' or (iRWn = '0' and rwn_ff = '1')) then
		if iA(23 downto 15) = "111111111" then
			-- hardware registers
			if FC(2) = '1' then
				if iA(15 downto 7)&"0000000" = x"8200" or iA(15 downto 1)&'1' = x"8001" or iA(15 downto 3)&"000" = x"8608" then
					DEVn <= '0';
				end if;
			end if;
		elsif unsigned(iA(23 downto 16)) >= x"fa" and unsigned(iA(23 downto 16)) <= x"fe" and iRWn = '1' then
			-- rom access
			RAMn <= '0';
		elsif unsigned(iA&'0') < 8 and iRWn = '1' and FC(2) = '1' then
			-- rom access
			RAMn <= '0';
		elsif unsigned(iA&'0') < x"800" and unsigned(iA&'0') >= 8 and FC(2) = '1' then
			-- protected ram access (supervisor mode only)
			RAMn <= '0';
		elsif unsigned(iA&'0') >= x"800" and iA(23 downto 22) = "00" then
			-- ram access
			RAMn <= '0';
		end if;
	end if;
end process;

-- bus error
BEER <= beercnt(5);
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			beercnt <= "100000";
		elsif enPhi1 = '1' then
			if iASn = '0' and (iUDSn = '0' or iLDSn = '0') and iDTACKn = '1' and sdtackn = '1' then
				if beercnt(5) = '1' then
					beercnt <= beercnt + 1;
				end if;
			else
				beercnt <= "100000";
			end if;
		end if;
	end if;
end process;

-- mfp access
process(iA,iASn)
begin
	if iASn = '0' and iA(23 downto 6)&"000000" = x"fffa00" then
		MFPCSn <= '0';
	else
		MFPCSn <= '1';
	end if;
end process;

-- dma registers access
process(iA,iASn)
begin
	if iASn = '0' and iA(23 downto 2)&"00" = x"ff8604" then
		FCSn <= '0';
	else
		FCSn <= '1';
	end if;
end process;

-- dma operation
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			BRn <= '1';
			BGACKn <= '1';
			dma_st <= idle;
			dma_cnt <= "000";
			sdma <= '1';
			oRWn <= '1';
		elsif enPhi1 = '1' then
			case dma_st is
			when idle =>
				if iRDY = '1' then
					-- initiate bus request
					BRn <= '0';
					dma_st <= wait_bg;
				end if;
			when wait_bg =>
				if BGn = '0' and iASn = '1' and iDTACKn = '1' then
					BGACKn <= '0';
					dma_cnt <= "111";
					dma_st <= running;
					if mmuct = 0 then
						dma_st <= running;
					else
						dma_st <= wait_sync;
					end if;
				end if;
			when wait_sync =>
				BRn <= '1';
				if mmuct = 0 then
					dma_st <= running;
				end if;
			when running =>
				BRn <= '1';
				if mmuct = 0 then
					oRWn <= '1';
				elsif mmuct = 1 then
					sdma <= '0';
					oRWn <= dma_w;
				elsif mmuct = 3 then
					if dma_cnt = 0 then
						dma_st <= wait_rdy;
					else
						dma_cnt <= dma_cnt - 1;
						dma_st <= running;
					end if;
				end if;
			when wait_rdy =>
				oRWn <= '1';
				BGACKn <= '1';
				if iRDY = '0' then
					dma_st <= idle;
				end if;
			end case;
		elsif enPhi2 = '1' then
			if sdma = '0' and mmuct = 3 then
				sdma <= '1';
			end if;
		end if;
	end if;
end process;

-- interrupt control
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			irq_hbl <= '0';
			irq_vbl <= '0';
			ack_hbl <= '0';
			ack_vbl <= '0';
		elsif enPhi2 = '1' then
			if vcnt = 0 and nexthcnt = vbl_delay then
				irq_vbl <= '1';
			end if;
			if nexthcnt = 0 then
				irq_hbl <= '1';
			end if;
			if FC = "111" and iA(19 downto 16) = "1111" and iASn = '0' then
				case iA(3 downto 2) is
					when "10" => ack_vbl <= '1';
					when "01" => ack_hbl <= '1';
					when others =>
				end case;
			else
				if ack_vbl = '1' then
					irq_vbl <= '0';
					ack_vbl <= '0';
				end if;
				if ack_hbl = '1' then
					irq_hbl <= '0';
					ack_hbl <= '0';
				end if;
			end if;
		end if;
	end if;
end process;

-- shift register for 4-cycle MFP interrupt delay
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			irq_mfp <= (others => '0');
		elsif enPhi1 = '1' then
			irq_mfp(irq_mfp'high) <= not MFPINTn;
			for i in irq_mfp'low to irq_mfp'high-1 loop
				irq_mfp(i) <= irq_mfp(i+1);
			end loop;
		end if;
	end if;
end process;

-- compute IPL
process(irq_hbl,irq_vbl,irq_mfp)
begin
	if irq_mfp(0) = '1' then
		IPLn <= "00";
	elsif irq_vbl = '1' then
		IPLn <= "01";
	elsif irq_hbl = '1' then
		IPLn <= "10";
	else
		IPLn <= "11";
	end if;
end process;

-- Autovector interrupt acknowledge (for HBL and VBL)
process(FC,iA,iASn)
begin
	vpa_irqn <= '1';
	if FC = "111" and iA(19 downto 16) = "1111" and iA(3 downto 2) /= "11" and iASn = '0' then
		vpa_irqn <= '0';
	end if;
end process;

-- Vectored interrupt acknowledge (for MFP)
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			iack_cnt <= (others => '0');
			IACKn <= '1';
		elsif enPhi1 = '1' then
			IACKn <= '1';
			if FC = "111" and iA(19 downto 16) = "1111" and iA(3 downto 2) = "11" and iASn = '0' then
				if iack_cnt = 7 then
					IACKn <= '0';
				else
					iack_cnt <= iack_cnt + 1;
				end if;
			else
				iack_cnt <= (others => '0');
			end if;
		end if;
	end if;
end process;

-- video sync
process(hcnt,mono,line_pal)
begin
	if (hcnt = 223 and mono = '1') or (hcnt = 507 and line_pal = '0') or hcnt = 511 then
		nexthcnt <= (others => '0');
	else
		nexthcnt <= hcnt+1;
	end if;
end process;

process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			svsync <= '1';
			shsync <= '1';
			hblank <= '1';
			vblank <= '1';
			hde <= '0';
			vde <= '0';
			hcnt <= (others => '1');
			vcnt <= (others => '0');
		elsif enPhi1 = '1' then
			-- update H signals
			hcnt <= nexthcnt;
			if nexthcnt = 4 and mono = '1' then
				hde <= '1';
			end if;
			if nexthcnt = 21 and mono = '1' then
				hblank <= '0';
			end if;
			if nexthcnt = 24 and mono = '0' and hz50 = '0' then
				hblank <= '0';
			end if;
			if nexthcnt = 28 and mono = '0' and hz50 = '1' then
				hblank <= '0';
			end if;
			if nexthcnt = 52 and mono = '0' and hz50 = '0' then
				hde <= '1';
			end if;
			if nexthcnt = 54 then
				line_pal <= hz50;
			end if;
			if nexthcnt = 56 and mono = '0' and hz50 = '1' then
				hde <= '1';
			end if;
			if nexthcnt = 164 and mono = '1' then
				hde <= '0';
			end if;
			if nexthcnt = 181 and mono = '1' then
				hblank <= '1';
			end if;
			if nexthcnt = 192 and mono = '1' then
				shsync <= '0';
			end if;
			if nexthcnt = 220 and mono = '1' then
				shsync <= '1';
			end if;
			if nexthcnt = 372 and mono = '0' and hz50 = '0' then
				hde <= '0';
			end if;
			if nexthcnt = 376 and mono = '0' and hz50 = '1' then
				hde <= '0';
			end if;
			if nexthcnt = 450 and mono = '0' then
				hblank <= '1';
			end if;
			if ((nexthcnt = 458 and line_pal = '0') or (nexthcnt = 462 and line_pal = '1')) and mono = '0' then
				shsync <= '0';
				hde <= '0';
			end if;
			if ((nexthcnt = 498 and line_pal = '0') or (nexthcnt = 502 and line_pal = '1')) and mono = '0' then
				shsync <= '1';
			end if;
			if (nexthcnt = 214 and mono = '1') or nexthcnt = 502 then
				-- update V signals
				if (vcnt = 262 and mono = '0' and hz50 = '0') or (vcnt = 312 and mono = '0') or vcnt = 500 then
					svsync <= '0';
				else
					if (vcnt = 0 and mono = '1') or (vcnt = 2 and mono = '0') then
						svsync <= '1';
					end if;
				end if;
				if vcnt+1 = sync.vblank_on then
					vblank <= '1';
				end if;
				if vcnt+1 = sync.first_visible then
					vblank <= '0';
				end if;
				if vcnt+1 = sync.vde_on then
					vde <= '1';
				end if;
				if vcnt+1 = sync.vde_off then
					vde <= '0';
				end if;
			end if;
			if nexthcnt = 0 then
				if (mono = '0' and ((vcnt = 262 and hz50 = '0') or vcnt = 312)) or vcnt = 500 then
					vcnt <= (others => '0');
				else
					vcnt <= vcnt + 1;
				end if;
			end if;
		end if;
	end if;
end process;

end behavioral;
