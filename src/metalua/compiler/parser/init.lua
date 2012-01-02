-- Export all public APIs from sub-modules, squashed into a flat spacename
local mod_names = {"expr", "lexer", "meta", "misc", "stat", "table" }
local M = require 'metalua.compiler.parser.common'
for _, mod_name in ipairs(mod_names) do
    -- TODO: expose sub-modules as nested tables? 
    -- Not sure: it might be confusing, will clash with API names, e.g. for expr
    local mod = require ("metalua.compiler.parser."..mod_name)
    assert (type (mod) == 'table')
    for api_name, val in pairs(mod) do
        assert(not M[api_name])
        M[api_name] = val
    end
end

-- TODO: remove or make somehow optional
require "metalua.compiler.parser.ext"

return M
