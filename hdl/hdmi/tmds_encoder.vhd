-- tmds_encoder.vhd - TMDS encoder
--
-- Copyright (c) 2021 Francois Galea <fgalea at free.fr>
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

entity tmds_encoder is
	generic (
		CHN    : integer := 0		-- TMDS channel number 0:blue, 1:green, 2:red
	);
	port (
		clk    : in std_logic;
		reset  : in std_logic;
		data   : in std_logic_vector(7 downto 0);
		de     : in std_logic;		-- display enable
		ae     : in std_logic;		-- auxiliary channel enable
		vgb    : in std_logic;		-- video leading guard band
		dgb    : in std_logic;		-- data island leading or trailing guard band
		tmds_d : out std_logic_vector(9 downto 0)
	);
end tmds_encoder;

architecture rtl of tmds_encoder is
	signal cnt : signed(4 downto 0);

	function n1 (x : in std_logic_vector) return integer is
		variable n : integer;
		begin
			n := 0;
			for i in x'range loop
				if x(i) = '1' then
					n := n + 1;
				end if;
			end loop;
			return n;
	end function;
begin

process(clk)
	variable q_m : std_logic_vector(8 downto 0);
	variable n1_q_m : integer;
	variable n1_n0 : integer;
begin
	if rising_edge(clk) then
		if reset = '1' then
			tmds_d <= "1101010100";
			cnt <= "00000";
		else
			if vgb = '1' then
				-- video guard band
				if CHN = 1 then
					tmds_d <= "0100110011";
				else
					tmds_d <= "1011001100";
				end if;
			elsif dgb = '1' and CHN /= 0 then
				-- data island leading or trailing guard band
				tmds_d <= "0100110011";
				-- When CHN = 0, fall back to TERC4 encoding of "11" & vsync & hsync
			elsif de = '1' then
				-- video encoding
				q_m(0) := data(0);
				if n1(data) > 4 or (n1(data) = 4 and data(0) = '0') then
					for i in 1 to 7 loop
						q_m(i) := q_m(i-1) xnor data(i);
					end loop;
					q_m(8) := '0';
				else
					for i in 1 to 7 loop
						q_m(i) := q_m(i-1) xor data(i);
					end loop;
					q_m(8) := '1';
				end if;

				-- number of 1's in q_m(7 downto 0)
				n1_q_m := n1(q_m(7 downto 0));
				-- number of 1's minus number of 0's in q_m(7 downto 0)
				n1_n0 := (n1_q_m-4)*2;
				if cnt = 0 or n1_q_m = 4 then
					tmds_d(9) <= not q_m(8);
					tmds_d(8) <= q_m(8);
					if q_m(8) = '1' then
						tmds_d(7 downto 0) <= q_m(7 downto 0);
						cnt <= cnt + n1_n0;
					else
						tmds_d(7 downto 0) <= not q_m(7 downto 0);
						cnt <= cnt - n1_n0;
					end if;
				elsif (cnt > 0 and n1_q_m > 4) or (cnt < 0 and n1_q_m < 4) then
					tmds_d(9) <= '1';
					tmds_d(8) <= q_m(8);
					tmds_d(7 downto 0) <= not q_m(7 downto 0);
					if q_m(8) = '1' then
						cnt <= cnt + 2 - n1_n0;
					else
						cnt <= cnt - n1_n0;
					end if;
				else
					tmds_d(9) <= '0';
					tmds_d(8) <= q_m(8);
					tmds_d(7 downto 0) <= q_m(7 downto 0);
					if q_m(8) = '0' then
						cnt <= cnt - 2 + n1_n0;
					else
						cnt <= cnt + n1_n0;
					end if;
				end if;
			elsif ae = '1' then
				-- TERC4 Encoding
				case data(3 downto 0) is
					when "0000" => tmds_d <= "1010011100";
					when "0001" => tmds_d <= "1001100011";
					when "0010" => tmds_d <= "1011100100";
					when "0011" => tmds_d <= "1011100010";
					when "0100" => tmds_d <= "0101110001";
					when "0101" => tmds_d <= "0100011110";
					when "0110" => tmds_d <= "0110001110";
					when "0111" => tmds_d <= "0100111100";
					when "1000" => tmds_d <= "1011001100";
					when "1001" => tmds_d <= "0100111001";
					when "1010" => tmds_d <= "0110011100";
					when "1011" => tmds_d <= "1011000110";
					when "1100" => tmds_d <= "1010001110";
					when "1101" => tmds_d <= "1001110001";
					when "1110" => tmds_d <= "0101100011";
					when others => tmds_d <= "1011000011";
				end case;
			else
				-- CTL encoding
				case data(1 downto 0) is
					when "00" => tmds_d <= "1101010100";
					when "01" => tmds_d <= "0010101011";
					when "10" => tmds_d <= "0101010100";
					when others => tmds_d <= "1010101011";
				end case;
			end if;
			if de = '0' then
				cnt <= "00000";
			end if;
		end if;
	end if;
end process;

end architecture;
