require 'metalua.package'
require 'tilo.type'
require 'tilo.gamma'
mlc = require 'metalua.compiler'

function tilo(x)
    checks('string|sbar')
    if type(x)=='string' then x = mlc.src_to_ast(x) end
    --print(mlc.ast_to_src(ast))
    local g = gamma_new()
    local ts = typeof.sbar(g, x)
    print(g :tostring())
    print("Result: "..mlc.ast_to_src(ts))
    return ts
end

return tilo