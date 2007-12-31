-- This only serves in the bootstrapping process, it isn't
-- included in the final compiler. When compiled with std.lua,
-- mlp and bytecode modules, it is able to compile metalua
-- sources into .luac bytecode files.
-- It allows to precompile files such as

print ' *** LOAD BOOTSTRAP with fake MLC'

require 'std'
require 'bytecode'
require 'mlp'

mlc = {  }
mlc.metabugs = false

function mlc.function_of_ast (ast)
   local proto        = bytecode.metalua_compile (ast)
   local dump         = bytecode.dump_string (proto)
   local func         = undump(dump)
   return func
end

local function compile_file (src_filename)
   local src_file     = io.open (src_filename, 'r')
   local src          = src_file:read '*a'; src_file:close()
   local lx           = mlp.lexer:newstream (src)
   local ast          = mlp.chunk (lx)
   local proto        = bytecode.metalua_compile (ast)
   local dump         = bytecode.dump_string (proto)
   local dst_filename = src_filename:gsub ("%.mlua$", ".luac")
   local dst_file     = io.open (dst_filename, 'w')
   dst_file:write(dump)
   dst_file:close()
end


for _, x in ipairs{...} do compile_file (x) end

