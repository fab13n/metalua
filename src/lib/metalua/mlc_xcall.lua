-- Does nothing: processes are simply run all in the same lua state for now.

mlc_xcall = { }

function mlc_xcall.client_file (luafilename)
   local ast = mlc.luafile_to_ast (luafilename)
   return true, ast
end

function mlc_xcall.client_literal (luasrc)
   local ast = mlc.luastring_to_ast (luafilename)
   return true, ast
end

return mlc_xcall