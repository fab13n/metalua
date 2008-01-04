local package = package

require 'mlc'

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
   name = name:gsub('%.', dir_sep)
   local errors = { }
   local path_pattern = string.format('[^%s]+', resc(path_sep))
   for path in path_string:gmatch(path_pattern) do
      printf('path = %s, rpath_mark=%s, name=%s', path, resc(path_mark), name)
      local filename = path:gsub (resc(path_mark), name)
      printf('filename = %s', filename)
      local file = io.open(filename, 'r')
      if file then return file, filename end
      table.insert(errors, string.format("\tno lua file %q", filename))
   end
   return false, table.concat(errors, "\n")..'\n'
end

----------------------------------------------------------------------
-- Load a metalua source file. Intended to replace the Lua loader
-- in package.loaders.
----------------------------------------------------------------------
function package.metalua_loader (name)
   local file, filename_or_msg = package.findfile (name, package.path)
   if not file then return filename_or_msg end
   print ('found file '..filename_or_msg)
   local src = file:read '*a'
   file:close()
   if src:strmatch '^\027LuaQ' or src:strmatch '^#![^\n]+\n\027LuaQ' then
      return mlc.function_of_luacstring(src, filename)
   else
      return mlc.function_of_luastring(src, filename_or_msg)
   end
end

package.loaders[2] = package.metalua_loader

return package