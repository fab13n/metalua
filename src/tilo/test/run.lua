require 'tilo'

local mlc = require 'metalua.compiler'
local a2s = mlc.ast_to_src
local annot = require 'metalua.compiler.parser.annot'
local cmp = require 'tilo.compare'

function eq_tree(a,b)
    if a==b then return true
    elseif type(a) ~= type(b) then return false
    elseif type(a) ~= 'table' then return a==b
    elseif a.tag~=b.tag then return false
    elseif #a ~= #b then return false end
    for i=1,#a do if not eq_tree(a[i], b[i]) then return false end end
    return true
end

cases = require 'tilo.test.cases'

function parse_annot(k, src)
    local parser = annot[k]
    local lx = mlc.src_to_lexstream (src)
    return parser(lx)
end

function main()
    local failures = { }

    for name, item in pairs(cases.typeof) do
        local str_e, str_expected_tebar = unpack(item)
        local e = mlc.src_to_ast(str_e)
        local str_tmp = 'local f #var ()->('..str_expected_tebar..')'
        local tmp = mlc.src_to_ast(str_tmp)
        local expected_tebar = {tag='TReturn', tmp[1][3][1][1][2] }
        local g = gamma_new()
        local status, actual_tebar = pcall(typeof.sbar, g, e)
        if name :match '^error_' and not status then
            printf("  (Test %q caused an error as expected)", name)
        elseif eq_tree(actual_tebar, expected_tebar) then
            printf("  (Test %q succeeded)", name)
        else
            printf("Typeof test %q failed", name)
            print(g :tostring())
            local msg = string.format("returned type %q instead of %q", 
                                      a2s(actual_tebar), a2s(expected_tebar))
            table.insert(failures, {name, msg})
        end
    end

    for _, op in ipairs{ 'min', 'max', 'eq' } do
        for k, cases in pairs(cases[op]) do 
            for name, item in pairs (cases) do
                local str_a, str_b, expected = unpack(item)
                local a = parse_annot(k, str_a)
                local b = parse_annot(k, str_b)
                if type(expected)=='string' then
                    expected = parse_annot(k, expected)
                end
                if type(expected)=='boolean' and expected == cmp[op][k](a, b) then
                    printf("  (Test %q succeeded)", name)
                elseif cmp.eq[k](cmp[op][k](a, b), expected) then
                    printf("  (Test %q succeeded)", name)
                else
                    printf("Test %q failed", name)
                    local msg = string.format(
                        "failed to prove that %s.%s(%s, %s) == %s",
                        op, k, 
                        a2s(a), a2s(b), 
                        type(expected)=='table' and a2s(expected) or tostring(expected))
                    table.insert(failures, {name, msg})
                end
            end
        end
    end

    if next(failures) then 
        print("\n\nFailures: ")
        for _, item in ipairs(failures) do
            printf(" - %s: %s", unpack(item))
        end
        return failures
    else return nil end
end

main()