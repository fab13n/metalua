--*-lua-*-----------------------------------------------------------------------
-- Override Lua's default compilation functions, so that they support Metalua
-- rather than only plain Lua
--------------------------------------------------------------------------------

local bytecode = require 'metalua.bytecode'
local mlp = require 'metalua.mlp'

local M = { }

-- Original versions
local X = { 
    load       = load,
    loadfile   = loadfile,
    loadstring = loadstring,
    dofile     = dofile,
    dostring   = dostring }

local lua_loadstring = loadstring
local lua_loadfile = loadfile

function M.loadstring(str, name)
   if type(str) ~= 'string' then error 'string expected' end
   if str:match '^\027LuaQ' then return lua_loadstring(str) end
   local n = str:match '^#![^\n]*\n()'
   if n then str=str:sub(n, -1) end
   -- FIXME: handle erroneous returns (return nil + error msg)
   local success, f = pcall (M.luastring_to_function, str, name)
   if success then return f else return nil, f end
end

function M.loadfile(filename)
   local f, err_msg = io.open(filename, 'rb')
   if not f then return nil, err_msg end
   local success, src = pcall( f.read, f, '*a')
   pcall(f.close, f)
   if success then return loadstring (src, '@'..filename)
   else return nil, src end
end

function M.load(f, name)
   while true do
      local x = f()
      if not x then break end
      assert(type(x)=='string', "function passed to load() must return strings")
      table.insert(acc, x)
   end
   return loadstring(table.concat(x))
end

function M.dostring(src)
   local f, msg = loadstring(src)
   if not f then error(msg) end
   return f()
end

function M.dofile(name)
   local f, msg = loadfile(name)
   if not f then error(msg) end
   return f()
end

-- Export replacement functions as globals
for name, f in pairs(M) do _G[name] = f end

-- To be done *after* exportation
M.lua = X

return M