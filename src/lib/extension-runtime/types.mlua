--------------------------------------------------------------------------------
-- Initialize the types table. It has an __index metatable entry,
-- so that if a symbol is not found in it, it is looked for in the current
-- environment. It allows to write things like [ n=3; x :: vector(n) ].
--------------------------------------------------------------------------------
types = { }
setmetatable (types, { __index = getfenv(0)})

--------------------------------------------------------------------------------
-- Built-in types
--------------------------------------------------------------------------------
for typename in values{ "number", "string", "boolean", "function", "thread" } do
   types[typename] = 
      function (val)           
         if type(val) ~= typename then error (typename .. " expected") end
      end
end

--------------------------------------------------------------------------------
-- [list (subtype)] checks that the term is a table, and all of its 
-- integer-indexed elements are of type [subtype].
--------------------------------------------------------------------------------
function types.table (...)
   local key_type, val_type, range_from, range_to
   -- arguments parsing
   for x in values{...} do
      if type(x) == "number" then
         if range2    then error "Invalid type: too many numbers in table type"
         elseif range1 then range2 = x
         else   range1 = x end
      else
         if     type_key  then error "Invalid type: too many types"
         elseif type_val  then type_key, type_val = type_val, x
         else   type_val = x end
      end
   end
   if not range2 then range2=range1 end
   if not type_key then type_key = types.integer end
   return function (val)
      if type(val) ~= "table" then error "table expected" end
      local s = #val
      if range2 and range2 > s then error "Not enough elements" end
      if range1 and range1 < s then error "Too many elements elements" end
      for k,v in pairs(args) do 
         type_key(k)
         type_val(v)
      end
   end
end

types.list = |...| types.table (types.integer, ...)

--------------------------------------------------------------------------------
-- Check that [x] is an integral number
--------------------------------------------------------------------------------
function types.int (x)
   if type(x)~="number" or x%1~=0 then error "Integer number expected" end
end

--------------------------------------------------------------------------------
-- [range(a,b)] checks that number [val] is between [a] and [b]. [a] and [b]
-- can be omitted.
--------------------------------------------------------------------------------
function types.range (a,b)
   return function (val)
      if type(val)~="number" or a and val<a or b and val>b then 
         error (string.format("Number between %s and %s expected",
                              a and tostring(a) or "-infty",
                              b and tostring(b) or "+infty"))
      end
   end
end

--------------------------------------------------------------------------------
-- [inter (x, y)] checks that the term has both types [x] and [y].
--------------------------------------------------------------------------------
function types.inter (...)
   local args={...}
   return function(val)
      for t in values(args) do t(args) end
   end
end      

--------------------------------------------------------------------------------
-- [inter (x, y)] checks that the term has type either [x] or [y].
--------------------------------------------------------------------------------
function types.union (...)
   local args={...}
   return function(val)
      for t in values(args) do if pcall(t, val) then return end end
      error "None of the types in the union fits"
   end
end      

--------------------------------------------------------------------------------
-- [optional(t)] accepts values of types [t] or [nil].
--------------------------------------------------------------------------------
function types.optional(t)
   return function(val) if val~=nil then t(val) end end
end  

--------------------------------------------------------------------------------
-- A call to this is done on litteral tables passed as types, i.e.
-- type {1,2,3} is transformed into types.__table{1,2,3}.
--------------------------------------------------------------------------------
function types.__table(s_type)
   return function (s_val)
      if type(s_val) ~= "table" then error "Struct table expected" end
      for k, field_type in pairs (s_type) do
         local r, msg = pcall (field_type, s_val[k])
         if not r then 
            error(string.format("In structure field `%s': %s", k, msg)) 
         end
      end
   end
end

--------------------------------------------------------------------------------
-- Same as __table, except that it's called on literal strings.
--------------------------------------------------------------------------------
function types.__string(s_type)
   return function (s_val)
      if s_val ~= s_type then
         error(string.format("String %q expected", s_type))
      end
   end
end

--------------------------------------------------------------------------------
-- Top and Bottom:
--------------------------------------------------------------------------------
function types.any() end
function types.none() error "Empty type" end
types.__add = types.union
types.__mul = types.inter