-- minimal fake io module for kahlua; based on kahmetalua.readfile (filename) and
-- kahmetalua.writefile (filename, content), which read/write the whole file
-- content in one single step.


local READ = { }; READ.__index = READ
local WRITE = { }; WRITE.__index = WRITE


function READ:read(x)
   if x == '*a' then 
      local result = x :sub (self.content, self.i, -1)
      self.i = #self.content+1
      return result
   elseif x=='*l' then
      local result, new_i = x :match ("(.-)\n()", self.i)
      self.i = new_i
      return result
   else
      error ("read param "..x.." not supported")
   end
end

function WRITE:write(x)
   table.insert (self.content, x)
end

function READ:close()
end

function WRITE:close()
   local content = table.concat (self.content)
   kahmetalua.writefile (content)
end
      
local function new_filereader(filename)
   local content = kahmetalua.readfile (filename)
   local self = { content=content; i=1 }
   return setmetatable (self, READ)
end

local function new_filewriter(filename)
   local self = { content={ } }
   return setmetatable (self, WRITE)
end

io = { }

function io.open (filename, direction)
   if direction:match 'w' then return new_filewriter(filename)
   else return new_filereader(filename) end
end