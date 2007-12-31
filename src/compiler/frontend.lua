----------------------------------------------------------------------
-- Metalua:  $Id$
--
-- Summary: Main source file for Metalua compiler.
--
----------------------------------------------------------------------
--
-- Copyright (c) 2006, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------

do
   local level = 0
   local function trace(e)
      local name = debug.getinfo(2).name or "?"
      if e=="call" then 
         print((": "):rep(level) .. e .. " " .. name)
         level=level+1
      elseif e=="return" then 
         level=level-1 
         --print(("."):rep(level) .. e .. " " .. name)
      else
         --print(("."):rep(level) .. e .. " " .. name)
      end
   end
   --debug.sethook(trace, "cr")
end

mlc.SHOW_METABUGS = false
PRINT_AST         = false
EXECUTE           = false
VERBOSE           = false
PRINT_LINE_MAX    = 80
UNIX_SHARPBANG    = [[#!/usr/bin/env lua]]..'\n'
LONG_NAMES   = { 
   help      = "-h" ; 
   ast       = "-a" ; 
   output    = "-o" ;
   metabugs  = "-b" ;
   execute   = "-x" ;
   sharpbang = "-s" ;
   verbose   = "-v" }

USAGE = [[
Metalua compiler.
Usage: mlc [options] [files]
Options:
  --help,     -h: display this help
  --ast,      -a: print the AST resulting from file compilation
  --output,   -o: set the name of the next compiled file
  --execute,  -x: run the function instead of saving it
  --metabugs, -b: undocumented
  --verbose,  -v: verbose

Options -a, -x, -b can be reversed with +a, +x, +b.

Options are taken into account only for the files that appear after them,
e.g. mlc foo.lua -x bar.lua will compile both files, but only execute bar.luac.]]

local function print_if_verbose(msg)
   if VERBOSE then printf("  [%3is]: %s", os.clock(), msg) end
end

-- Compilation of a file:
-- [src_name] is the name of the input file;
-- [dst_name] is the optional name of the output file; if nil, an appropriate
--            name is built from [src_name]
-- What to do with the file is decided by the global variables.

local function compile_file (src_name, dst_name)
   printf("Compiling %s...", src_name)

   print_if_verbose "Build AST"
   local ast = mlc.ast_of_luafile (src_name)
   if not ast then error "Can't open or parse file" end
   if PRINT_AST then table.print(ast, PRINT_LINE_MAX, "nohash") end

   -- Execute and save:
   if EXECUTE and dst_name then
      EXECUTE = false
      dst_name = src_name .. (src_name:match ".*%.lua" and "c" or ".luac")
      print_if_verbose "Build binary dump"
      local bin = mlc.bin_of_ast (ast, src_name)
      if not ast then error "Invalid parse tree" end
      print_if_verbose "Write dump in file"
      mlc.luacfile_of_bin (bin, dst_name)
      printf("...Wrote %s; execute it:", dst_name)
      print_if_verbose "Build function from dump"
      local f = mlc.function_of_bin (bin)
      f()

   -- Execute, don't save
   elseif EXECUTE then
      EXECUTE = false
      print_if_verbose "Build function"
      local f = mlc.function_of_ast(ast)
      if not f then error "Invalid parse tree" end
      printf("...Execute it:", dst_name)
      f()
   -- Save, don't execute
   else
      dst_name = dst_name or      
         src_name .. (src_name:match ".*%.lua" and "c" or ".luac")
      print_if_verbose "Build dump and write to file"
      mlc.luacfile_of_ast(ast, dst_name)
      printf("...Wrote %s.", dst_name)
   end
end

-- argument parsing loop
local i = 1
while i <= #arg do
   local dst_name
   local a = arg[i]
   i=i+1
   local x = a:sub(1,1)
   if x == "-" or x == "+" then
      local bool = (x=="-")
      if bool and a[1]=="-" then
         -- double-dash: read long option
         a = LONG_NAMES [a:sub(2)]
         if not a then 
            printf("Unknown option %s\n\n%s", arg[i], USAGE)
            return -1
         end
      end
      for j = 2, #a do
         local opt = a:sub (j, j)
         if     opt == "h" then print (USAGE); return 0
         elseif opt == "a" then PRINT_AST = bool
         elseif opt == "o" then dst_name = arg[i]; i=i+1
         elseif opt == "b" then mlc.SHOW_METABUGS = bool
         elseif opt == "x" then EXECUTE = bool
         elseif opt == "v" then VERBOSE = bool
         elseif opt == "s" then 
            if bool then UNIX_SHARPBANG = arg[i]; i=i+1
            else UNIX_SHARPBANG = nil end
         else error ("Unknown option -"..opt) end
      end
   else compile_file (a, dst_name) end
end


