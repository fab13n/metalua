require 'metalua.package' -- load metalua sources
local typeof    = require 'tilo.type'
local gamma_new = require 'tilo.gamma'
local ord       = require 'tilo.order'
local mlc       = require 'metalua.compiler'
local u         = require 'tilo.termutils'

function tilo(x)
    checks('string|sbar')
    if type(x)=='string' then
        if x:sub(1,1)=='@' then x = mlc.srcfile_to_ast(x:sub(2,-1))
        else x = mlc.src_to_ast(x) end
    end

    local gamma = gamma_new()
    local ts = typeof.sbar(gamma, x)

    print("\nRaw constraints:\n"..gamma :tostring().."\n")

    gamma :simplify()
    local sigma = gamma.te.eq :get_sigma()
    gamma.tebar.eq :get_sigma(sigma)
    --gamma.te.eq :get_sigma(sigma)
    --gamma.tebar.eq :get_sigma(sigma)

    for name, cell in pairs(gamma.var_types) do
        cell.type = u.subst(cell.type, sigma)
    end

    print("\nAfter heuristic simplifications:\n"..gamma :tostring().."\n")

    if false then
        local acc = { }
        for k, v in pairs(sigma) do
            table.insert(acc, string.format("%s->%s", k, mlc.ast_to_src(v)))
        end
        local sigma_str = table.concat(acc, "; ")
        printf("ord.subst(%s, <<%s>>)", mlc.ast_to_src(ts), sigma_str)
    end

    ts = u.subst(ts, sigma)
    --print("Result: "..table.tostring(ts))
    print("Result: "..mlc.ast_to_src(ts))
    return ts
end

return tilo