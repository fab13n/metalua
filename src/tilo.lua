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
    print("\n"..gamma :tostring().."\n")

    local sigma = gamma.te.eq :get_sigma()

    if false then
        local acc = { }
        for k, v in pairs(sigma) do
            table.insert(acc, string.format("%s->%s", k, a2s(v)))
        end
        local sigma_str = table.concat(acc, "; ")
        printf("cmp.subst(%s, <<%s>>)", a2s(ts), sigma_str)
    end

    ts = cmp.subst(ts, sigma)
    print("Result: "..mlc.ast_to_src(ts))
    return ts
end

return tilo