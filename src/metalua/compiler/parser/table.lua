--------------------------------------------------------------------------------
--
-- Copyright (c) 2006-2012, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--
-- Exported API:
-- * [M.bracket_field()]
-- * [M.field()]
-- * [M.content()]
-- * [M.table()]
--
-- KNOWN BUG: doesn't handle final ";" or "," before final "}"
--
--------------------------------------------------------------------------------

local gg  = require 'metalua.grammar.generator'
local mlp = require 'metalua.compiler.parser.common'

local M = { }

--------------------------------------------------------------------------------
-- eta expansion to break circular dependencies:
--------------------------------------------------------------------------------
local function _expr (lx) return mlp.expr(lx) end

--------------------------------------------------------------------------------
-- [[key] = value] table field definition
--------------------------------------------------------------------------------
M.bracket_field = gg.sequence{ "[", _expr, "]", "=", _expr, builder = "Pair" }

--------------------------------------------------------------------------------
-- [id = value] or [value] table field definition;
-- [[key]=val] are delegated to [bracket_field()]
--------------------------------------------------------------------------------
function M.field (lx)
   if lx :is_keyword (lx :peek(), "[") then return M.bracket_field (lx) end
   local e = _expr (lx)
   if lx :is_keyword (lx :peek(), "=") then 
      lx :next(); -- skip the "="
      local key = mlp.id2string(e)
      local val = _expr(lx)
      local r = { tag="Pair", key, val } 
      r.lineinfo = { first = key.lineinfo.first, last = val.lineinfo.last }
      return r
   else return e end
end

--------------------------------------------------------------------------------
-- table constructor, without enclosing braces; returns a full table object
--------------------------------------------------------------------------------
M.content  = gg.list { 
   primary     =  function(...) return M.field(...) end, 
   separators  = { ",", ";" }, 
   terminators = "}",
   builder     = "Table" }

--------------------------------------------------------------------------------
-- complete table constructor including [{...}]
--------------------------------------------------------------------------------
M.table = gg.sequence{ "{", function(...) return M.content(...) end, "}", builder = unpack }

return M
