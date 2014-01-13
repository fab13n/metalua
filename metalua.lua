-------------------------------------------------------------------------------
-- Copyright (c) 2006-2013 Fabien Fleutot and others.
--
-- All rights reserved.
--
-- This program and the accompanying materials are made available
-- under the terms of the Eclipse Public License v1.0 which
-- accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- This program and the accompanying materials are also made available
-- under the terms of the MIT public license which accompanies this
-- distribution, and is available at http://www.lua.org/license.html
--
-- Contributors:
--     Fabien Fleutot - API and implementation
--
-------------------------------------------------------------------------------

-- Survive lack of checks
if not pcall(require, 'checks') then function package.preload.checks() function checks() end end end

-- Main file for the metalua executable
require 'metalua.loader' -- load *.mlue files
require 'metalua.compiler.globals' -- metalua-aware loadstring, dofile etc.

local alt_getopt = require 'alt_getopt'
local pp  = require 'metalua.pprint'
local mlc = require 'metalua.compiler'

local M = { }

local AST_COMPILE_ERROR_NUMBER        = -1
local RUNTIME_ERROR_NUMBER            = -3

local alt_getopt_options = "f:l:e:o:xivaASbs"

local long_opts = {
    file='f',
    library='l',
    literal='e',
    output='o',
    run='x',
    interactive='i',
    verbose='v',
    ['print-ast']='a',
    ['print-ast-lineinfo']='A',
    ['print-src']='S',
    ['meta-bugs']='b',
    ['sharp-bang']='s',
}

local chunk_options = {
    library=1,
    file=1,
    literal=1
}

local usage=[[

Compile and/or execute metalua programs. Parameters passed to the
compiler should be prefixed with an option flag, hinting what must be
done with them: take tham as file names to compile, as library names
to load, as parameters passed to the running program... When option
flags are absent, metalua tries to adopt a "Do What I Mean" approach:

- if no code (no library, no literal expression and no file) is
  specified, the first flag-less parameter is taken as a file name to
  load.

- if no code and no parameter is passed, an interactive loop is
  started.

- if a target file is specified with --output, the program is not
  executed by default, unless a --run flag forces it to. Conversely,
  if no --output target is specified, the code is run unless ++run
  forbids it.
]]

function M.cmdline_parser(...)
    local argv = {...}
    local opts, optind, optarg =
        alt_getopt.get_ordered_opts({...}, alt_getopt_options, long_opts)
    --pp.printf("argv=%s; opts=%s, ending at %i, with optarg=%s",
    --          argv, opts, optind, optarg)
    local s2l = { } -- short to long option names conversion table
    for long, short in pairs(long_opts) do s2l[short]=long end
    local cfg = { chunks = { } }
    for i, short in pairs(opts) do
        local long = s2l[short]
        if chunk_options[long] then table.insert(cfg.chunks, { tag=long, optarg[i] })
        else cfg[long] = optarg[i] or true end
    end
    cfg.params = { select(optind, ...) }
    return cfg
end

