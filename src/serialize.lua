--------------------------------------------------------------------------------
-- Metalua
-- Summary: Table-to-source serializer
--------------------------------------------------------------------------------
--
-- Copyright (c) 2008-2009, Fabien Fleutot <metalua@gmail.com>.
--
-- This software is released under the MIT Licence, see licence.txt
-- for details.
--
--------------------------------------------------------------------------------
--
-- Serialize an object into a source code string. This string, when passed as
-- an argument to loadstring()(), returns an object structurally identical
-- to the original one. 
--
-- The following are supported:
--
-- * strings, numbers, booleans, nil
--
-- * functions without upvalues
--
-- * tables thereof. There is no restriction on keys; recursive and shared
--   sub-tables are handled correctly.
--
-- Caveat: metatables and environments aren't saved; this might or might not
--         be what you want.
--------------------------------------------------------------------------------

local no_identity = { number=1, boolean=1, string=1, ['nil']=1 }

function serialize (x)
   
   local gensym_max =  0  -- index of the gensym() symbol generator
   local seen_once  = { } -- element->true set of elements seen exactly once in the table
   local multiple   = { } -- element->varname set of elements seen more than once
   local nested     = { } -- transient, set of elements currently being traversed
   local nest_points  = { }
   local nest_patches = { }
   
   -- Generate fresh indexes to store new sub-tables:
   local function gensym()
      gensym_max = gensym_max + 1 ;  return gensym_max
   end
   
   -----------------------------------------------------------------------------
   -- `nest_points' are places where a (recursive) table appears within
   -- itself, directly or not.  for instance, all of these chunks
   -- create nest points in table `x':
   --
   -- "x = { }; x[x] = 1"
   -- "x = { }; x[1] = x"
   -- "x = { }; x[1] = { y = { x } }".
   --
   -- To handle those, two tables are created by `mark_nest_point()':
   --
   -- * `nest_points [parent]' associates all keys and values in table
   --   parent which create a nest_point with boolean `true'
   --
   -- * `nest_patches' contains a list of `{ parent, key, value }'
   --   tuples creating a nest point. They're all dumped after all the
   --   other table operations have been performed.
   --
   -- `mark_nest_point (p, k, v)' fills tables `nest_points' and
   -- `nest_patches' with informations required to remember that
   -- key/value `(k,v)' creates a nest point in parent table `p'. It
   -- also marks `p' as occuring multiple times, since several
   -- references to it will be required in order to patch the nest
   -- points.
   -----------------------------------------------------------------------------
   local function mark_nest_point (parent, k, v)
      local nk, nv = nested[k], nested[v]
      assert (not nk or seen_once[k] or multiple[k])
      assert (not nv or seen_once[v] or multiple[v])
      local mode = (nk and nv and "kv") or (nk and "k") or ("v")
      local parent_np = nest_points [parent]
      local pair = { k, v }
      if not parent_np then parent_np = { }; nest_points [parent] = parent_np end
      parent_np [k], parent_np [v] = nk, nv
      table.insert (nest_patches, { parent, k, v })
      seen_once [parent], multiple [parent]  = nil, true
   end
   
   -----------------------------------------------------------------------------
   -- 1st pass, list the tables and functions which appear more than once in `x'
   -----------------------------------------------------------------------------
   local function mark_multiple_occurences (x)
      if no_identity [type(x)] then return end
      if     seen_once [x]     then seen_once [x], multiple [x] = nil, true
      elseif multiple  [x]     then -- pass
      else   seen_once [x] = true end
      
      if type (x) == 'table' then
         nested [x] = true
         for k, v in pairs (x) do
            if nested[k] or nested[v] then mark_nest_point (x, k, v) else
               mark_multiple_occurences (k)
               mark_multiple_occurences (v)
            end
         end
         nested [x] = nil
      end
   end

   local dumped    = { } -- multiply occuring values already dumped in localdefs
   local localdefs = { } -- already dumped local definitions as source code lines


   -- mutually recursive functions:
   local dump_val, dump_or_ref_val

   ------------------------------------------------------------------------------
   -- if `x' occurs multiple times, dump the local var rather than the
   -- value. If it's the first time it's dumped, also dump the content
   -- in localdefs.
   ------------------------------------------------------------------------------            
   function dump_or_ref_val (x)
      if nested[x] then return 'false' end -- placeholder for recursive reference
      if not multiple[x] then return dump_val (x) end
      local var = dumped [x]
      if var then return "_[" .. var .. "]" end -- already referenced
      local val = dump_val(x) -- first occurence, create and register reference
      var = gensym()
      table.insert(localdefs, "_["..var.."]="..val)
      dumped [x] = var
      return "_[" .. var .. "]"
   end

   -----------------------------------------------------------------------------
   -- 2nd pass, dump the object; subparts occuring multiple times are dumped
   -- in local variables, which can then be referenced multiple times;
   -- care is taken to dump local vars in an order which repect dependencies.
   -----------------------------------------------------------------------------
   function dump_val(x)
      local  t = type(x)
      if     x==nil        then return 'nil'
      elseif t=="number"   then return tostring(x)
      elseif t=="string"   then return string.format("%q", x)
      elseif t=="boolean"  then return x and "true" or "false"
      elseif t=="function" then
         return string.format ("loadstring(%q,'@serialized')", string.dump (x))
      elseif t=="table" then

         local acc        = { }
         local idx_dumped = { }
         local np         = nest_points [x]
         for i, v in ipairs(x) do
            if np and np[v] then
               table.insert (acc, 'false') -- placeholder
            else
               table.insert (acc, dump_or_ref_val(v))
            end
            idx_dumped[i] = true
         end
         for k, v in pairs(x) do
            if np and (np[k] or np[v]) then
               --check_multiple(k); check_multiple(v) -- force dumps in localdefs
            elseif not idx_dumped[k] then
               table.insert (acc, "[" .. dump_or_ref_val(k) .. "] = " .. dump_or_ref_val(v))
            end
         end
         return "{ "..table.concat(acc,", ").." }"
      else
         error ("Can't serialize data of type "..t)
      end
   end
          
   -- Patch the recursive table entries:
   local function dump_nest_patches()
      for _, entry in ipairs(nest_patches) do
         local p, k, v = unpack (entry)
         assert (multiple[p])
         local set = dump_or_ref_val (p) .. "[" .. dump_or_ref_val (k) .. "] = " .. 
            dump_or_ref_val (v) .. " -- rec "
         table.insert (localdefs, set)
      end
   end
   
   mark_multiple_occurences (x)
   local toplevel = dump_or_ref_val (x)
   dump_nest_patches()

   if next (localdefs) then
      -- Dump local vars containing shared or recursive parts,
      -- then the main table using them.
      return "local _={ }\n" ..
         table.concat (localdefs, "\n") .. 
         "\nreturn " .. toplevel
   else
      -- No shared part, straightforward dump:
      return "return " .. toplevel
   end
end
