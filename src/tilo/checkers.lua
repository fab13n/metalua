require 'checks'

-- gamma is checked through it metatable's __type field.

function checkers.tebar(x)
    if type(x)~='table' then return false end
    for _, y in ipairs(x) do if not checkers.te(y) then return false end end
    return true
end

function checkers.e(x)
    if type(x)~='table' then return false end
    local t = { Function=1,Table=1,Call=1,Index=1,Id=1 }
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

function checkers.te(x)
    if type(x)~='table' then return false end
    local t = {TDyn=1,TId=1,TFunction=1,TTable=1}
    return t[x.tag]
end

function checkers.vbar(x)
    if type(x)~='table' then return false end
    for _, y in ipairs(x) do if y.tag~='Id' then return false end end
    return true
end

function checkers.tf(x)
    if type(x)~='table' then return false end
    local t = {TField=1,TVar=1,TConst=1,TCurrently=1}
    return t[x.tag]
end

function checkers.ell(x)
    if type(x)~='table' then return false end
    return x.tag=='Index' or x.tag=='Id'
end
