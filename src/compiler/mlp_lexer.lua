----------------------------------------------------------------------
-- Metalua:  $Id: mll.lua,v 1.3 2006/11/15 09:07:50 fab13n Exp $
--
-- Summary: Source file lexer. ~~Currently only works on strings.
-- Some API refactoring is needed.
--
----------------------------------------------------------------------
--
-- Copyright (c) 2006-2007, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------

print ("mlp_lexer 1")

module ("mlp", package.seeall)

print ("mlp_lexer 2")

local mlp_lexer = lexer.lexer:clone()

print ("mlp_lexer 3")

local keywords = {
    "and", "break", "do", "else", "elseif",
    "end", "false", "for", "function", "if",
    "in", "local", "nil", "not", "or", "repeat",
    "return", "then", "true", "until", "while",
    "...", "..", "==", ">=", "<=", "~=", 
    "+{", "-{" }
 
print ("mlp_lexer 4")

for w in values(keywords) do mlp_lexer:add(w) end

print ("mlp_lexer 5")

_M.lexer = mlp_lexer

print ("mlp_lexer 6")
