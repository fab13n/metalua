----------------------------------------------------------------------
-- Springs -- Serialization with Pluto for Rings
----------------------------------------------------------------------
--
-- Copyright (c) 2008, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
----------------------------------------------------------------------
--
-- This module is an improved version of
-- Lua Rings <http://www.keplerproject.org/rings/>:
-- Lua Rings lets users create independant Lua states, and provides
-- limited communication means (sending commands as strings,
-- receiving as results strings, numbers, booleans).
-- Springs uses Pluto <http://luaforge.net/projects/pluto/> to
-- let both states communicate arbitrary data, by serializing them
-- as strings.
--
-- API
-- ---
--
-- * new states are created with 'springs.new()' as before
--
-- * method :dostring() still works as usual
--
-- * method :pcall(f, arg1, ..., argn) works as standard function
--   pcall(), except that execution occurs in the sub-state.
--   Moreover, 'f' can also be a string, rather tahn a function.
--   If it's a string, this string must eval to a function in 
--   the substate's context. This allows to pass standard functions
--   easily. For instance:
--   > r:pcall('table.concat', {'a', 'b', 'c'}, ',')
--
-- * method :call() is similar to :pcall(), except that in case of
--   error, it actually throws the error in the sender's context.
--   Therefore, it doesn't return a success status as does pcall().
--   For instance:
--   > assert('xxx' == r:call('string.rep', 'x', 3))
--
-- Springs requires Rings and Pluto to be accessibel through require()
-- in order to work
----------------------------------------------------------------------

require 'pluto'
require 'rings'

----------------------------------------------------------------------
-- Make the name match the module, grab state __index metamethod.
-- We need to use the debug() API, since there is a __metatable
-- metamethod to prevent metatable retrieval.
-- Change the __NAME__ if you want to rename the module!
----------------------------------------------------------------------
local __NAME__      = 'springs'
local rings         = rings
local ring_index    = debug.getregistry()['state metatable'].__index
getfenv()[__NAME__] = rings

----------------------------------------------------------------------
-- Permanent tables for Pluto's persist() and unpersist() functions.
-- Unused for now.
----------------------------------------------------------------------
rings.p_perms = { }
rings.u_perms = { }

----------------------------------------------------------------------
-- For springs to work, the newly created state must load springs, so
-- that it has the 'pcall_receive' function needed to answer :call()
-- and :pcall().
----------------------------------------------------------------------
local original_rings_new = rings.new
function rings.new ()
   local r = original_rings_new ()
   r:dostring (string.format ("require %q", __NAME__))
   return r
end

----------------------------------------------------------------------
-- Serialize, send the request to the child state, 
-- deserialize and return the result
----------------------------------------------------------------------
function ring_index:pcall (f, ...)

   local type_f = type(f) 
   if type_f ~= 'string' and type_f ~= 'function' then 
      error "Springs can only call functions and strings"
   end

   -------------------------------------------------------------------
   -- pack and send msg, get response msg
   -------------------------------------------------------------------
   local  data = { f, ... }
   local  msg_snd = pluto.persist (rings.p_perms, data)
   local  st, msg_rcv = 
      self:dostring (string.format ("return rings.pcall_receive %q", msg_snd))
   
   -------------------------------------------------------------------
   -- Upon success, unpack and return results.
   -- Upon failure, msg_rcv is an error message
   -------------------------------------------------------------------
   if st then return unpack(pluto.unpersist (rings.u_perms, msg_rcv))
   else return st, msg_rcv end
end

----------------------------------------------------------------------
-- Similar to pcall(), but if the result is an error, this error
-- is actually thrown *in the sender's context*.
----------------------------------------------------------------------
function ring_index:call (f, ...)
   local results = { self:pcall(f, ...) }
   if results[1] then return select(2, unpack(results))
   else error(results[2]) end
end

----------------------------------------------------------------------
-- Receive a request from the master state, deserialize it, do it,
-- serialize the result.
-- Format of the message, once unpersisted:
-- * either a function and its arguments;
-- * or a string, which must eval to a function, and its arguments
----------------------------------------------------------------------
function rings.pcall_receive (rcv_msg)
   local result
   local data = pluto.unpersist (rings.u_perms, rcv_msg)
   assert (type(data)=='table', "illegal springs message")

   -------------------------------------------------------------------
   -- If the function is a string, the string is evaluated in
   -- the context of the sub-state. This is an easy way to
   -- pass reference to global functions.
   -------------------------------------------------------------------
   if type(data[1]) == 'string' then 
      local f, msg = loadstring ('return '..data[1])
      if not f then result = { false, msg } else 
         local status
         status, f = pcall(f)
         if f then data[1] = f else result = { false, f } end
      end
   end

   -------------------------------------------------------------------
   -- result might already have been set by a failure to load or eval
   -- a string passed as first argument.
   -------------------------------------------------------------------
   if not result then result = { pcall (unpack (data)) } end

   -------------------------------------------------------------------
   -- Format of the result: a table, with as first element a boolean
   -- indicating the success status (true ==> the evaluation went
   -- successfully), then all the results of the evaluation.
   -------------------------------------------------------------------
   return pluto.persist (rings.p_perms, result)
end

