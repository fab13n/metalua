#!/usr/bin/env lua

os.execute "hevea metalua-manual.tex -o manual.tmp.html"
os.execute "cp ../html-header.html metalua-manual.html"

local input  = io.open ("manual.tmp.html")
local output = io.open ("metalua-manual.html", "a")

local in_body = false
for line in input:lines() do
   if     line:match"<BODY *>" then in_body = true
   elseif line:match"<body *>" then in_body = true
   elseif line:match"</BODY *>" then break
   elseif line:match"</body *>" then break
   elseif in_body then output:write (line,"\n") end
end

output:close()
input:close()

os.execute "cat ../html-footer.html >> metalua-manual.html"
