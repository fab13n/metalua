require 'metalua.package'
require 'tilo.type'
require 'tilo.gamma'
mlc = require 'metalua.compiler'

function tilo(x)
    checks('string|sbar')
    if type(x)=='string' then x = mlc.src_to_ast(x) end
    local gamma = gamma_new()
    local ts = typeof.sbar(gamma, x)
    gamma :close()
    print(gamma :tostring())
    print("Result: "..mlc.ast_to_src(ts))
    return ts
end

return tilo