-{ extension 'match' }

function clopts(cfg)
   local legal_types = table.transpose{'boolean','string','number','nil'}

   -- Fill short and long name indexes, and check its validity
   local short, long, param_func = { }, { }
   for x in ivalues(cfg) do
      match x with
      | { action=a } -> 
         if not x.type then x.type='nil' end
         if not legal_types[x.type] then error ("Invalid type name "..x.type) end
         if x.short then
            if short[x.short] then error ("multiple definitions for option "..x.short) 
            else short[x.short] = x end
         end
         if x.long then
            if long[x.long] then error ("multiple definitions for option "..x.long) 
            else long[x.long] = x end
         end
      | { ... } -> error "invalid table entry in clopts: no action specified"
      | _ if type(x)=='function' -> 
         if param_func then error "multiple parameters handler in clopts"
         else param_func=x end
      | _ -> error ("invalid clopts config entry of type "..type(x))
      end
   end

   -- Print a help message, summarizing how to use the command line
   local function print_usage(msg)
      if msg then print(msg,'\n') end
      print(cfg.usage or "Options:\n")
      for x in values(cfg) do
         if type(x) == 'table' then
            local opts = { }
            if x.type=='boolean' then 
               if x.short then opts = { '-'..x.short, '+'..x.short } end
               if x.long  then table.insert (opts, '--'..x.long) end
            else
               if x.short then opts = { '-'..x.short..' <'..x.type..'>' } end
               if x.long  then table.insert (opts,  '--'..x.long..' <'..x.type..'>' ) end
            end
            printf("  %s: %s", table.concat(opts,', '), x.usage or '<undocumented>')
         end
      end
   end

   -- Unless overridden, -h and --help display the help msg
   if not short.h   then short.h   = {action=print_usage;type='nil'} end
   if not long.help then long.help = {action=print_usage;type='nil'} end

   -- Helper function for parse
   local function actionate(table, flag, opt, i, args)
      local x = table[opt]
      if not x then print_usage ("invalid option "..flag..opt); return false; end
      match x.type with
      | 'string' | 'number' -> 
         if flag=='+' then 
            print_usage ("flag "..flag.." is reserved for boolean options, not for "..opt)
            return false
         end
         local arg = args[i+1]
         if not arg then 
            print_usage ("missing parameter for option "..flag..opt)
            return false
         end
         x.action(arg)
         return i+2
      | 'boolean' -> x.action(flag~='+'); return i+1
      | 'nil'     -> x.action();          return i+1
      |  t        -> error('bad type for clopts action: '..t)
      end
   end

   -- Parse a list of commands
   local function parse(...)
      local args = type(...)=='table' and ... or {...}
      local i, i_max = 1, #args
      while i <= i_max do         
         local arg, flags, opts, opt = args[i]
         --printf('beginning of loop: i=%i/%i, arg=%q', i, i_max, arg)
         flag, opt = arg:strmatch "^(%-%-)(.+)"
         if opt then
            -- double dash option
            i=actionate (long, flag, opt, i, args)
            -{ `Goto 'continue' }
         end
         flag, opts = arg:strmatch "^([+-])(.+)"
         if opts then 
            -- single plus or single dash series of short options
            local j_max, i2 = opts:len()
            for j = 1, j_max do
               opt = opts:sub(j,j)
               --printf ('parsing short opt %q', opt)               
               i2 = actionate (short, flag, opt, i, args)
               if i2 ~= i+1 and j < j_max then 
                  error ('short option '..opt..' needs a param of type '..short[opt])
               end               
            end
            i=i2 
            -{ `Goto 'continue' }
         end
         if param_func then 
            -- handler for non-option parameter
            param_func(args[i])
            i=i+1
         else
            print_usage "No option before parameter"
            return false
         end
         -{ `Label 'continue' }
         if not i then return false end
      end -- </while>
   end
   return parse
end


