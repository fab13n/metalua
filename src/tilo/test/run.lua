require 'tilo'

local mlc = require 'metalua.compiler'

function eq_tree(a,b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a==b end
    if a.tag~=b.tag then return false end
    if #a ~= #b then return false end
    for i=1,#a do if not eq_tree(a[i], b[i]) then return false end end
    return true
end

cases = require 'tilo.test.cases'

function main()
    local failures = { }
    for name, item in pairs(cases) do
        local str_e, str_expected_tebar = unpack(item)
        local e = mlc.luastring_to_ast(str_e)
        local str_tmp = 'local f #var ()->('..str_expected_tebar..')'
        local tmp = mlc.luastring_to_ast(str_tmp)
        local expected_tebar = {tag='TReturn', tmp[1][3][1][1][2] }
        local g = gamma_new()
        local status, actual_tebar = pcall(typeof.sbar, g, e)
        if eq_tree(actual_tebar, expected_tebar) then
            printf("  (Test %q succeeded)", name)
        else
            printf("Test %q failed", name)
            table.insert(failures, name, actual_tebar, expected_tebar)
        end
    end
    if next(failures) then 
        print("\n\nFailures: ")
        for _, f in ipairs(failures) do
            printf(" - %s returned %q instead of %q", unpack(f))
        end
        return failures
    else return nil end
end

main()