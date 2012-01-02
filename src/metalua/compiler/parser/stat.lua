----------------------------------------------------------------------
-- Metalua:  $Id: mlp_stat.lua,v 1.7 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: metalua parser, statement/block parser. This is part of
--   the definition of module [mlp].
--
----------------------------------------------------------------------
--
-- Copyright (c) 2006, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------
--
----------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- Exports API:
-- * [mlp.stat()]
-- * [mlp.block()]
-- * [mlp.for_header()]
--
--------------------------------------------------------------------------------

local mlp      = require 'metalua.compiler.parser.common'
local mlp_misc = require 'metalua.compiler.parser.misc'
local mlp_meta = require 'metalua.compiler.parser.meta'
local gg       = require 'metalua.grammar.generator'
local M        = { }

--------------------------------------------------------------------------------
-- eta-expansions to break circular dependency
--------------------------------------------------------------------------------
local expr      = function (lx) return mlp.expr     (lx) end
local func_val  = function (lx) return mlp.func_val (lx) end
local expr_list = function (lx) return mlp.expr_list(lx) end

--------------------------------------------------------------------------------
-- List of all keywords that indicate the end of a statement block. Users are
-- likely to extend this list when designing extensions.
--------------------------------------------------------------------------------


M.block_terminators = { "else", "elseif", "end", "until", ")", "}", "]" }

-- FIXME: this must be handled from within GG!!!
function M.block_terminators :add(x) 
   if type (x) == "table" then for _, y in ipairs(x) do self :add (y) end
   else table.insert (self, x) end
end

--------------------------------------------------------------------------------
-- list of statements, possibly followed by semicolons
--------------------------------------------------------------------------------
M.block = gg.list {
   name        = "statements block",
   terminators = M.block_terminators,
   primary     = function (lx)
      -- FIXME use gg.optkeyword()
      local x = mlp.stat (lx)
      if lx:is_keyword (lx:peek(), ";") then lx:next() end
      return x
   end }

--------------------------------------------------------------------------------
-- Helper function for "return <expr_list>" parsing.
-- Called when parsing return statements.
-- The specific test for initial ";" is because it's not a block terminator,
-- so without itgg.list would choke on "return ;" statements.
-- We don't make a modified copy of block_terminators because this list
-- is sometimes modified at runtime, and the return parser would get out of
-- sync if it was relying on a copy.
--------------------------------------------------------------------------------
local return_expr_list_parser = gg.multisequence{
   { ";" , builder = function() return { } end }, 
   default = gg.list { 
      expr, separators = ",", terminators = block_terminators } }


local for_vars_list = gg.list{
    name        = "for variables list",
    primary     = mlp_misc.id,
    separators  = ",", 
    terminators = "in" }

