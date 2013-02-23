require 'checks'

-- gamma is checked through it metatable's __type field.

local debug_metatable = debug.metatable
function checkers.callable(f)
    if type(f)=='function' then return true end
    local mt = debug_metatable(f)
    return mt and mt.__call
end

local tebar_tags = { TUnkbar=1, TCatbar=2, TDynbar=0 }

function checkers.tebar(x)
    if type(x)~='table' then return false end
    local n=tebar_tags[x.tag]
    if n then return n==#x end
    if x.tag then return false end
    for _, y in ipairs(x) do if not checkers.te(y) then return false end end
    return true
end

function checkers.e(x)
    if type(x)~='table' then return false end
    local t = { Function=1,Table=1,Call=1,Index=1,Id=1,Op=1 }
    if t[x.tag] then return true
    else return checkers.p(x) end
end

function checkers.s(x)
    if type(x)~='table' then return false end
    if x.tag=='Set' then return true
    --elseif x.tag=='Local' then return x[2]==nil or #x[2]==0 
    else return true end
end

function checkers.ebar(x)
    if type(x)~='table' then return false end
    for _, y in ipairs(x) do if not checkers.e(y) then return false end end
    return true
end

function checkers.sbar(x)
    if type(x)~='table' then return false end
    for _, y in ipairs(x) do if not checkers.s(y) then return false end end
    return true
end

function checkers.ts(x)
    if type(x)~='table' then return false end
    return x.tag=='TReturn' or x.tag=='TPass'
end

function checkers.p(x)
    if type(x)~='table' then return false end
    local t = {Number=1,String=1,True=1,False=1,Nil=1}
    return t[x.tag]
end

local te_tags = { TDyn=0, TId=1, TUnk=1, TFunction=2, TTable=2 }
function checkers.te(x)
    if type(x)~='table' then return false end
    if x.tag=='TTable' then
        if #x~=2 then return false end
        if x[2].tag then return false end
        for _, p in ipairs(x[2]) do
            if p.tag~='TPair' then return false end
        end
    end
    local n = te_tags[x.tag]
    if n then return #x==n end
end

function checkers.vbar(x)
    if type(x)~='table' then return false end
    for _, y in ipairs(x) do if y.tag~='Id' then return false end end
    return true
end

local tf_tags={ TField=1,TVar=1,TConst=1,TCurrently=1,TJust=1 }

function checkers.tf(x)
    if type(x)~='table' then return false end
    if x.tag=='TField' then return x[1]==nil
    else return tf_tags[x.tag] and x[1] end
end

function checkers.ell(x)
    if type(x)~='table' then return false end
    return x.tag=='Index' or x.tag=='Id'
end
