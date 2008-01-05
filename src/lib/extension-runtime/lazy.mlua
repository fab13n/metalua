module("lazy", package.seeall)

local THUNK_MT = { }

function thunk (f)
   return setmetatable ({raw=f}, THUNK_MT)
end

is_thunk = |th| getmetatable(th) == THUNK_MT

function force (th)
   if not is_thunk(th) then return th 
   elseif th.raw then th.value=th.raw(); th.raw=nil; return th.value
   else return th.value end
end

function table (t)
   local mt = { __rawtable = t }
   function mt.__index(_, key) return force(t[key]) end 
   function mt.__newindex(_, key, val) t[key]=val end
   return setmetatable({}, mt)
end   