--------------------------------------------------------------------------------
-- for header, between [for] and [do] (exclusive).
-- Return the `Forxxx{...} AST, without the body element (the last one).
--------------------------------------------------------------------------------
function M.for_header (lx)
   local var = mlp.id (lx)
   if lx:is_keyword (lx:peek(), "=") then 
      -- Fornum: only 1 variable
      lx:next() -- skip "="
      local e = mlp.expr_list (lx)
      assert (2 <= #e and #e <= 3, "2 or 3 values in a fornum")
      return { tag="Fornum", var, unpack (e) }
   else
      -- Forin: there might be several vars
      local a = lx:is_keyword (lx:next(), ",", "in")
      local var_list
      if a=="in" then var_list = { var, lineinfo = var.lineinfo } else
         -- several vars; first "," skipped, read other vars
         var_list = for_vars_list(lx)
         table.insert (var_list, 1, var) -- put back the first variable
         lx:next() -- skip "in"
      end
      local e = mlp.expr_list (lx)
      return { tag="Forin", var_list, e }
   end
end

--------------------------------------------------------------------------------
-- Function def parser helper: id ( . id ) *
--------------------------------------------------------------------------------
local function fn_builder (list)
   local r = list[1]
   for i = 2, #list do r = { tag="Index", r, mlp.id2string(list[i]) } end
   return r
end
local func_name = gg.list{ mlp_misc.id, separators = ".", builder = fn_builder }

--------------------------------------------------------------------------------
-- Function def parser helper: ( : id )?
--------------------------------------------------------------------------------
local method_name = gg.onkeyword{ name = "method invocation", ":", mlp_misc.id, 
   transformers = { function(x) return x and x.tag=='Id' and mlp_misc.id2string(x) end } }

--------------------------------------------------------------------------------
-- Function def builder
--------------------------------------------------------------------------------
local function funcdef_builder(x)

   local name   = x[1] or gg.earlier_error()
   local method = x[2]
   local func   = x[3] or gg.earlier_error()


   if method then 
      name = { tag="Index", name, method, lineinfo = {
         first = name.lineinfo.first,
         last  = method.lineinfo.last } }
      table.insert (func[1], 1, {tag="Id", "self"}) 
   end
   local r = { tag="Set", {name}, {func} } 
   r[1].lineinfo = name.lineinfo
   r[2].lineinfo = func.lineinfo
   return r
end 


--------------------------------------------------------------------------------
-- if statement builder
--------------------------------------------------------------------------------
local function if_builder (x)
   local cb_pairs, else_block, r = x[1], x[2], {tag="If"}
   for i=1,#cb_pairs do r[2*i-1]=cb_pairs[i][1]; r[2*i]=cb_pairs[i][2] end
   if else_block then r[#r+1] = else_block end
   return r
end 

--------------------------------------------------------------------------------
-- produce a list of (expr,block) pairs
--------------------------------------------------------------------------------
local elseifs_parser = gg.list {
   gg.sequence { expr, "then", M.block },
   separators  = "elseif",
   terminators = { "else", "end" } }

--------------------------------------------------------------------------------
-- assignments and calls: statements that don't start with a keyword
--------------------------------------------------------------------------------
local function assign_or_call_stat_parser (lx)
   local e = mlp.expr_list (lx)
   local a = lx:is_keyword(lx:peek())
   local op = a and mlp.stat.assignments[a]
   if op then
      --FIXME: check that [e] is a LHS
      lx:next()
      local v = mlp.expr_list (lx)
      if type(op)=="string" then return { tag=op, e, v }
      else return op (e, v) end
   else 
      assert (#e > 0)
      if #e > 1 then 
         return gg.parse_error (lx, 
            "comma is not a valid statement separator; statement can be "..
            "separated by semicolons, or not separated at all") end
      if e[1].tag ~= "Call" and e[1].tag ~= "Invoke" then
         local typename
         if e[1].tag == 'Id' then 
            typename = '("'..e[1][1]..'") is an identifier'
         elseif e[1].tag == 'Op' then 
            typename = "is an arithmetic operation"
         else typename = "is of type '"..(e[1].tag or "<list>").."'" end

         return gg.parse_error (lx, "This expression " .. typename ..
            "; a statement was expected, and only function and method call "..
            "expressions can be used as statements");
      end
      return e[1]
   end
end

M.local_stat_parser = gg.multisequence{
   -- local function <name> <func_val>
   { "function", mlp_misc.id, func_val, builder = 
      function(x) 
         local vars = { x[1], lineinfo = x[1].lineinfo }
         local vals = { x[2], lineinfo = x[2].lineinfo }
         return { tag="Localrec", vars, vals } 
      end },
   -- local <id_list> ( = <expr_list> )?
   default = gg.sequence{ mlp_misc.id_list, gg.onkeyword{ "=", expr_list },
      builder = function(x) return {tag="Local", x[1], x[2] or { } } end } }

--------------------------------------------------------------------------------
-- statement
--------------------------------------------------------------------------------
M.stat = gg.multisequence { 
   name = "statement",
   { "do", M.block, "end", builder = 
      function (x) return { tag="Do", unpack (x[1]) } end },
   { "for", M.for_header, "do", M.block, "end", builder = 
      function (x) x[1][#x[1]+1] = x[2]; return x[1] end },
   { "function", func_name, method_name, func_val, builder=funcdef_builder },
   { "while", expr, "do", M.block, "end", builder = "While" },
   { "repeat", M.block, "until", expr, builder = "Repeat" },
   { "local", M.local_stat_parser, builder = unpack },
   { "return", return_expr_list_parser, builder = 
     function(x) x[1].tag='Return'; return x[1] end },
   { "break", builder = function() return { tag="Break" } end },
   { "-{", mlp_meta.splice_content, "}", builder = unpack },
   { "if", elseifs_parser, gg.onkeyword{ "else", M.block }, "end", 
     builder = if_builder },
   default = assign_or_call_stat_parser }

M.stat.assignments = {
   ["="] = "Set" }

function M.stat.assignments:add(k, v) self[k] = v end

return M