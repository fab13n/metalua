do
   local xrequire, n, ind = require, 0, "| "
   function require (x)
      print(ind:rep(n).."/ require: "..x)
      n=n+1
      local y = xrequire(x) 
      n=n-1
      print(ind:rep(n).."\\_"); 
      return y
   end
end
