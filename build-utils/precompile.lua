-- Compile all files called *.mluam in a directory and its sub-directories,
-- into their *.luac counterpart.
--
-- This script is windows-only, Unices have half-decent shell script languages 
-- which let you do the same with a find and an xargs.

cfg = { }
for _, a in ipairs(arg) do
   local var, val = a :match "^(.-)=(.*)"
   if var then cfg[var] = val end
end

if not cfg.command or not cfg.directory then
   error ("Usage: "..arg[0].." command=<metalua command> directory=<library root>")
end

-- List all files, recursively, from newest to oldest
local f = io.popen ("dir /S /b /o-D " .. cfg.directory)

local file_seen = { }
for src in f:lines() do
   file_seen[src] = true
   local base = src:match "^(.+)%.mlua$"
   if base then
      local target = base..".luac"
      if file_seen[target] then 
	 -- the target file has been listed before the source ==> it's newer
	 print ("("..target.." up-to-date)")
      else
	 local cmd = cfg.command.." "..src.." -o "..target
	 print (cmd)
	 os.execute (cmd)
      end
   end
end


