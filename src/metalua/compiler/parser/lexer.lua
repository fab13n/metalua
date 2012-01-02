----------------------------------------------------------------------
-- (Meta)lua-specific lexer, derived from the generic lexer.
----------------------------------------------------------------------
--
-- Copyright (c) 2006-2012, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------

local generic_lexer = require 'metalua.grammar.lexer'
local M = { }

M.lexer = generic_lexer.lexer :clone()

local keywords = {
    "and", "break", "do", "else", "elseif",
    "end", "false", "for", "function",
    "goto", -- Lua5.2
    "if",
    "in", "local", "nil", "not", "or", "repeat",
    "return", "then", "true", "until", "while",
    "...", "..", "==", ">=", "<=", "~=",
    "::", -- Lua5,2
    "+{", "-{" }
 
for w in values(keywords) do M.lexer :add (w) end

return M
