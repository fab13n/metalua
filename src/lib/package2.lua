local package = package

require 'mlc'

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
-- Execute a metalua module sources compilation in a separate ring.
----------------------------------------------------------------------
local function spring_load(filename)   
   if os.getenv "LUA_MFAST" == "yes" then 
      print "Warning: loading metalua source file in the same compilation ring;"
      print "metalevels 0 might interfere, condider unsetting environment variable LUA_MFAST"
      return mlc.function_of_luafile(filename) 
   end
   require 'springs'
   local r = springs.new()
   r:dostring [[require 'metalua.compiler']]
   local f = r:call('mlc.function_of_luafile', filename)
   return f
end

----------------------------------------------------------------------
-- Load a metalua source file. Intended to replace the Lua loader
-- in package.loaders.
----------------------------------------------------------------------
function package.metalua_loader (name)
   local file, filename_or_msg = package.findfile (name, package.mpath)
   if not file then return filename_or_msg end
   --print ('Metalua loader: found file '..filename_or_msg)
   file:close()
   return spring_load(filename_or_msg)
end

table.insert(package.loaders, package.metalua_loader)

----------------------------------------------------------------------
-- Loads a couple syntax extension + support library in a single
-- operation. For instance, [-{ extension "exceptions" }] should both
-- * load the exception syntax in the parser at compile time
-- * put the instruction to load the support lib in the compiled file
----------------------------------------------------------------------

function extension (name, noruntime)
   local ext_runtime_name = metalua.ext_runtime_prefix  .. name
   local ext_compiler_name = metalua.ext_compiler_prefix .. name
   require (ext_compiler_name)
   if not noruntime then
      return {tag="Call", {tag="Id", "require"},
                          {tag="String", ext_runtime_name} }
   end
end

return package