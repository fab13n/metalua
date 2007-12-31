----------------------------------------------------------------------
----------------------------------------------------------------------
--
-- Base library extension
--
----------------------------------------------------------------------
----------------------------------------------------------------------

METALUA_VERSION          = "v-0.4"
METALUA_EXTLIB_PREFIX    = "ext-lib/"
METALUA_EXTSYNTAX_PREFIX = "ext-syntax/"

function pairs(x)
   assert(type(x)=='table', 'pairs() expects a table')
   local mt = getmetatable(x)
   if mt then
      local mtp = mt.__pairs
      if mtp then return mtp(x) end
   end
   return rawpairs(x)
end

function ipairs(x)
   assert(type(x)=='table', 'ipairs() expects a table')
   local mt = getmetatable(x)
   if mt then
      local mti = mt.__ipairs
      if mti then return mti(x) end
   end
   return rawipairs(x)
end

function type(x)
   local mt = getmetatable(x)
   if mt then
      local mtt = mt.__type
      if mtt then return mtt end
   end
   return rawtype(x)
end

function min (a, ...)
   for n in values{...} do if n<a then a=n end end
   return a
end

function max (a, ...)
   for n in values{...} do if n>a then a=n end end
   return a
end
      
function o (...)
   local args = {...}
   local function g (...)
      local result = {...}
      for i=#args, 1, -1 do result = {args[i](unpack(result))} end
      return unpack (result)
   end
   return g
end
         
function id (...) return ... end
function const (k) return function () return k end end

function printf(...) return print(string.format(...)) end

function ivalues (x)
   local i = 1
   local function iterator ()
      local r = x[i]; i=i+1; return r
   end
   return iterator
end


function values (x) 
   local function iterator (state)
      local it
      state.content, it = next(state.list, state.content) 
      return it
   end
   return iterator, { list = x }
end

function keys (x) 
   local function iterator (state)
      local it = next(state.list, state.content) 
      state.content = it
      return it
   end
   return iterator, { list = x }
end

-- Loads a couple syntax extension + support library in a single
-- operation. For instance, [-{ extension "exceptions" }] should both
-- * load the exception syntax in the parser at compile time
-- * put the instruction to load the support lib in the compiled file

function extension (name, noruntime)
   local extlib_name = METALUA_EXTLIB_PREFIX .. name
   local extsyn_name = METALUA_EXTSYNTAX_PREFIX .. name
   require (extsyn_name)
   if not noruntime then
      return {tag="Call", {tag="Id", "require"},
                          {tag="String", extlib_name} }
   end
end

require 'table2'
require 'string2'

