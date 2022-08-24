-- mmu.vhd - Implementation of the Atari ST MMU chip
--
-- Copyright (c) 2020-2022 Francois Galea <fgalea at free.fr>
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
		-- DMA RAM access (use DMA pointer instead of address bus)
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
		mem_top	: in std_logic_vector(3 downto 0);
		-- wakestate
		wakest	: in std_logic_vector(1 downto 0);

		-- interface to RAM. Using own signals instead of hardware specific ones
		ram_A	: out std_logic_vector(23 downto 1);
		ram_W	: out std_logic;
		ram_R	: out std_logic;
		ram_DS	: out std_logic_vector(1 downto 0)
	);
end mmu;

architecture behavioral of mmu is
	signal memcfg			: std_logic_vector(3 downto 0);
	signal cnt				: unsigned(1 downto 0);
	signal screen_adr		: std_logic_vector(23 downto 8);
	signal video_ptr		: std_logic_vector(23 downto 1);
	signal dma_ptr			: std_logic_vector(23 downto 1);
	signal al				: std_logic_vector(7 downto 0);
	signal delay_loadn		: std_logic;
	signal delay_bus		: std_logic;
	signal mode_bus			: std_logic;
	signal mode_bus_ff		: std_logic;
	signal mode_load		: std_logic;
	signal sdtackn			: std_logic;
	signal sde				: std_logic;
	signal loadn			: std_logic;

begin

	al <= iA(7 downto 1) & '1';
	mode_bus <= '1' when cnt = 1 and (DMAn = '0' or (RAMn = '0' and (iA(23 downto 18) <= "00"&mem_top or iA(23 downto 22) /= "00"))) else '0';
	DTACKn <= sdtackn;
	DCYCn <= loadn;
	RDATn <= RAMn or delay_loadn;

	-- RAM access control
	process(mode_load,delay_bus,delay_loadn,video_ptr,mode_bus,mode_bus_ff,iA,iUDSn,iLDSn,iRWn,RAMn,DMAn,dma_ptr)
	begin
		LATCH <= '1';
		ram_A <= (others => '0');
		ram_DS <= "00";
		ram_R <= '0';
		ram_W <= '0';
		if mode_load = '1' and delay_bus = '0' then
			-- get shifter data
			ram_A <= video_ptr;
			ram_DS <= "11";
			ram_R <= '1';
			ram_W <= '0';
		elsif (mode_bus = '1' or mode_bus_ff = '1') and delay_loadn = '0' then
			-- valid ST RAM/ROM address
			if RAMn = '0' then
				ram_A <= iA;
				ram_DS <= not (iUDSn,iLDSn);
				ram_R <= iRWn;
				ram_W <= iRWn nor (iUDSn and iLDSn);
			elsif DMAn = '0' then
				ram_A <= dma_ptr;
				ram_DS <= "11";
				ram_R <= iRWn;
				ram_W <= not iRWn;
			end if;
			LATCH <= not iRWn;
		end if;
	end process;

	-- MMU sequence
	process(clk)
	begin
	if rising_edge(clk) then
		delay_loadn <= '0';
		delay_bus <= '0';
		if resetn = '0' then
			sdtackn <= '1';
			cnt <= unsigned(wakest);
			CMPCSn <= '1';
			oD <= x"ff";
			mode_bus_ff <= '0';
			mode_load <= '0';
			screen_adr <= (others => '0');
			video_ptr <= (others => '0');
			memcfg <= (others => '0');
			dma_ptr <= (others => '0');
			loadn <= '1';
		elsif en8rck = '1' then
			if (RAMn = '0' or DEVn = '0') and cnt = 2 then
				sdtackn <= '0';
			end if;
			if cnt = 0 then
				sdtackn <= '1';
				sde <= DE;
			end if;
			if cnt = 0 and mode_load = '1' then
				loadn <= '0';
			end if;
			if cnt = 1 and loadn = '0' then
				loadn <= '1';
				mode_load <= '0';
				delay_loadn <= '1';
				video_ptr <= std_logic_vector(unsigned(video_ptr)+1);
			end if;
		elsif en8fck = '1' then
			mode_bus_ff <= mode_bus or mode_bus_ff;
			cnt <= cnt + 1;
			CMPCSn <= '1';
			oD <= x"ff";
			if cnt = 2 then
				mode_bus_ff <= '0';
			end if;

			if VSYNC = '0' then
				video_ptr <= screen_adr & "0000000";
			end if;

			oD <= (others => '1');
			if (cnt = 1 or cnt = 2) and iASn = '0' then
				-- hardware registers
				if iA(23 downto 7) & "0000000" = x"ff8200" then
					if al >= x"40" then
						-- shifter registers
						CMPCSn <= '0';
					elsif iLDSn = '0' then
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

			if cnt = 3 and sde = '1' then
				mode_load <= '1';
			end if;

			if mode_bus_ff = '1' and cnt = 2 then
				delay_bus <= '1';
				if DMAn = '0' then
					dma_ptr <= std_logic_vector(unsigned(dma_ptr)+1);
				end if;
			end if;
		end if;
	end if;

	end process;

end behavioral;