function M.main (...)

   local cfg = M.cmdline_parser(...)

   -------------------------------------------------------------------
   -- Print messages if in verbose mode
   -------------------------------------------------------------------
   local function verb_print (fmt, ...)
      if cfg.verbose then
         return pp.printf ("[ "..fmt.." ]", ...)
      end
   end

   if cfg.verbose then
      verb_print("raw options: %s", cfg)
   end

   -------------------------------------------------------------------
   -- If there's no chunk but there are params, interpret the first
   -- param as a file name.
   if not next(cfg.chunks) and next(cfg.params) then
      local the_file = table.remove(cfg.params, 1)
      verb_print("Param %q considered as a source file", the_file)
      cfg.file={ the_file }
   end

   -------------------------------------------------------------------
   -- If nothing to do, run REPL loop
   if not next(cfg.chunks) and not cfg.interactive then
      verb_print "Nothing to compile nor run, force interactive loop"
      cfg.interactive=true
   end


   -------------------------------------------------------------------
   -- Run if asked to, or if no --output has been given
   -- if cfg.run==false it's been *forced* to false, don't override.
   if not cfg.run and not cfg.output then
      verb_print("No output file specified; I'll run the program")
      cfg.run = true
   end

   local code = { }

   -------------------------------------------------------------------
   -- Get ASTs from sources

   local last_file_idx
   for i, x in ipairs(cfg.chunks) do
      local compiler = mlc.new()
      local tag, val = x.tag, x[1]
      verb_print("Compiling %s", x)
      local st, ast
      if tag=='library' then
          ast = { tag='Call',
                  {tag='Id', "require" },
                  {tag='String', val } }
      elseif tag=='literal' then ast = compiler :src_to_ast(val)
      elseif tag=='file' then
         ast = compiler :srcfile_to_ast(val)
         -- Isolate each file in a separate fenv
         ast = { tag='Call',
                 { tag='Function', { { tag='Dots'} }, ast },
                 { tag='Dots' } }
         ast.source  = '@'..val
         code.source = '@'..val
         last_file_idx = i
      else
          error ("Bad option "..tag)
      end
      local valid = true -- TODO: check AST's correctness
      if not valid then
         pp.printf ("Cannot compile %s:\n%s", x, ast or "no msg")
         os.exit (AST_COMPILE_ERROR_NUMBER)
      end
      ast.origin = x
      table.insert(code, ast)
   end
   -- The last file returns the whole chunk's result
   if last_file_idx then
       -- transform  +{ (function(...) -{ast} end)(...) }
       -- into   +{ return (function(...) -{ast} end)(...) }
       local prv_ast = code[last_file_idx]
       local new_ast = { tag='Return', prv_ast }
       code[last_file_idx] = new_ast
   end

   -- Further uses of compiler won't involve AST transformations:
   -- they can share the same instance.
   -- TODO: reuse last instance if possible.
   local compiler = mlc.new()

   -------------------------------------------------------------------
   -- AST printing
   if cfg['print-ast'] or cfg['print-ast-lineinfo'] then
      verb_print "Resulting AST:"
      for _, x in ipairs(code) do
         pp.printf("--- AST From %s: ---", x.source)
         if x.origin and x.origin.tag=='File' then x=x[1][1][2][1] end
         local pp_cfg = cfg['print-ast-lineinfo']
             and { line_max=1, fix_indent=1, metalua_tag=1 }
             or  { line_max=1, metalua_tag=1, hide_hash=1  }
         pp.print(x, 80, pp_cfg)
      end
   end

   -------------------------------------------------------------------
   -- Source printing
   if cfg['print-src'] then
      verb_print "Resulting sources:"
      for _, x in ipairs(code) do
         printf("--- Source From %s: ---", table.tostring(x.source, 'nohash'))
         if x.origin and x.origin.tag=='File' then x=x[1][1][2] end
         print (compiler :ast2string (x))
      end
   end

   -- TODO: canonize/check AST

   local bytecode = compiler :ast_to_bytecode (code)
   code = nil

   -------------------------------------------------------------------
   -- Insert #!... command
   if cfg.sharpbang then
      local shbang = cfg.sharpbang
      verb_print ("Adding sharp-bang directive %q", shbang)
      if not shbang :match'^#!' then shbang = '#!' .. shbang end
      if not shbang :match'\n$' then shbang = shbang .. '\n' end
      bytecode = shbang .. bytecode
   end

   -------------------------------------------------------------------
   -- Save to file
   if cfg.output then
      -- FIXME: handle '-'
      verb_print ("Saving to file %q", cfg.output)
      local file, err_msg = io.open(cfg.output, 'wb')
      if not file then error("can't open output file: "..err_msg) end
      file:write(bytecode)
      file:close()
      if cfg.sharpbang and os.getenv "OS" ~= "Windows_NT" then
         pcall(os.execute, 'chmod a+x "'..cfg.output..'"')
      end
   end

   -------------------------------------------------------------------
   -- Run compiled code
   if cfg.run then
      verb_print "Running"
      local f = compiler :bytecode_to_function (bytecode)
      bytecode = nil
      -- FIXME: isolate execution in a ring
      -- FIXME: check for failures
      local function print_traceback (errmsg)
         return errmsg .. '\n' .. debug.traceback ('',2) .. '\n'
      end
      local function g() return f(unpack (cfg.params)) end
      local st, msg = xpcall(g, print_traceback)
      if not st then
         io.stderr:write(msg)
         os.exit(RUNTIME_ERROR_NUMBER)
      end
   end

   -------------------------------------------------------------------
   -- Run REPL loop
   if cfg.interactive then
      verb_print "Starting REPL loop"
      require 'metalua.repl' .run()
   end

   verb_print "Done"

end

return M.main(...)
