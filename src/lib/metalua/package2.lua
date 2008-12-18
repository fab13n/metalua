local package = package

require 'metalua.mlc'

package.metalua_extension_prefix = 'metalua.extension.'

package.mpath = os.getenv 'LUA_MPATH' or
   './?.mlua;/usr/local/share/lua/5.1/?.mlua;'..
   '/usr/local/share/lua/5.1/?/init.mlua;'..
   '/usr/local/lib/lua/5.1/?.mlua;'..
   '/usr/local/lib/lua/5.1/?/init.mlua'


----------------------------------------------------------------------
-- resc(k) returns "%"..k if it's a special regular expression char,
-- or just k if it's normal.
----------------------------------------------------------------------
local regexp_magic = table.transpose{
   "^", "$", "(", ")", "%", ".", "[", "]", "*", "+", "-", "?" }
local function resc(k)
   return regexp_magic[k] and '%'..k or k
end

----------------------------------------------------------------------
-- Take a Lua module name, return the open file and its name,
-- or <false> and an error message.
----------------------------------------------------------------------
function package.findfile(name, path_string)
   local config_regexp = ("([^\n])\n"):rep(5):sub(1, -2)
   local dir_sep, path_sep, path_mark, execdir, igmark =
      package.config:strmatch (config_regexp)
   name = name:gsub ('%.', dir_sep)
   local errors = { }
   local path_pattern = string.format('[^%s]+', resc(path_sep))
   for path in path_string:gmatch (path_pattern) do
      --printf('path = %s, rpath_mark=%s, name=%s', path, resc(path_mark), name)
      local filename = path:gsub (resc (path_mark), name)
      --printf('filename = %s', filename)
      local file = io.open (filename, 'r')
      if file then return file, filename end
      table.insert(errors, string.format("\tno lua file %q", filename))
   end
   return false, table.concat(errors, "\n")..'\n'
end


----------------------------------------------------------------------
-- Execute a metalua module sources compilation in a separate process
----------------------------------------------------------------------
local function spring_load(filename)
   local pattern = 
      [[lua -l metalua.mlc -l -e "print(mlc.luacstring_of_luafile('%s', '%s'))"]]
   local cmd = string.format (pattern, f, filename, filename)
   print ("running command: ``" .. cmd .. "''")
   local fd = io.popen (cmd)
   local bytecode = fd:read '*a'
   fd:close()
   return string.undump (bytecode)
end

----------------------------------------------------------------------
-- Load a metalua source file.
----------------------------------------------------------------------
function package.metalua_loader (name)
   local file, filename_or_msg = package.findfile (name, package.mpath)
   if not file then return filename_or_msg end
   file:close()
   return spring_load(filename_or_msg)
end

----------------------------------------------------------------------
-- Placed after lua/luac loader, so precompiled files have
-- higher precedence.
----------------------------------------------------------------------
table.insert(package.loaders, package.metalua_loader)

----------------------------------------------------------------------
-- Load an extension.
----------------------------------------------------------------------
function extension (name, noruntime)
   local complete_name = package.metalua_extension_prefix..name
   local x = require (complete_name)
   if x==true then return
   elseif type(x) ~= 'table' then
      error ("extension returned %s instead of an AST", type(x))
   else
      return x
   end
end

return package
