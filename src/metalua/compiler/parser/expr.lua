----------------------------------------------------------------------
-- Metalua:  $Id: mlp_expr.lua,v 1.7 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: metalua parser, expression parser. This is part of the
--   definition of module [mlp].
--
----------------------------------------------------------------------
--
-- Copyright (c) 2006, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------
-- History:
-- $Log: mlp_expr.lua,v $
-- Revision 1.7  2006/11/15 09:07:50  fab13n
-- debugged meta operators.
-- Added command line options handling.
--
-- Revision 1.6  2006/11/10 02:11:17  fab13n
-- compiler faithfulness to 5.1 improved
-- gg.expr extended
-- mlp.expr refactored
--
-- Revision 1.5  2006/11/09 09:39:57  fab13n
-- some cleanup
--
-- Revision 1.4  2006/11/07 21:29:02  fab13n
-- improved quasi-quoting
--
-- Revision 1.3  2006/11/07 04:38:00  fab13n
-- first bootstrapping version.
--
-- Revision 1.2  2006/11/05 15:08:34  fab13n
-- updated code generation, to be compliant with 5.1
--
----------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- Exported API:
-- * [mlp.expr()]
-- * [mlp.expr_list()]
-- * [mlp.func_val()]
--
--------------------------------------------------------------------------------

local gg  = require 'metalua.grammar.generator'
local mlp = require 'metalua.compiler.parser.common'
local M   = { }

local mlp_table = require 'metalua.compiler.parser.table'
local mlp_meta  = require 'metalua.compiler.parser.meta'
local mlp_misc  = require 'metalua.compiler.parser.misc'

-- Delayed dependencies toward externally-defined parsers
local function block (lx) return mlp.block (lx) end
local function stat (lx) return mlp.stat (lx)  end

-- For recursive definitions
local function expr (lx) return M.expr (lx) end

local id = mlp_misc.id


--------------------------------------------------------------------------------
-- Non-empty expression list. Actually, this isn't used here, but that's
-- handy to give to users.
--------------------------------------------------------------------------------
M.expr_list = gg.list{ primary=expr, separators="," }

--------------------------------------------------------------------------------
-- Helpers for function applications / method applications
--------------------------------------------------------------------------------
M.func_args_content = gg.list{ 
    name        = "function arguments",
    primary     = expr,
    separators  = ",", 
    terminators = ")" } 

-- Used to parse methods
M.method_args = gg.multisequence{
   name = "function argument(s)",
   { "{",  mlp_table.content, "}" },
   { "(",  M.func_args_content, ")", builder = unpack },
   { "+{", mlp_meta.quote_content, "}" }, 
   function(lx) local r = mlp.opt_string(lx); return r and {r} or { } end }

--------------------------------------------------------------------------------
-- [func_val] parses a function, from opening parameters parenthese to
-- "end" keyword included. Used for anonymous functions as well as
-- function declaration statements (both local and global).
--
-- It's wrapped in a [_func_val] eta expansion, so that when expr
-- parser uses the latter, they will notice updates of [func_val]
-- definitions.
--------------------------------------------------------------------------------
M.func_params_content = gg.list{ name="function parameters",
   gg.multisequence{ { "...", builder = "Dots" }, id },
   separators  = ",", terminators = {")", "|"} } 

local func_params_content = function (lx) return M.func_params_content(lx) end

M.func_val = gg.sequence { name="function body",
   "(", M.func_params_content, ")", block, "end", builder = "Function" }

local func_val = function(lx) return M.func_val(lx) end

--------------------------------------------------------------------------------
-- Default parser for primary expressions
--------------------------------------------------------------------------------
function M.id_or_literal (lx)
   local a = lx:next()
   if a.tag~="Id" and a.tag~="String" and a.tag~="Number" then
      local msg
      if a.tag=='Eof' then
         msg = "End of file reached when an expression was expected"
      elseif a.tag=='Keyword' then
         msg = "An expression was expected, and `"..a[1]..
            "' can't start an expression"
      else
         msg = "Unexpected expr token " .. table.tostring (a, 'nohash')
      end
      return gg.parse_error (lx, msg)
   end
   return a
