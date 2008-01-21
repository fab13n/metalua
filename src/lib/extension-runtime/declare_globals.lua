local _G_mt = getmetatable(getfenv())

if _G_mt then
   print( "Warning: _G already has a metatable,"..
          " which might interfere with declare_globals")
   if _G_mt.globals_declared then return else
      globals_declared = { } 
   end
else 
   _G_mt = { globals_declared = { } }
end

function _G_mt.declare_globals(...)
   local g = _G_mt.globals_declared
   for v in ivalues{...} do g[v]=true end
end

function _G_mt.__newindex(_G, var, val)
   if not _G_mt.globals_declared[var] then
      error ("Setting undeclared global variable "..var)
   end
   rawset(_G, var, val)
end

function _G_mt.__index(_G, var)
   if not _G_mt.globals_declared[var] then 
      error ("Reading undeclared global variable "..var) 
   end
   rawset(_G, var, val)
end

setmetatable(_G, _G_mt)