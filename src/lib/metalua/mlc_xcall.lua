-- lua -l mlc_xcall -e 'luafile_to_astfile ("/tmp/tmp12345.lua", "/tmp/tmp54321.ast")'
-- lua -l mlc_xcall -e 'lua_to_astfile ("/tmp/tmp54321.ast")'

mlc_xcall = { }


-- This is the back-end function, called in a separate lua process
-- by `mlc_xcall.client_*()' through `os.execute()'.
--  * inputs:
--     * the name of a lua source file to compile in a separate process
--     * the name of a writable file where the resulting ast is dumped
--       with `serialize()'.
--  * results:
--     * an exit status of 0 or -1, depending on whethet compilation
--       succeeded;
--     * the ast file filled will either the serialized ast, or the
--       error message.
function mlc_xcall.server (luafilename, astfilename)

   -- We don't want these to be loaded when people only do client-side business
   require 'metalua.compiler'
   require 'serialize'

   -- compile the content of luafile name in an AST, serialized in astfilename
   local status, ast = pcall (mlc.luafile_to_ast, luafilename)
   local out = io.open (astfilename, 'w')
   if status then -- success
      out:write (serialize (ast))
      out:close ()
      os.exit (0)
   else -- failure, `ast' is actually the error message
      out:write (ast)
      out:close ()
      os.exit (-1)
   end      
end

-- Compile the file whose name is passed as argument, in a separate process,
-- communicating through a temporary file.
-- returns:
--  * true or false, indicating whether the compilation succeeded
--  * the ast, or the error message.
function mlc_xcall.client_file (luafile)

   -- printf("\n\nmlc_xcall.client_file(%q)\n\n", luafile)

   local tmpfilename = os.tmpname()
   local cmd = string.format (
      [=[lua -l metalua.mlc_xcall -e "mlc_xcall.server([[%s]], [[%s]])"]=], 
      luafile, tmpfilename)

   -- printf("os.execute [[%s]]\n\n", cmd)

   local status = (0 == os.execute (cmd))
   local result -- ast or error msg
   if status then 
      result = (lua_loadfile or loadfile) (tmpfilename) ()
   else
      local f = io.open (tmpfilename)
      result = f :read '*a'
      f :close()
   end
   os.remove(tmpfilename)
   return status, result
end

-- Compile a source string into an ast, by dumping it in a tmp
-- file then calling `mlc_xcall.client_file()'.
-- returns: the same as `mlc_xcall.client_file()'.
function mlc_xcall.client_literal (luasrc)
   local srcfilename = os.tmpname()
   local srcfile, msg = io.open (srcfilename, 'w')
   if not srcfile then print(msg) end
   srcfile :write (luasrc)
   srcfile :close ()
   local status, ast = mlc_xcall.client_file (srcfilename)
   os.remove(srcfilename)
   return status, ast
end

return mlc_xcall