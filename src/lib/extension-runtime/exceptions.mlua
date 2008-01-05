exception = { }
exn_mt    = { } 
setmetatable (exception, exn_mt)

function exn_mt.__lt(a,b) 
   return getmetatable(a) == exn_mt and 
      getmetatable(b) == exn_mt and
      b.super and a <= b.super
end

function exn_mt.__le (a,b) 
   return a==b or a<b 
end

function exception:new(...)
   local e = { super = self, new = self.new, args = {...} }
   setmetatable(e, getmetatable(self))
   return e
end

throw = error
