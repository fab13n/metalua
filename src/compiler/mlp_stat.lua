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
-- History:
-- $Log: mlp_stat.lua,v $
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
-- Exports API:
-- * [mlp.stat()]
-- * [mlp.block()]
-- * [mlp.for_header()]
-- * [mlp.add_block_terminators()]
--
--------------------------------------------------------------------------------

--require "gg"
--require "mll"
--require "mlp_misc"
--require "mlp_expr"
--require "mlp_meta"

--------------------------------------------------------------------------------
-- eta-expansions to break circular dependency
--------------------------------------------------------------------------------
local expr      = function (lx) return mlp.expr     (lx) end
local func_val  = function (lx) return mlp.func_val (lx) end
local expr_list = function (lx) return mlp.expr_list(lx) end

module ("mlp", package.seeall)

--------------------------------------------------------------------------------
-- List of all keywords that indicate the end of a statement block. Users are
-- likely to extend this list when designing extensions.
--------------------------------------------------------------------------------


local block_terminators = { "else", "elseif", "end", "until", ")", "}", "]" }

-- FIXME: this must be handled from within GG!!!
function block_terminators:add(x) 
   if type (x) == "table" then for _, y in ipairs(x) do self:add (y) end
   else _G.table.insert (self, x) end
end

--------------------------------------------------------------------------------
-- list of statements, possibly followed by semicolons
--------------------------------------------------------------------------------
block = gg.list {
   name        = "statements block",
   terminators = block_terminators,
   primary     = function (lx)
      local x = stat (lx)
      if lx:is_keyword (lx:peek(), ";") then lx:next() end
      return x
   end }

--------------------------------------------------------------------------------
-- Helper function for "return <expr_list>" parsing.
-- Called when parsing return statements
--------------------------------------------------------------------------------
local return_expr_list_parser = gg.list { 
   expr, separators = ",", terminators = block_terminators }

--------------------------------------------------------------------------------
-- for header, between [for] and [do] (exclusive).
-- Return the `Forxxx{...} AST, without the body element (the last one).
--------------------------------------------------------------------------------
function for_header (lx)
   local var = mlp.id (lx)
   if lx:is_keyword (lx:peek(), "=") then 
      -- Fornum: only 1 variable
      lx:next() -- skip "="
      local e = expr_list (lx)
      assert (2 <= #e and #e <= 3, "2 or 3 values in a fornum")
      return { tag="Fornum", var, unpack (e) }
   else
      -- Forin: there might be several vars
      local a = lx:is_keyword (lx:next(), ",", "in")
      if a=="in" then var_list = { var } else
         -- several vars; first "," skipped, read other vars
         var_list = gg.list{ 
            primary = id, separators = ",", terminators = "in" } (lx)
         _G.table.insert (var_list, 1, var) -- put back the first variable
         lx:next() -- skip "in"
      end
      local e = expr_list (lx)
      return { tag="Forin", var_list, e }
   end
end

--------------------------------------------------------------------------------
-- Function def parser helper: id ( . id ) *
--------------------------------------------------------------------------------
local function fn_builder (list)
   local r = list[1]
   for i = 2, #list do r = { tag="Index", r, id2string(list[i]) } end
   return r
end
local func_name = gg.list{ id, separators = ".", builder = fn_builder }

--------------------------------------------------------------------------------
-- Function def parser helper: ( : id )?
--------------------------------------------------------------------------------
local method_name = gg.onkeyword{ name = "method invocation", ":", id, 
   transformers = { function(x) return x and id2string(x) end } }

--------------------------------------------------------------------------------
-- Function def builder
--------------------------------------------------------------------------------
local function funcdef_builder(x)
   local name, method, func = x[1], x[2], x[3]
   if method then 
      name = { tag="Index", name, method }
      _G.table.insert (func[1], 1, {tag="Id", "self"}) 
   end
   return { tag="Set", {name}, {func} } 
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
   gg.sequence { expr, "then", block },
   separators  = "elseif",
   terminators = { "else", "end" } }

--------------------------------------------------------------------------------
-- assignments and calls: statements that don't start with a keyword
--------------------------------------------------------------------------------
local function assign_or_call_stat_parser (lx)
   local e = expr_list (lx)
   local a = lx:is_keyword(lx:peek())
   local op = a and stat.assignments[a]
   if op then
      --FIXME: check that [e] is a LHS
      lx:next()
      local v = expr_list (lx)
      if type(op)=="string" then return { tag=op, e, v }
      else return op (e, v) end
   else 
      assert (#e > 0)
      if #e > 1 then 
         gg.parse_error (lx, "comma is not a valid statement separator") end
      if e[1].tag ~= "Call" and e[1].tag ~= "Invoke" then
         gg.parse_error (lx, "This expression is of type '%s'; "..
            "only function and method calls make valid statements", 
            e[1].tag or "<list>")
      end
      return e[1]
   end
end

local local_stat_parser = gg.multisequence{
   -- local function <name> <func_val>
   { "function", id, func_val, builder = 
      function(x) return { tag="Localrec", { x[1] }, { x[2] } } end },
   -- local <id_list> ( = <expr_list> )?
   default = gg.sequence{ id_list, gg.onkeyword{ "=", expr_list },
      builder = function(x) return {tag="Local", x[1], x[2] or { } } end } }

--------------------------------------------------------------------------------
-- statement
--------------------------------------------------------------------------------
stat = gg.multisequence { 
   name="statement",
   { "do", block, "end", builder = 
      function (x) return { tag="Do", unpack (x[1]) } end },
   { "for", for_header, "do", block, "end", builder = 
      function (x) x[1][#x[1]+1] = x[2]; return x[1] end },
   { "function", func_name, method_name, func_val, builder=funcdef_builder },
   { "while", expr, "do", block, "end", builder = "While" },
   { "repeat", block, "until", expr, builder = "Repeat" },
   { "local", local_stat_parser, builder = fget (1) },
   { "return", return_expr_list_parser, builder = fget (1, "Return") },
   { "break", builder = function() return { tag="Break" } end },
   { "-{", splice_content, "}", builder = fget(1) },
   { "if", elseifs_parser, gg.onkeyword{ "else", block }, "end", 
     builder = if_builder },
   default = assign_or_call_stat_parser }

stat.assignments = {
   ["="] = "Set" }

function stat.assignments:add(k, v) self[k] = v end