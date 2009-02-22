--------------------------------------------------------------------------------
-- Execute an `mlc.ast_of_*()' in a separate lua process.
-- Communication between processes goes through temporary files,
-- for the sake of portability.
--------------------------------------------------------------------------------

mlc_xcall = { }

--------------------------------------------------------------------------------
-- Number of lines to remove at the end of a traceback, should it be
-- dumped due to a compilation error in metabugs mode.
--------------------------------------------------------------------------------
local STACK_LINES_TO_CUT = 7

--------------------------------------------------------------------------------
-- (Not intended to be called directly by users)
--
-- This is the back-end function, called in a separate lua process
-- by `mlc_xcall.client_*()' through `os.execute()'.
--  * inputs:
--     * the name of a lua source file to compile in a separate process
--     * the name of a writable file where the resulting ast is dumped
--       with `serialize()'.
--     * metabugs: if true and an error occurs during compilation,
--       the compiler's stacktrace is printed, allowing meta-programs
--       debugging.
--  * results:
--     * an exit status of 0 or -1, depending on whethet compilation
--       succeeded;
--     * the ast file filled will either the serialized ast, or the
--       error message.
--------------------------------------------------------------------------------
function mlc_xcall.server (luafilename, astfilename, metabugs)

   -- We don't want these to be loaded when people only do client-side business
   require 'metalua.compiler'
   require 'serialize'

   mlc.metabugs = metabugs

   -- compile the content of luafile name in an AST, serialized in astfilename
   --local status, ast = pcall (mlc.luafile_to_ast, luafilename)
   local status, ast
   local function compile() return mlc.luafile_to_ast (luafilename) end
   if mlc.metabugs then 
      print 'mlc_xcall.server/metabugs'
      --status, ast = xpcall (compile, debug.traceback)
      --status, ast = xpcall (compile, debug.traceback)
      local function tb(msg)
         local r = debug.traceback(msg)

         -- Cut superfluous end lines
         local line_re = '\n[^\n]*'
         local re =  "^(.-)" .. (line_re) :rep (STACK_LINES_TO_CUT) .. "$"
         return r :strmatch (re) or r
      end
      --status, ast = xpcall (compile, debug.traceback)
      status, ast = xpcall (compile, tb)
   else status, ast = pcall (compile) end
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

--------------------------------------------------------------------------------
-- Compile the file whose name is passed as argument, in a separate process,
-- communicating through a temporary file.
-- returns:
--  * true or false, indicating whether the compilation succeeded
--  * the ast, or the error message.
--------------------------------------------------------------------------------
function mlc_xcall.client_file (luafile)

   -- printf("\n\nmlc_xcall.client_file(%q)\n\n", luafile)

   local tmpfilename = os.tmpname()
   local cmd = string.format (
      [=[lua -l metalua.mlc_xcall -e "mlc_xcall.server([[%s]], [[%s]], %s)"]=], 
      luafile, tmpfilename, mlc.metabugs and "true" or "false")

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

--------------------------------------------------------------------------------
-- Compile a source string into an ast, by dumping it in a tmp
-- file then calling `mlc_xcall.client_file()'.
-- returns: the same as `mlc_xcall.client_file()'.
--------------------------------------------------------------------------------
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