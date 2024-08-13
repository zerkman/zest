-- mmu.vhd - Implementation of the Atari ST MMU chip
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

entity mmu is
	port (
		clk		: in std_logic;
		en8rck	: in std_logic;
		en8fck	: in std_logic;
		resetn	: in std_logic;

		-- regular RAM access
		RAMn	: in std_logic;
		-- DMA RAM access (use DMA pointer instead of address bus)
		DMAn	: in std_logic;
		-- DMA or Shifter register access
		DEVn	: in std_logic;

		iA		: in std_logic_vector(23 downto 1);
		iASn	: in std_logic;
		iRWn	: in std_logic;
		iD		: in std_logic_vector(7 downto 0);
		iUDSn	: in std_logic;
		iLDSn	: in std_logic;
		oD		: out std_logic_vector(7 downto 0);
		DTACKn	: out std_logic;

		RDATn	: out std_logic;
		LATCH	: out std_logic;

		-- data cycle to shifter
		DCYCn	: out std_logic;
		-- register request to shifter
		CMPCSn	: out std_logic;

		DE		: in std_logic;
		VSYNC	: in std_logic;

		-- max memory configuration
		mem_top	: in std_logic_vector(5 downto 0);

		-- interface to RAM. Using own signals instead of hardware specific ones
		ram_A	: out std_logic_vector(23 downto 1);
		ram_W	: out std_logic;
		ram_R	: out std_logic;
		ram_DS	: out std_logic_vector(1 downto 0)
	);
end mmu;

architecture behavioral of mmu is
	-- ST RAM management simulation
	signal ramcfg			: std_logic_vector(3 downto 0);	-- physical RAM, 2x2 bits: 00:128k 01:512k 10:2M 11:unused
	signal memcfg			: std_logic_vector(3 downto 0);	-- MMU config ($ff8001), 2x2 bits
	signal memcfg_top		: unsigned(23 downto 0);
	signal log_adr			: std_logic_vector(23 downto 1);
	signal phys_adr			: std_logic_vector(23 downto 1);
	signal bank0_size		: unsigned(23 downto 1);
	signal present_bus		: std_logic;
	signal present_video	: std_logic;

	signal cnt				: unsigned(1 downto 0);
	signal screen_adr		: std_logic_vector(23 downto 8);
	signal video_ptr		: std_logic_vector(23 downto 1);
	signal dma_ptr			: std_logic_vector(23 downto 1);
	signal al				: std_logic_vector(7 downto 0);
	signal mode_bus_0		: std_logic;
	signal mode_bus_1		: std_logic;
	signal mode_bus			: std_logic;
	signal mode_load_0		: std_logic;
	signal mode_load_1		: std_logic;
	signal mode_load		: std_logic;
	signal cmpcsn_en		: std_logic;
	signal sdtackn			: std_logic;
	signal sde				: std_logic;
	signal loadn			: std_logic;

	-- tells whether there is actual memory at given address
	impure function memory_present(a: in std_logic_vector(23 downto 1)) return std_logic is
	begin
		if a(23 downto 22) /= "00" then
			-- for extended memory (from +4M up to 14M), address verification is done in GLUE (bus error)
			return '1';
		end if;
		if unsigned(a) < bank0_size then
			return '1';
		end if;
		if ramcfg(1 downto 0) /= "11" and unsigned(a) < memcfg_top(23 downto 1) then
			return '1';
		end if;
		return '0';
	end function;

