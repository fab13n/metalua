local _G = getfenv()
local _G_mt = { declared = { } }

function _G_mt.declare_globals(...)
   local g = _G_mt.declared
   for v in ivalues{...} do g[v]=true end
end

function _G_mt.__newindex(_G, var, val)
   if not _G_mt.declared[var] then error ("Setting undeclared global variable "..var) end
   rawset(_G, var, val)
end

function _G_mt.__index(_G, var)
   if not _G_mt.declared[var] then error ("Reading undeclared global variable "..var) end
   rawset(_G, var, val)
end

setmetatable(_G, _G_mt)