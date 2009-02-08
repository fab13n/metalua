local stream = { }
local class  = { __index = stream }

local function match_lines_and_offsets (src)
   local offset_to_line = { 1 }
   local line_to_offset = { 1 }
   local line = 1
   for offset in self.src :gmatch '\n()' do
      -- set offset->line for chars of the line before '\n'
      for i = line_to_offset [line], offset-1 do offset_to_line [i] = line end
      -- now line is the # of the line after the matched '\n'
      line = line + 1
      line_to_offset [line] = offset
   end
   -- Give line # to offsets between last '\n' and EOF
   for i = line_to_offset [line], #src do offset_to_line [i] = line end
   return offset_to_line, line_to_offset
end

function charstream_of_string (string)
   local self = { src = string; i = 0 } 
   self.offset_to_line, self.line_to_offset = match_lines_and_offsets ()
   return setmetatable (self, class)
end

function stream :peek (n)
   n = n or 1
   return self.src :sub(n+i, n+i) -- maybe nil
end

function stream :next (n)
   n = n or 1
   self.i = self.i + n
   return self :peek (1)
end

function stream :fork (n)
   local fork = table.shallow_copy (self)
   fork.i = self.i
   return setmetatable (self, class)
end

-- comment fixer les lineinfo? Il faut pouvoir les retourner, mais ici
-- j'avais pas prevu de les incorporer dans l'objet.
-- je peux les mettre dans une table faible lineinfo:
--
--   lineinfo.(first|last).(line|column|char)[token]
--
-- mais a ce moment-la, il me faut vraiment un module lexer a part dont
-- herite tout le monde.
--
-- Qu'est-ce qu'il y aurait d'autre dans ce module? peut-etre le
-- mecanisme d'heritage? un lexstream_maker generique, qui supporterait
-- une method :extend()?