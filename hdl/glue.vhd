-- glue.vhd - Implementation of the Atari ST GLUE chip
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
		DTACKn	: out std_logic;
		BEER	: out std_logic;
		oD		: out std_logic_vector(1 downto 0);

		FC		: in std_logic_vector(2 downto 0);
		IPLn	: out std_logic_vector(2 downto 1);
		VPAn	: out std_logic;
		VMAn	: in std_logic;
		cs6850	: out std_logic;

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
	constant sync_hi	: sync_t := (224,501,34,34,434,500,28,4,164,184);

	type sync_array_t is array (0 to 2) of sync_t;
	constant sync_array : sync_array_t := (sync_60,sync_50,sync_hi);

	signal sync		: sync_t;

	-- IO memory mapped registers map
	type iomap_t is array (16#8000# to 16#ffff#) of std_logic;
	constant iomap	: iomap_t := (
		16#8001# => '1',
		16#8201# => '1',
		16#8203# => '1',
		16#8205# => '1',
		16#8207# => '1',
		16#8209# => '1',
		16#820a# => '1',
		16#820b# => '1',
		16#820d# => '1',
		16#8240# to 16#827f# => '1',
		16#8604# to 16#8607# => '1',
		16#8609# => '1',
		16#860b# => '1',
		16#860d# => '1',
		16#8800# to 16#88ff# => '1',
		16#8a00# to 16#8a3d# => '1',
		16#fa01# => '1',
		16#fa03# => '1',
		16#fa05# => '1',
		16#fa07# => '1',
		16#fa09# => '1',
		16#fa0b# => '1',
		16#fa0d# => '1',
		16#fa0f# => '1',
		16#fa11# => '1',
		16#fa13# => '1',
		16#fa15# => '1',
		16#fa17# => '1',
		16#fa19# => '1',
		16#fa1b# => '1',
		16#fa1d# => '1',
		16#fa1f# => '1',
		16#fa21# => '1',
		16#fa23# => '1',
		16#fa25# => '1',
		16#fa27# => '1',
		16#fa29# => '1',
		16#fa2b# => '1',
		16#fa2d# => '1',
		16#fa2f# => '1',
		16#fa31# => '1',
		16#fa33# => '1',
		16#fa35# => '1',
		16#fa37# => '1',
		16#fa39# => '1',
		16#fa3b# => '1',
		16#fa3d# => '1',
		16#fa3f# => '1',
		16#fc00# to 16#fdff# => '1',
		others => '0');

	-- resolution
	signal res		: std_logic_vector(1 downto 0) := "00";
	signal mono		: std_logic;
	-- 0 -> 60 Hz, 1 -> 50 Hz
	signal hz50		: std_logic := '1';

	signal cnt		: unsigned(1 downto 0);
	signal hcnt		: unsigned(8 downto 0);
	signal vcnt		: unsigned(8 downto 0);
	signal vblank	: std_logic;
	signal hblank	: std_logic;
	signal vde		: std_logic;
	signal hde		: std_logic;
	signal line_pal	: std_logic := '0';

	signal rd_reg	: boolean;
	signal wt_reg	: boolean;
	signal sync_id	: unsigned(1 downto 0);

	signal irq_vbl	: std_logic;
	signal irq_hbl	: std_logic;
	signal irq_mfp	: std_logic;
	signal svsync	: std_logic;
	signal shsync	: std_logic;
	signal svsync2	: std_logic;
	signal shsync2	: std_logic;
	signal ack_vbl	: std_logic;
	signal ack_hbl	: std_logic;
	signal vpa_irqn	: std_logic;
	signal vpa_acia	: std_logic;

begin

rd_reg <= (iRWn = '1' and cnt = 1) or cnt = 2;
wt_reg <= iRWn = '0' and cnt = 2;
mono <= res(1);
BLANKn <= vblank nor hblank;
DE <= vde and hde;
VSYNC <= svsync;
HSYNC <= shsync;
irq_mfp <= not MFPINTn;
VPAn <= vpa_irqn and vpa_acia;

sync_id <= mono & (line_pal and not mono);
sync <= sync_array(to_integer(sync_id));

-- 8-bit bus (ACIA) signal management
process(iA,iASn,VMAn)
begin
	vpa_acia <= '1';
	cs6850 <= '0';
	if iA(23 downto 3)&"000" = x"fffc00" and iASn = '0' then
		vpa_acia <= '0';
		if VMAn = '0' then
			cs6850 <= '1';
		end if;
	end if;
end process;

-- peripheral register access
process(clk)
begin
	if rising_edge(clk) then
	if resetn = '0' then
		DTACKn <= '1';
		BEER <= '1';
		cnt <= "00";
	elsif enPhi2 = '1' then
		cnt <= cnt + 1;
	elsif enPhi1 = '1' then
		oD <= (others => '1');
		if cnt = 0 then
			DTACKn <= '1';
			BEER <= '1';
		end if;
		if FC /= "111" and iASn = '0' and (cnt = 1 or cnt = 2) then
			if iA(23 downto 15) = "111111111" and FC(2) = '1' then
				-- hardware registers
				if iUDSn = '0' and iA(15 downto 1)&'0' = x"8260" and wt_reg then
					-- resolution (write only - Read is managed by Shifter.)
					res <= iD;
				end if;
				if iUDSn = '0' and iA(15 downto 1)&'0' = x"820a" then
					if rd_reg then
						oD <= hz50&'0';
					elsif wt_reg then
						hz50 <= iD(1);
					end if;
				end if;
				if cnt = 2 and iA(15 downto 6)&"000000" /= x"fa00" and iA(15 downto 9) /= "1111110" then
					-- assert DTACKn except for MFP and ACIA register accesses.
					DTACKn <= '0';
				end if;
				if cnt = 2 and ((iUDSn = '0' and iomap(to_integer(unsigned(iA(15 downto 1)&'0'))) = '0') or (iLDSn = '0' and iomap(to_integer(unsigned(iA(15 downto 1)&'1'))) = '0')) then
					DTACKn <= '1';
					BEER <= '0';
				end if;
			elsif ((unsigned(iA(23 downto 16)) >= x"fa" and unsigned(iA(23 downto 16)) <= x"fe") or unsigned(iA&'0') < 8) and FC(2) = '1' and iRWn = '1' then
				-- rom access
				if cnt = 2 then
					DTACKn <= '0';
				end if;
			elsif unsigned(iA&'0') < x"800" and unsigned(iA&'0') >= 8 and FC(2) = '1' then
				-- protected ram access (supervisor mode only)
				if cnt = 2 then
					DTACKn <= '0';
				end if;
			elsif unsigned(iA&'0') >= x"800" and unsigned(iA(23 downto 16)) < x"40" then
				-- ram access
				if cnt = 2 then
					DTACKn <= '0';
				end if;
			else
				if cnt = 2 then
					BEER <= '0';
				end if;
			end if;
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

-- interrupt control
process(clk)
begin
	if rising_edge(clk) then
		if resetn = '0' then
			irq_hbl <= '0';
			irq_vbl <= '0';
			ack_hbl <= '0';
			ack_vbl <= '0';
			svsync2 <= '1';
			shsync2 <= '1';
		elsif enPhi2 = '1' then
			svsync2 <= svsync;
			shsync2 <= shsync;
			if svsync = '0' and svsync2 = '1' then
				irq_vbl <= '1';
			end if;
			if shsync = '0' and shsync2 = '1' then
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

-- compute IPL
process(irq_hbl,irq_vbl,irq_mfp)
begin
	if irq_mfp = '1' then
		IPLn <= "00";
	elsif irq_vbl = '1' then
		IPLn <= "01";
	elsif irq_hbl = '1' then
		IPLn <= "10";
	else
		IPLn <= "11";
	end if;
end process;

-- interrupt acknowledge
-- process(FC,iA,iASn,irq_mfp,irq_vbl,irq_hbl)
process(FC,iA,iASn)
begin
	vpa_irqn <= '1';
	IACKn <= '1';
	if FC = "111" and iA(19 downto 16) = "1111" and iASn = '0' then
		if iA(3 downto 2) = "11" then
			IACKn <= '0';
		elsif iA(3 downto 2) = "10" or iA(3 downto 2) = "01" then
			vpa_irqn <= '0';
		end if;
	end if;
end process;

-- video sync
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
			hcnt <= hcnt+1;
			if hcnt+1 = 4 and mono = '1' then
				hde <= '1';
			end if;
			if hcnt+1 = 24 and mono = '0' and hz50 = '0' then
				hblank <= '0';
			end if;
			if hcnt+1 = 28 and mono = '0' and hz50 = '1' then
				hblank <= '0';
			end if;
			if hcnt+1 = 52 and mono = '0' and hz50 = '0' then
				hde <= '1';
			end if;
			if hcnt+1 = 54 then
				line_pal <= hz50;
			end if;
			if hcnt+1 = 56 and mono = '0' and hz50 = '1' then
				hde <= '1';
			end if;
			if hcnt+1 = 164 and mono = '1' then
				hde <= '0';
			end if;
			if hcnt+1 = 184 and mono = '1' then
				hblank <= '1';
			end if;
			if hcnt+1 = 372 and mono = '0' and hz50 = '0' then
				hde <= '0';
			end if;
			if hcnt+1 = 376 and mono = '0' and hz50 = '1' then
				hde <= '0';
			end if;
			if hcnt+1 = 450 and mono = '0' then
				hblank <= '1';
			end if;
			if ((hcnt = 457 and line_pal = '0') or (hcnt = 461 and line_pal = '1')) and mono = '0' then
				shsync <= '0';
				hde <= '0';
			end if;
			if ((hcnt = 497 and line_pal = '0') or (hcnt = 501 and line_pal = '1')) and mono = '0' then
				shsync <= '1';
			end if;
			if (hcnt = 213 and mono = '1') or hcnt = 501 then
				-- update V signals
				if (vcnt = 262 and mono = '0' and hz50 = '0') or (vcnt = 312 and mono = '0') or vcnt = 500 then
					svsync <= '0';
					vcnt <= (others => '0');
				else
					vcnt <= vcnt+1;
					if (vcnt = 0 and mono = '1') or (vcnt = 2 and mono = '0') then
						svsync <= '1';
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
			end if;
			if (hcnt = 223 and mono = '1') or (hcnt = 507 and line_pal = '0') or hcnt = 511 then
				hcnt <= (others => '0');
			end if;
		end if;
	end if;
end process;

end behavioral;
