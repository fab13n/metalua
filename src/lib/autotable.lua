local mt = { }
function mt:__index(key)
   local v = auto{ }
   self[key] = v
   return v
end

auto = |t| setmetatable(t or { }, mt)
   