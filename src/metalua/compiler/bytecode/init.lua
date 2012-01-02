local compile = require 'metalua.compiler.bytecode.compile'
local ldump   = require 'metalua.compiler.bytecode.ldump'

local M = { }

M.ast_to_proto = compile.ast_to_proto
M.dump_string  = ldump.dump_string
M.dump_file    = ldump.dump_file

return M