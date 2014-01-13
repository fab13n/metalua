--------------------------------------------------------------------------------
-- Copyright (c) 2006-2013 Fabien Fleutot and others.
--
-- All rights reserved.
--
-- This program and the accompanying materials are made available
-- under the terms of the Eclipse Public License v1.0 which
-- accompanies this distribution, and is available at
-- http://www.eclipse.org/legal/epl-v10.html
--
-- This program and the accompanying materials are also made available
-- under the terms of the MIT public license which accompanies this
-- distribution, and is available at http://www.lua.org/license.html
--
-- Contributors:
--     Fabien Fleutot - API and implementation
--
--------------------------------------------------------------------------------

local M = require "package" -- extend Lua's basic "package" module

M.metalua_extension_prefix = 'metalua.extension.'

-- Initialize package.mpath from package.path
M.mpath = M.mpath or os.getenv 'LUA_MPATH' or
    (M.path..";") :gsub("%.(lua[:;])", ".m%1") :sub(1, -2)

M.mcache = M.mcache or os.getenv 'LUA_MCACHE'

----------------------------------------------------------------------
-- resc(k) returns "%"..k if it's a special regular expression char,
-- or just k if it's normal.
----------------------------------------------------------------------
local regexp_magic = { }
for k in ("^$()%.[]*+-?") :gmatch "." do regexp_magic[k]="%"..k end

local function resc(k) return regexp_magic[k] or k end

----------------------------------------------------------------------
-- Take a Lua module name, return the open file and its name,
-- or <false> and an error message.
----------------------------------------------------------------------
function M.findfile(name, path_string)
   local config_regexp = ("([^\n])\n"):rep(5):sub(1, -2)
   local dir_sep, path_sep, path_mark, execdir, igmark =
      M.config :match (config_regexp)
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
   return false, '\n'..table.concat(errors, "\n")..'\n'
end

----------------------------------------------------------------------
-- Before compiling a metalua source module, try to find and load
-- a more recent bytecode dump. Requires lfs
----------------------------------------------------------------------
local function metalua_cache_loader(name, src_filename, src)
    local mlc          = require 'metalua.compiler'.new()
    local lfs          = require 'lfs'
    local dir_sep      = M.config:sub(1,1)
    local dst_filename = M.mcache :gsub ('%?', (name:gsub('%.', dir_sep)))
    local src_a        = lfs.attributes(src_filename)
    local src_date     = src_a and src_a.modification or 0
    local dst_a        = lfs.attributes(dst_filename)
    local dst_date     = dst_a and dst_a.modification or 0
    local delta        = dst_date - src_date
    local bytecode, file, msg
    if delta <= 0 then
       print "NEED TO RECOMPILE"
       bytecode = mlc :src_to_bytecode (src, name)
       for x in dst_filename :gmatch('()'..dir_sep) do
          lfs.mkdir(dst_filename:sub(1,x))
       end
       file, msg = io.open(dst_filename, 'wb')
       if not file then error(msg) end
       file :write (bytecode)
       file :close()
    else
       file, msg = io.open(dst_filename, 'rb')
       if not file then error(msg) end
       bytecode = file :read '*a'
       file :close()
    end
    return mlc :bytecode_to_function (bytecode)
end

----------------------------------------------------------------------
-- Load a metalua source file.
----------------------------------------------------------------------
function M.metalua_loader (name)
   local file, filename_or_msg = M.findfile (name, M.mpath)
   if not file then return filename_or_msg end
   local luastring = file:read '*a'
   file:close()
   if M.mcache and pcall(require, 'lfs') then
      return metalua_cache_loader(name, filename_or_msg, luastring)
   else return require 'metalua.compiler'.new() :src_to_function (luastring, name) end
end


----------------------------------------------------------------------
-- Placed after lua/luac loader, so precompiled files have
-- higher precedence.
----------------------------------------------------------------------
table.insert(M.loaders, M.metalua_loader)

----------------------------------------------------------------------
-- Load an extension.
----------------------------------------------------------------------
function extension (name, mlp)
    local complete_name = M.metalua_extension_prefix..name
    local extend_func = require (complete_name)
    if not mlp.extensions[complete_name] then
        local ast =extend_func(mlp)
        mlp.extensions[complete_name] =extend_func
        return ast
     end
end

return M
