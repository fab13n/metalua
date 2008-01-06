----------------------------------------------------------------------
-- Metalua:  $Id: mlp_table.lua,v 1.5 2006/11/10 02:11:17 fab13n Exp $
--
-- Summary: metalua parser, table constructor parser. This is part 
--   of thedefinition of module [mlp].
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
-- $Log: mlp_table.lua,v $
-- Revision 1.5  2006/11/10 02:11:17  fab13n
-- compiler faithfulness to 5.1 improved
-- gg.expr extended
-- mlp.expr refactored
--
-- Revision 1.4  2006/11/09 09:39:57  fab13n
-- some cleanup
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
-- * [mlp.table_field()]
-- * [mlp.table_content()]
-- * [mlp.table()]
--
-- KNOWN BUG: doesn't handle final ";" or "," before final "}"
--
--------------------------------------------------------------------------------

--require "gg"
--require "mll"
--require "mlp_misc"

module ("mlp", package.seeall)

--------------------------------------------------------------------------------
-- eta expansion to break circular dependencies:
--------------------------------------------------------------------------------
local function _expr (lx) return expr(lx) end

--------------------------------------------------------------------------------
-- [[key] = value] table field definition
--------------------------------------------------------------------------------
local bracket_field = gg.sequence{ "[", _expr, "]", "=", _expr, builder = "Pair" }

--------------------------------------------------------------------------------
-- [id = value] or [value] table field definition;
-- [[key]=val] are delegated to [bracket_field()]
--------------------------------------------------------------------------------
function table_field (lx)
   if lx:is_keyword (lx:peek(), "[") then return bracket_field (lx) end
   local e = _expr (lx)
   if lx:is_keyword (lx:peek(), "=") then 
      if e.tag ~= 'Id' then _G.table.print(e,80) end
      assert (e.tag == "Id", "Identifier required on the left of = in table")
      lx:next(); return {tag="Pair", {tag="String", e[1]}, _expr(lx)} 
   else return e end
end

local function _table_field(lx) return table_field(lx) end

--------------------------------------------------------------------------------
-- table constructor, without enclosing braces; returns a full table object
--------------------------------------------------------------------------------
table_content = gg.list { _table_field, 
   separators = { ",", ";" }, terminators = "}", builder = "Table" }

local function _table_content(lx) return table_content(lx) end

--------------------------------------------------------------------------------
-- complete table constructor including [{...}]
--------------------------------------------------------------------------------
table = gg.sequence{ "{", _table_content, "}", builder = fget(1) }


