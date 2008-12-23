--------------------------------------------------------------------------------
-- Serialize an object into a source code string. This string, when passed as
-- an argument to loadstring()(), returns an object structurally identical
-- to the original one. The following are currently supported:
-- * strings, numbers, booleans, nil
-- * functions without upvalues
-- * tables thereof. Tables can have shared part, but can't be recursive yet.
-- Caveat: metatables and environments aren't saved.
--------------------------------------------------------------------------------

local no_identity = { number=1, boolean=1, string=1, nil=1 }

function serialize (x)

   local gensym_max =  0  -- index of the gensym() symbol generator
   local seen_once  = { } -- element->true set of elements seen exactly once in the table
   local multiple   = { } -- element->varname set of elements seen more than once
   local nested     = { } -- transient, set of elements currently being traversed

   local function gensym()
      gensym_max = gensym_max + 1 ;  return gensym_max
   end

   -----------------------------------------------------------------------------
   -- First pass, list the tables and functions which appear more than once in x
   -----------------------------------------------------------------------------
   local function mark_multiple_occurences (x)
      if no_identity [type(x)] then return end
      if     seen_once [x]     then seen_once [x], multiple [x] = nil, true
      elseif multiple  [x]     then -- pass
      else   seen_once [x] = true end
      
      if type (x) == 'table' then
         nested [x] = true
         for k, v in pairs (x) do
            if nested [k] or nexted [v] 
            then error "Can't serialize recursive tables yet" end
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
         --------------------------------------------------------------------
         -- if x occurs multiple times, dump the local var rather than the
         -- value. If it's the first time it's dumped, also dump the content
         -- in localdefs.
         --------------------------------------------------------------------            
         local function check_multiple (x)
            if not multiple[x] then return dump_val (x) end
            local var = dumped [x]
            if var then return "_[" .. var .. "]" end
            local val = dump_val(x)
            var = gensym()
            table.insert(localdefs, "_["..var.."]="..val)
            dumped [x] = var
            return "_[" .. var .. "]"
         end

         local idx_dumped = { }
         for i, v in ipairs(x) do
            table.insert (acc, check_multiple(v))
            idx_dumped[i] = true
         end
         for k, v in pairs(x) do
            if not idx_dumped[k] then
               table.insert (acc, "[" .. check_multiple(k) .. "] = " .. check_multiple(v))
            end
         end
         return "{ "..table.concat(acc,", ").." }"
      else
         error ("Can't serialize data of type "..t)
      end
   end
          
   mark_multiple_occurences (x)
   local toplevel = dump_val (x)
   if next (localdefs) then
      return "local _={ }\n" ..
         table.concat (localdefs, "\n") .. 
         "\nreturn " .. toplevel
   else
      return "return " .. toplevel
   end
end