begin

	al <= iA(7 downto 1) & '1';
	present_bus <= memory_present(iA);
	present_video <= memory_present(video_ptr);
	DTACKn <= sdtackn;
	DCYCn <= loadn;
	RDATn <= (DMAn and RAMn) or not iRWn;
	CMPCSn <= '0' when cmpcsn_en = '1' and iA(23 downto 6) & "000000" = x"ff8240" and iUDSn = '0' and iASn = '0' else '1';

	-- Typical ram config depending on size
	process(mem_top)
		variable ramsz : integer range 0 to 63;
	begin
		ramsz := to_integer(unsigned(mem_top));
		if ramsz = 0 then
			-- 256 kB
			ramcfg <= "0000";
		elsif ramsz = 1 then
			-- 512 kB
			ramcfg <= "0111";
		elsif ramsz <= 3 then
			-- 1 MB
			ramcfg <= "0101";
		elsif ramsz <= 7 then
			-- 2 MB
			ramcfg <= "1011";
		elsif ramsz <= 9 then
			-- 2.5 MB
			ramcfg <= "1001";
		else
			ramcfg <= "1010";
		end if;
	end process;

	-- maximum address in configured RAM
	process(memcfg)
	begin
		if memcfg = "0000" then
			memcfg_top <= x"040000";	-- 256k
		elsif memcfg = "0001" or memcfg = "0100" then
			memcfg_top <= x"0a0000";	-- 512k+128k
		elsif memcfg = "0101" then
			memcfg_top <= x"100000";	-- 1M
		elsif memcfg = "1000" or memcfg = "0010" then
			memcfg_top <= x"220000";	-- 2M+128k
		elsif memcfg = "1001" or memcfg = "0110" then
			memcfg_top <= x"280000";	-- 2M+512k
		else
			memcfg_top <= x"400000";	-- 4M
		end if;
	end process;

	-- Bank 0 size = Bank 1 offset (in words)
	process(memcfg)
	begin
		case memcfg(3 downto 2) is
			when "00" => bank0_size <= (17 => '1', others => '0');
			when "01" => bank0_size <= (19 => '1', others => '0');
			when "10" => bank0_size <= (21 => '1', others => '0');
			when others => bank0_size <= (others => '0');
		end case;
	end process;

	-- logical to physical address conversion
	process(log_adr,bank0_size,memcfg,ramcfg)
		variable addr : unsigned(23 downto 1);
		variable bank : integer range 0 to 1;
		variable bank_memcfg : std_logic_vector(1 downto 0);
		variable bank_ramcfg : std_logic_vector(1 downto 0);
	begin
		addr := unsigned(log_adr);
		if addr >= 8 and addr < 16#400000# then
			-- values for bank 0
			bank := 0;
			if unsigned(log_adr) >= bank0_size then
				-- bank 1
				bank := 1;
				addr := addr - bank0_size;
			end if;
			-- convert to address in 2M space
			if bank = 0 then
				bank_memcfg := memcfg(3 downto 2);
			else
				bank_memcfg := memcfg(1 downto 0);
			end if;
			case bank_memcfg is
				when "00" => addr := "00011" & addr(16 downto 9) & "11" & addr(8 downto 1);
				when "01" => addr := "0001" & addr(18 downto 10) & "1" & addr(9 downto 1);
				when others => addr := addr;
			end case;
			-- convert to address in host space
			if bank = 0 then
				bank_ramcfg := ramcfg(3 downto 2);
			else
				bank_ramcfg := ramcfg(1 downto 0);
			end if;
			case bank_ramcfg is
				when "00" => addr := "00000" & addr(18 downto 11) & "00" & addr(8 downto 1);
				when "01" => addr := "0000" & addr(19 downto 11) & "0" & addr(9 downto 1);
				when others => addr := addr;
			end case;
			if bank = 1 then
				addr := addr + 16#100000#;
			end if;
		end if;
		phys_adr <= std_logic_vector(addr);
	end process;

	-- RAM access control
	process(cnt,DMAn,RAMn,iRWn,present_bus,en8fck,mode_bus,sde,video_ptr,mem_top,present_video,video_ptr,iA,dma_ptr)
	begin
		mode_bus_0 <= '0';
		mode_bus_1 <= '0';
		mode_load_0 <= '0';
		mode_load_1 <= '0';
		log_adr <= (others => '0');
		if (cnt = 1 and (DMAn = '0' or (RAMn = '0' and iRWn = '1' and present_bus = '1')))
		or ((cnt = 1 or cnt = 2) and RAMn = '0' and iRWn = '0' and present_bus = '1') then
			mode_bus_1 <= '1';
			-- valid ST RAM/ROM address
			if RAMn = '0' then
				log_adr <= iA;
			elsif DMAn = '0' then
				log_adr <= dma_ptr;
			end if;
		end if;
		if cnt = 2 and en8fck = '1' then
			mode_bus_0 <= '1';
		end if;
		if ((en8fck = '1' and cnt = 2 and mode_bus = '0') or cnt = 3) and sde = '1' and (video_ptr(23 downto 22) = "00" or unsigned(video_ptr(23 downto 18)) <= unsigned(mem_top)) then
			mode_load_1 <= '1';
			if present_video = '1' then
				-- get shifter data
				log_adr <= video_ptr;
			end if;
		end if;
		if en8fck = '1' and cnt = 0 then
			mode_load_0 <= '1';
		end if;
	end process;

	process(clk,resetn)
	begin
		if resetn = '0' then
			mode_bus <= '0';
			mode_load <= '0';
			LATCH <= '1';
			ram_A <= (others => '0');
			ram_DS <= "00";
			ram_R <= '0';
			ram_W <= '0';
		elsif rising_edge(clk) then
			if mode_bus_0 = '1' then
				mode_bus <= '0';
				ram_A <= (others => '0');
				ram_DS <= "00";
				ram_R <= '0';
				ram_W <= '0';
				LATCH <= '1';
			elsif mode_load_0 = '1' then
				mode_load <= '0';
				ram_A <= (others => '0');
				ram_DS <= "00";
				ram_R <= '0';
			elsif mode_bus_1 = '1' then
				mode_bus <= '1';
				-- valid ST RAM/ROM address
				ram_A <= phys_adr;
				if RAMn = '0' then
					ram_DS <= not (iUDSn,iLDSn);
					ram_R <= iRWn;
					ram_W <= iRWn nor (iUDSn and iLDSn);
				elsif DMAn = '0' then
					ram_DS <= "11";
					ram_R <= iRWn;
					ram_W <= not iRWn;
				end if;
				LATCH <= not iRWn;
			elsif mode_load_1 = '1' then
				mode_load <= '1';
				if present_video = '1' then
					-- get shifter data
					ram_A <= phys_adr;
					ram_DS <= "11";
					ram_R <= '1';
				end if;
			end if;
		end if;
	end process;

	-- MMU sequence
	process(clk,resetn)
	begin
	if resetn = '0' then
		sdtackn <= '1';
		cnt <= "00";
		oD <= x"ff";
		screen_adr <= (others => '0');
		video_ptr <= (others => '0');
		memcfg <= (others => '0');
		dma_ptr <= (others => '0');
		sde <= '0';
		loadn <= '1';
		cmpcsn_en <= '0';
	elsif rising_edge(clk) then
		if en8rck = '1' then
			if (RAMn = '0' or DEVn = '0') and cnt = 2 then
				sdtackn <= '0';
			end if;
			if cnt = 0 then
				sdtackn <= '1';
			end if;
			if cnt = 2 then
				cmpcsn_en <= '1';
			end if;
		elsif en8fck = '1' then
			cnt <= cnt + 1;
			oD <= x"ff";

			if VSYNC = '0' then
				video_ptr <= screen_adr & "0000000";
			end if;

			oD <= (others => '1');
			if (cnt = 1 or cnt = 2) and iASn = '0' then
				-- hardware registers
				if iA(23 downto 7) & "0000000" = x"ff8200" then
					if iLDSn = '0' then
						-- video pointer registers
						if iRWn = '1' then
							-- read
							case al is
								when x"01" => oD <= screen_adr(23 downto 16);
								when x"03" => oD <= screen_adr(15 downto 8);
								when x"05" => oD <= video_ptr(23 downto 16);
								when x"07" => oD <= video_ptr(15 downto 8);
								when x"09" => oD <= video_ptr(7 downto 1) & '0';
								when others => oD <= x"ff";
							end case;
						elsif iRWn = '0' and cnt = 2 then
							-- write
							case al is
								when x"01" => screen_adr(23 downto 16) <= iD;
								when x"03" => screen_adr(15 downto 8) <= iD;
								when others =>
							end case;
						end if;
					end if;
				elsif iA(23 downto 1) & '1' = x"ff8001" and iLDSn = '0' then
					-- memory configuration
					if iRWn = '1' then
						-- read
						oD <= "0000" & memcfg;
					elsif iRWn = '0' and cnt = 2 then
						-- write
						memcfg <= iD(3 downto 0);
					end if;
				elsif iA(23 downto 4) & "0000" = x"ff8600" and iLDSn = '0' then
					-- DMA base and counter
					if iRWn = '1' then
						-- read
						case al is
							when x"09" => oD <= dma_ptr(23 downto 16);
							when x"0b" => oD <= dma_ptr(15 downto 8);
							when x"0d" => oD <= dma_ptr(7 downto 1) & '0';
							when others => oD <= x"ff";
						end case;
					elsif iRWn = '0' and cnt = 2 then
						-- write
						case al is
							when x"09" => dma_ptr(23 downto 16) <= iD;
							when x"0b" => dma_ptr(15 downto 8) <= iD;
							when x"0d" => dma_ptr(7 downto 1) <= iD(7 downto 1);
							when others =>
						end case;
					end if;
				end if;
			end if;

			if mode_bus = '1' then
				if DMAn = '0' then
					dma_ptr <= std_logic_vector(unsigned(dma_ptr)+1);
				end if;
			end if;

			if cnt = 3 and mode_load = '1' then
				loadn <= '0';
			end if;
			if loadn = '0' then
				loadn <= '1';
				video_ptr <= std_logic_vector(unsigned(video_ptr)+1);
			end if;
			if cnt = 1 then
				sde <= DE;
			end if;
			if cnt = 3 then
				cmpcsn_en <= '0';
			end if;

		end if;
	end if;

	end process;

end behavioral;
