
require 'pluto'
require 'rings'

-- Permanent tables for Pluto's persist() and unpersist() functions.
local rings_p_perms = { }
local rings_u_perms = { }

-- Serialize, send the request to the child state, deserialize the result
local function call_send (r, ...)
   local  msg_snd = pluto.persist (rings_p_perms, {...})
   local  st, msg_rcv = 
      r:dostring (string.format ("return rings.call_receive %q", msg_snd))
   if st then return unpack(pluto.unpersist (rings_u_perms, msg_rcv))
   else return st, msg_rcv end
end

-- Receive a request from the master state, deserialize it, do it,
-- serialize the result.
local function call_receive (rcv_msg)
   local args = pluto.unpersist (rings_u_perms, rcv_msg)
   local r = { pcall (unpack (args)) }
   return pluto.persist (rings_p_perms, r)
end

-- Monkey-patch rings
debug.getregistry()['state metatable'].__index.call = call_send
rings.call_receive = call_receive

local original_rings_new = rings.new
function rings.new ()
   local r = original_rings_new ()
   r:dostring [[require'springs']]
   return r
end

-- Make the name match the module
springs=rings
