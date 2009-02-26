-- This utility bootstraps the metalua compiler:
-- * The compiler itself is written partly in lua, partly in metalua.
-- * This program uses the lua parts of the compiler to compile the metalua parts.
--
-- Usage: bootstrap output=<resulting file> inputdir=<source directory> <src_1> ... <src_n>
--


cfg = { inputs = { } }
for _, a in ipairs(arg) do
   local var, val = a :match "^(.-)=(.*)"
   if var then cfg[var] = val else table.insert (cfg.inputs, a) end
end

-- metalua.mlc doesn't exist yet; this preload manager loads a mockup which is just
-- sufficient to compile the real mlc.mlua
package.preload['metalua.mlc'] = function()

   print "Loading fake metalua.mlc module for compiler bootstrapping"

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

   function mlc.function_of_luafile (name)
      local f   = io.open(name, 'r')
      local src = f:read '*a'
      f:close()
      return mlc.function_of_luastring (src, "@"..name)
   end

   -- don't let require() fork a separate process for *.mlua compilations.
   package.metalua_nopopen = true
end

require 'verbose_require'
require 'metalua.base'
require 'metalua.bytecode'
require 'metalua.mlp'
require 'metalua.package2'

local function compile_file (src_filename)
   print("Compiling "..src_filename.."... ")
   local src_file     = io.open (src_filename, 'r')
   local src          = src_file:read '*a'; src_file:close()
   local ast          = mlc.ast_of_luastring (src)
   local proto        = bytecode.metalua_compile (ast, '@'..src_filename)
   local dump         = bytecode.dump_string (proto)
   local dst_filename = cfg.output or error "no output file name specified"
   local dst_file     = io.open (dst_filename, 'wb')
   dst_file:write(dump)
   dst_file:close()
   print("...Wrote "..dst_filename)
end

if cfg.inputdir then
   local sep = package.config:sub(1,1)
   if not cfg.inputdir :match (sep..'$') then cfg.inputdir = cfg.inputdir..sep end
else
   cfg.inputdir=""
end

for _, x in ipairs (cfg.inputs) do compile_file (cfg.inputdir..x) end

