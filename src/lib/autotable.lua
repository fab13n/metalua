--------------------------------------------------------------------------------
-- Tables that automatically generates subtables upon access.
--------------------------------------------------------------------------------
-- Borrowed from Lua-users, the Lua wiki.
-- (c) Thomas Wrensch & Rici Lake
--------------------------------------------------------------------------------
--
-- For instance, autotable().a.b.c = 42 is legal.
-- TODO: add proper pairs() and ipairs() iterators.
--------------------------------------------------------------------------------

local meta, auto, assign

function auto(tab, key)
   return setmetatable({}, {
      __index = auto,
      __newindex = assign,
      parent = tab,
      key = key
   })
end

--------------------------------------------------------------------------------
-- The if statement below prevents the table from being created if the
-- value assigned is nil. This is, I think, technically correct but it
-- might be desirable to use assignment to nil to force a table into
-- existence.
--------------------------------------------------------------------------------
function assign(tab, key, val)
   -- if val ~= nil then
   local oldmt = getmetatable(tab)
   oldmt.parent[oldmt.key] = tab
   setmetatable(tab, meta)
   tab[key] = val
   -- end
end

meta = {__index = auto}

function autotable()
   return setmetatable({}, meta)
end


