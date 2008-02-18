----------------------------------------------------------------------
-- Metalua:  $Id: mlp_meta.lua,v 1.4 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: Meta-operations: AST quasi-quoting and splicing
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
-- $Log: mlp_meta.lua,v $
-- Revision 1.4  2006/11/15 09:07:50  fab13n
-- debugged meta operators.
--
-- Revision 1.2  2006/11/09 09:39:57  fab13n
-- some cleanup
--
-- Revision 1.1  2006/11/07 21:29:02  fab13n
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
-- * [mlp.splice_content()]
-- * [mlp.quote_content()]
--
--------------------------------------------------------------------------------

--require "compile"
--require "ldump"

module ("mlp", package.seeall)

--------------------------------------------------------------------------------
-- External splicing: compile an AST into a chunk, load and evaluate
-- that chunk, and replace the chunk by its result (which must also be
-- an AST).
--------------------------------------------------------------------------------

function splice (ast)
   --printf(" [SPLICE] Ready to compile:\n%s", _G.table.tostring (ast, "nohash", 60))
   local f = mlc.function_of_ast(ast, '=splice')
   --printf " [SPLICE] Splice Compiled."
   --local status, result = pcall(f)
   --printf " [SPLICE] Splice Evaled."
   --if not status then print 'ERROR IN SPLICE' end
   local result=f()
   return result
end

--------------------------------------------------------------------------------
-- Going from an AST to an AST representing that AST
-- the only key being lifted in this version is ["tag"]
--------------------------------------------------------------------------------
function quote (t)
   --print("QUOTING:", _G.table.tostring(t, 60))
   local cases = { }
   function cases.table (t)
      local mt = { tag = "Table" }
      --_G.table.insert (mt, { tag = "Pair", quote "quote", { tag = "True" } })
      if t.tag == "Splice" then
         assert (#t==1, "Invalid splice")
         local sp = t[1]
         return sp
      elseif t.tag then
         _G.table.insert (mt, { tag = "Pair", quote "tag", quote (t.tag) })
      end
      for _, v in ipairs (t) do
         _G.table.insert (mt, quote(v))
      end
      return mt
   end
   function cases.number (t) return { tag = "Number", t, quote = true } end
   function cases.string (t) return { tag = "String", t, quote = true } end
   return cases [ type (t) ] (t)
end

--------------------------------------------------------------------------------
-- when this variable is false, code inside [-{...}] is compiled and
-- avaluated immediately. When it's true (supposedly when we're
-- parsing data inside a quasiquote), [-{foo}] is replaced by
-- [`Splice{foo}], which will be unpacked by [quote()].
--------------------------------------------------------------------------------
in_a_quote = false

--------------------------------------------------------------------------------
-- Parse the inside of a "-{ ... }"
--------------------------------------------------------------------------------
function splice_content (lx)
   local parser_name = "expr"
   if lx:is_keyword (lx:peek(2), ":") then
      local a = lx:next()
      lx:next() -- skip ":"
      assert (a.tag=="Id", "Invalid splice parser name")
      parser_name = a[1]
--       printf("this splice is a %s", parser_name)
--    else
--       printf("no splice specifier:\npeek(1)")
--       _G.table.print(lx:peek(1))
--       printf("peek(2)")
--       _G.table.print(lx:peek(2))
   end
   local ast = mlp[parser_name](lx)
   if in_a_quote then
      --printf("SPLICE_IN_QUOTE:\n%s", _G.table.tostring(ast, "nohash", 60))
      return { tag="Splice", ast }
   else
      if parser_name == "expr" then ast = { { tag="Return", ast } }
      elseif parser_name == "stat"  then ast = { ast }
      elseif parser_name ~= "block" then
         error ("splice content must be an expr, stat or block") end
      --printf("EXEC THIS SPLICE:\n%s", _G.table.tostring(ast, "nohash", 60))
      return splice (ast)
   end
end

--------------------------------------------------------------------------------
-- Parse the inside of a "+{ ... }"
--------------------------------------------------------------------------------
function quote_content (lx)
   local parser 
   if lx:is_keyword (lx:peek(1), ":") then -- +{:parser: content }
      lx:next()
      errory "NOT IMPLEMENTED"
   elseif lx:is_keyword (lx:peek(2), ":") then -- +{parser: content }
      parser = mlp[id(lx)[1]]
      lx:next()
   else -- +{ content }
      parser = mlp.expr
   end

   --assert(not in_a_quote, "Nested quotes not handled yet")
   local prev_iq = in_a_quote
   in_a_quote = true
   --print("IN_A_QUOTE")
   local content = parser (lx)
   local q_content = quote (content)
--     printf("/IN_A_QUOTE:\n* content=\n%s\n* q_content=\n%s\n",
--            _G.table.tostring(content, "nohash", 60),
--            _G.table.tostring(q_content, "nohash", 60))
   in_a_quote = prev_iq
   return q_content
end

