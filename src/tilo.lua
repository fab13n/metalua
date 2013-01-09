require 'metalua.package'
require 'tilo.type'
require 'tilo.gamma'
mlc = require 'metalua.compiler'

function tilo(src)
    local ast = mlc.luastring_to_ast(src)
    --print(mlc.ast_to_luastring(ast))
    local g = gamma_new()
    local ts = typeof.sbar(g, ast)
    print( g :tostring())
    print(mlc.ast_to_luastring(ts))
    return ts
end

return tilo