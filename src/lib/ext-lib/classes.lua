-{ extension "match" }

--------------------------------------------------------------------------------
-- rootclass: there's a need for one object
--------------------------------------------------------------------------------
rootclass = { init = const(nil), prototype = { } }
rootinstance_mt = { __index = rootclass }
function rootclass:new()
   local this = table.shallow_copy (self.prototype)
   setmetatable (this, rootinstance_mt)
   return this
end

--------------------------------------------------------------------------------
-- creatng a new class
--------------------------------------------------------------------------------
function newclass (ancestors, fields, methods)
   local thisclass = methods
   match #ancestors with
   | 0 -> thisclass.super = rootclass
   | 1 -> thisclass.super = ancestors[1]
   | n -> error "This class model doesn't support multiple inheritance"
   end
   thisclass.prototype = fields
   local instance_mt = { __index = thisclass }
   local class_mt    = { __index = thisclass.super }
   setmetatable (thisclass, class_mt)
   function thisclass:new (...)
      local this = self.super:new()
      for k, v in pairs (self.prototype) do this[k]=v end
      setmetatable (this, instance_mt)
      this:init (...)
      return this
   end
   return thisclass
end
