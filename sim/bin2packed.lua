-- bin2packed.lua - convert a binary file into a packed sequence of VHDL std_logic_vector literals
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

local ntracks = 160

local file,err = io.open(arg[1],"r")
if not file then error(err) end
local str = file:read("*a")
file:close()

local function printlast(i1,i2,c)
  if c ~= 0 then
    if i1 ~= i2 then
      io.write(string.format("%d to %d => x\"%02x\",\n",i1,i2,c));
    else
      io.write(string.format("%d => x\"%02x\",\n",i1,c));
    end
  end
end

local c
local lastc,lasti = str:byte(1,1),0
for i=1,ntracks*6250-1 do
  c = str:byte(i+1,i+1)
  if c ~= lastc then
    printlast(lasti,i-1,lastc)
    lastc = c
    lasti = i
  end
end
printlast(lasti,ntracks*6250-1,lastc)
