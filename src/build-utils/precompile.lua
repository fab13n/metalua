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

local f = io.popen ("dir /S /b " .. cfg.directory)
for src in f:lines() do
   local base = src:match "^(.+)%.mlua$"
   if base then
      local cmd = cfg.command.." "..src.." -o "..base..".luac"
      print (cmd)
      os.execute (cmd)
   end
end


