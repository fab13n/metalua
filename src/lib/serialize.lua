--------------------------------------------------------------------------------
-- Serialize an object into a source code string. This string, when passed as
-- an argument to loadstring()(), returns an object structurally identical
-- to the original one. The following are currently supported:
-- * strings, numbers, booleans, nil
-- * functions without upvalues
-- * tables thereof. Tables cna have shared part, but can't be recursive yet.
-- Caveat: metatables and environments aren't saved.
--------------------------------------------------------------------------------

local no_identity = table.transpose { 'number', 'boolean', 'string', 'nil' }

function serialize (x)

   local gensym_max =  0  -- index of the gensym() symbol generator
   local seen_once  = { } -- element->true set of elements seen exactly once in the table
   local multiple   = { } -- element->varname set of elements seen more than once
   local nested     = { } -- transient, set of elements currently being traversed

   local function gensym()
      gensym_max = gensym_max + 1 ;  return "_" .. gensym_max
   end

   -----------------------------------------------------------------------------
   -- First pass, list the tables and functions which appear more than once in x
   -----------------------------------------------------------------------------
   local function mark_multiple_occurences (x)
      if no_identity [type(x)] then return end
      if     seen_once [x]    then seen_once [x], multiple [x] = nil, gensym()
      elseif multiple [x]     then -- pass
      elseif seen_once [x] = true end
      
      if type (x) == 'table' then
         nested [x] = true
         for k, v in pairs (x) do
            if nested [k] then error "Can't serialize recursive tables yet" end
            mark_multiple_occurences (k)
            mark_multiple_occurences (v)
         end
         nested [x] = nil
      end
   end

   local dumped    = { } -- multiply occuring values already dumped in localdefs
   local localdefs = { } -- already dumped local definitions as source code lines

   -----------------------------------------------------------------------------
   -- Second pass, dump the object; subparts occuring multiple times are dumped
   -- in local variables which can be referenced multiple times;
   -- care is taken to dump locla vars in asensible order.
   -----------------------------------------------------------------------------
   local function dump_val(x)
      local  t = type(x)
      if     x==nil        then return 'nil'
      elseif t=="number"   then return tostring(x)
      elseif t=="string"   then return string.format("%q", x)
      elseif t=="boolean"  then return x and "true" or "false"
      elseif t=="function" then
         return string.format ("loadstring(%q,'@serialized')", string.dump (x))
      elseif t=="table" then
         local acc = { }
         for k, v in pairs(x) do
            --------------------------------------------------------------------
            -- if x occurs multiple times, dump the local var rather than the
            -- value. If it's the first time it's dumped, also dump the content
            -- in localdefs.
            --------------------------------------------------------------------            
            local function check_multiple (x)
               local var = multiple [x]
               if not var then return dump_val (x) end            -- Occuring only once              
               if dumped [var] then return var end  -- multiple occ, but already dumped
               table.insert (localdefs, "local " .. var .. " = " .. dump_val (x)) -- dump
               dumped [var] = true
               return var
            end
            table.insert (acc, "[" .. check_multiple(k) .. "] = " .. check_multiple(v))
         end
         return "{ "..table.concat(acc,"; ").." }"
      else
         error ("Can't serialize data of type "..t)
      end
   end
          
   mark_multiple_occurences (x)
   local toplevel = dump_val (x)
   return next (localdefs) and table.concat (localdefs, "\n") .. "\nreturn " .. toplevel
      or "return "..toplevel
end
