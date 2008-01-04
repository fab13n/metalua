
require 'pluto'
require 'rings'

-- Permanent tables for Pluto's persist() and unpersist() functions.
local rings_p_perms = { }
local rings_u_perms = { }

-- Serialize, send the request to the child state, deserialize the result
local function pcall_send (r, f, ...)
   local data
   if type(f)=='string' then 
      data = string.format (f, ...)
   else
      assert (type(f)=='function', "Springs can only call functions and strings")
      data = { f, ... }
   end
   local  msg_snd = pluto.persist (rings_p_perms, data)
   local  st, msg_rcv = 
      r:dostring (string.format ("return rings.pcall_receive %q", msg_snd))
   if st then return unpack(pluto.unpersist (rings_u_perms, msg_rcv))
   else return st, msg_rcv end
end

local function call_send (r, f, ...)
   local results = { r.pcall(r, f, ...) }
   if results[1] then return select(2, unpack(results))
   else error(results[2]) end
end

-- Receive a request from the master state, deserialize it, do it,
-- serialize the result.
local function pcall_receive (rcv_msg)
   local data = pluto.unpersist (rings_u_perms, rcv_msg)
   local result
   if type(data) == 'string' then 
      local f, msg = loadstring(data)
      if not f then result = { false, msg }
      else result = { pcall (f) } end
   else
      require 'std'
      print("data received:")
      table.print (data, 80)
      assert (type(data)=='table', "illegal springs message")
      result = { pcall (unpack (data)) }
   end
   return pluto.persist (rings_p_perms, result)
end

-- Monkey-patch rings
debug.getregistry()['state metatable'].__index.pcall = pcall_send
debug.getregistry()['state metatable'].__index.call = call_send
rings.pcall_receive = pcall_receive

local original_rings_new = rings.new
function rings.new ()
   local r = original_rings_new ()
   r:dostring [[require'springs']]
   return r
end

-- Make the name match the module
springs=rings
