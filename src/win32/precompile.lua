local dirname = ... or arg and arg[2] or error "No directory specified"
print ("Precompiling the content of "..dirname)

local f = io.popen ("dir /S /b " .. dirname)
for src in f:lines() do
   local base = src:match "^(.+)%.mlua$"
   if base then
      local cmd = "metalua "..src.." -o "..base..".luac"
      print (cmd)
      os.execute (cmd)
   end
end


