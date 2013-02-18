require 'metalua.package'
require 'tilo.type'
require 'tilo.gamma'
mlc = require 'metalua.compiler'

function tilo(x)
    checks('string|sbar')
    if type(x)=='string' then x = mlc.src_to_ast(x) end
    local gamma = gamma_new()
    local ts = typeof.sbar(gamma, x)

    print("\nRaw constraints:\n"..gamma :tostring().."\n")

    gamma :close()
    local sigma = gamma.te.eq :get_sigma()
    for name, cell in pairs(gamma.var_types) do
        cell.type = cmp.subst(cell.type, sigma)
    end

    print("\nAfter heuristic simplifications:\n"..gamma :tostring().."\n")

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