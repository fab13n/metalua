end_of_stream = newproxy()

stream_class = { methods = { } }
stream_class.__index = stream_class.methods

function stream_class:new (instance)
   instance = instance or { }
   instance.peeked = { }
   setmetatable (instance, self)
   return instance
end

function stream_class:inherit()
   local inherited_methods = { }
   setmetatable (inherited_methods, { __index = self.methods })
   local inherited_class = {
      __index = inherited_methods,
      methods = inherited_methods,
      super = self }
   setmetatable (inherited_class, { __index = self })
   return inherited_class
end

function stream_class.methods:extract()
   error "Method :extract() not implemented in stream class"
end

function stream_class.methods:dup()
   error "Method :dup() not implemented in stream class"
end

function stream_class.methods:peek (n)
   if not n then n=1 end
   if n > #self.peeked then
      for i = #self.peeked+1, n do self.peeked [i] = self:extract() end
   end
  return self.peeked [n]
end

function stream_class.methods:next (n)
   n = n or 1
   self:peek (n)
   for i=1,n-1 do table.remove (self.peeked, 1) end
   return table.remove (self.peeked, 1)
end
