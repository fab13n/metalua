local mt = { }
function mt:__index(key)
   local v = auto{ }
   self[key] = v
   return v
end

auto = function(t) return setmetatable(t or { }, mt) end

