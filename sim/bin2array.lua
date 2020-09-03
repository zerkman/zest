-- bin2array.lua - convert a binary file into a sequence of VHDL std_logic_vector literals
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

local file,err = io.open(arg[1],"r")
if not file then error(err) end
local str = file:read("*a")
file:close()

for i=1,#str,2 do
  local delim = i%16==15 and ",\n" or ","
  io.write(string.format("x\"%02x%02x\"",str:byte(i,i+1)),delim)
end
