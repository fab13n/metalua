-- lua -l mlc_xcall -e 'luafile_to_astfile ("/tmp/tmp12345.lua", "/tmp/tmp54321.ast")'
-- lua -l mlc_xcall -e 'lua_to_astfile ("/tmp/tmp54321.ast")'

mlc_xcall = { }

function mlc_xcall.server (luafilename, astfilename)

   -- We don't want these to be loaded when people only do client-side business
   require 'metalua.compiler'
   require 'serialize'

   -- compile the content of luafile name in an AST, serialized in astfilename
   local ast = mlc.luafile_to_ast (luafilename)
   local out = io.open (astfilename, 'w')
   out:write (serialize (ast))
   out:close ()
end

function mlc_xcall.client_file (luafilename)
   local ast = mlc.luafile_to_ast (luafilename)
   return true, ast
end

function mlc_xcall.client_literal (luasrc)
   local ast = mlc.luastring_to_ast (luafilename)
   return true, ast
end

return mlc_xcall