end


--------------------------------------------------------------------------------
-- Builder generator for operators. Wouldn't be worth it if "|x|" notation
-- were allowed, but then lua 5.1 wouldn't compile it 
--------------------------------------------------------------------------------

-- opf1 = |op| |_,a| `Op{ op, a }
local function opf1 (op) return 
   function (_,a) return { tag="Op", op, a } end end

-- opf2 = |op| |a,_,b| `Op{ op, a, b }
local function opf2 (op) return 
   function (a,_,b) return { tag="Op", op, a, b } end end

-- opf2r = |op| |a,_,b| `Op{ op, b, a } -- (args reversed)
local function opf2r (op) return 
   function (a,_,b) return { tag="Op", op, b, a } end end

local function op_ne(a, _, b)
    -- This version allows to remove the "ne" operator from the AST definition.
    -- However, it doesn't always produce the exact same bytecode as Lua 5.1.
    return { tag="Op", "not", 
             { tag="Op", "eq", a, b, lineinfo= {
                   first = a.lineinfo.first, last = b.lineinfo.last } } }
end
   

--------------------------------------------------------------------------------
--
-- complete expression
--
--------------------------------------------------------------------------------

-- FIXME: set line number. In [expr] transformers probably

M.expr = gg.expr { name = "expression",

   primary = gg.multisequence{ name="expr primary",
      { "(", expr, ")",                     builder = "Paren" },
      { "function", func_val,               builder = unpack },
      { "-{", mlp_meta.splice_content, "}", builder = unpack },
      { "+{", mlp_meta.quote_content, "}",  builder = unpack }, 
      { "nil",                              builder = "Nil" },
      { "true",                             builder = "True" },
      { "false",                            builder = "False" },
      { "...",                              builder = "Dots" },
      mlp_table.table,
      M.id_or_literal },

   infix = { name="expr infix op",
      { "+",  prec = 60, builder = opf2 "add"  },
      { "-",  prec = 60, builder = opf2 "sub"  },
      { "*",  prec = 70, builder = opf2 "mul"  },
      { "/",  prec = 70, builder = opf2 "div"  },
      { "%",  prec = 70, builder = opf2 "mod"  },
      { "^",  prec = 90, builder = opf2 "pow",    assoc = "right" },
      { "..", prec = 40, builder = opf2 "concat", assoc = "right" },
      { "==", prec = 30, builder = opf2 "eq"  },
      { "~=", prec = 30, builder = op_ne  },
      { "<",  prec = 30, builder = opf2 "lt"  },
      { "<=", prec = 30, builder = opf2 "le"  },
      { ">",  prec = 30, builder = opf2r "lt"  },
      { ">=", prec = 30, builder = opf2r "le"  },
      { "and",prec = 20, builder = opf2 "and" },
      { "or", prec = 10, builder = opf2 "or"  } },

   prefix = { name="expr prefix op",
      { "not", prec = 80, builder = opf1 "not" },
      { "#",   prec = 80, builder = opf1 "len" },
      { "-",   prec = 80, builder = opf1 "unm" } },

   suffix = { name="expr suffix op",
      { "[", expr, "]", builder = function (tab, idx)
         return {tag="Index", tab, idx[1]} end},
      { ".", id, builder = function (tab, field) 
         return {tag="Index", tab, mlp_misc.id2string(field[1])} end },
      { "(", M.func_args_content, ")", builder = function(f, args) 
         return {tag="Call", f, unpack(args[1])} end },
      { "{", mlp_table.content, "}", builder = function (f, arg)
         return {tag="Call", f, arg[1]} end},
      { ":", id, M.method_args, builder = function (obj, post)
         return {tag="Invoke", obj, mlp_misc.id2string(post[1]), unpack(post[2])} end},
      { "+{", mlp_meta.quote_content, "}", builder = function (f, arg) 
         return {tag="Call", f,  arg[1] } end },
      default = { name="opt_string_arg", parse = mlp_misc.opt_string, builder = function(f, arg) 
         return {tag="Call", f, arg } end } } }

return M