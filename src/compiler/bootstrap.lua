-- This only serves in the bootstrapping process, it isn't
-- included in the final compiler. When compiled with std.lua,
-- mlp and bytecode modules, it is able to compile metalua
-- sources into .luac bytecode files.
-- It allows to precompile files such as


package.preload.mlc = function() 

   print "Loading fake mlc module for compiler bootstrapping"

   mlc = { } 
   mlc.metabugs = false

   function mlc.function_of_ast (ast)
      local  proto = bytecode.metalua_compile (ast)
      local  dump  = bytecode.dump_string (proto)
      local  func  = string.undump(dump) 
      return func
   end
   
   function mlc.ast_of_luastring (src)
      local  lx  = mlp.lexer:newstream (src)
      local  ast = mlp.chunk (lx)
      return ast
   end
   
   function mlc.function_of_luastring (src)
      local  ast  = mlc.ast_of_luastring (src)
      local  func = mlc.function_of_ast(ast)
      return func
   end
end

require 'base'
require 'bytecode'
require 'mlp'
require 'package2'

local function compile_file (src_filename)
   print ("Compiling "..src_filename)
   local src_file     = io.open (src_filename, 'r')
   local src          = src_file:read '*a'; src_file:close()
   local ast          = mlc.ast_of_luastring (src)
   local proto        = bytecode.metalua_compile (ast)
   local dump         = bytecode.dump_string (proto)
   local dst_filename = src_filename:gsub ("%.mlua$", ".luac")
   local dst_file     = io.open (dst_filename, 'w')
   dst_file:write(dump)
   dst_file:close()
end


for _, x in ipairs{...} do compile_file (x) end

