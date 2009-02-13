-- Compile all files called *.mluam in a directory and its sub-directories,
-- into their bytecode counterpart.
--
-- This script is windows-only, Unices have half-decent shell script languages 
-- which let you do the same with a find and an xargs.

cfg = { }


for _, a in ipairs(arg) do
   local var, val = a :match "^(.-)=(.*)"
   if var then cfg[var] = val end
end

-- Check for missing arguments on the command line
MANDATORY_ARGS = { 'bytecode_ext', 'lua_compiler', 'metalua_compiler', 'directory' }
for _, a in ipairs(MANDATORY_ARGS) do
   if not cfg[a] then
      local suffix = "=<value> "
      local msg = string.format("\n\nUsage: %s %s\nMissing mandatory argument %s",
                                arg[0], 
                                table.concat(MANDATORY_ARGS, suffix)..suffix,
                                a)
      error (msg)
   end
end

-- List all files, recursively, from newest to oldest
local f = io.popen ("dir /S /b /o-D " .. cfg.directory)

local file_seen = { }

for src in f:lines() do
   file_seen[src] = true
   local base, ext = src:match "^(.+)%.(m?lua)$"
   if base then
      local target = base.."."..cfg.bytecode_ext
      if file_seen[target] then 
         -- the target file has been listed before the source ==> it's newer
         print ("  [OK]\t("..target.." up-to-date)")
      else
         local compiler = ext=='mlua' and cfg.metalua_compiler or cfg.lua_compiler
         local cmd = compiler.." -o "..target.." "..src
         print (cmd)
         os.execute (cmd)
      end
   end
end


