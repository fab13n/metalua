-{ extension "ternary" }

local cat = |...| flist.concat (...)

flist            = { }
flist.cons       = |h,t| setmetatable({hd=h,tl=t}, flist)
flist.case       = |x,   oncons, onnil| x ? oncons(x.hd,x.tl), onnil()
flist.concat     = |a,b| flist.case (a, |h,t| flist.cons (h, t `cat` b), || b)
flist.p          = |x|   x==nil or getmetatable(x)==flist
flist.nth        = |x,n| flist.case(x, |_,t| 1+flist.nth(t), || 0)

function flist.of_table(t) 
   local x=nil
   for i=#t,1,-1 do x=flist.cons(t[i],x) end
   return x
end

function flist.totable(l, acc)
   if not acc then acc = { } end
   flist.case(l, |a,b| table.insert(acc,a) or flist.totable (b, acc), ||nil)
   return acc
end


function flist.__tostring (l) 
   local acc = { "<| " }
   local function aux (l)
      table.insert (acc, tostring (l.hd))
      if l.tl==nil then table.insert (acc, " |>")
      elseif flist.p (l.tl) then
         table.insert (acc, ", ")
         aux (l.tl, acc)
      else -- there's a non-list tl
         table.insert (acc, " | ")
         table.insert (acc, tostring(l.tl))
         table.insert (acc, " |>")
      end
   end
   aux (l)
   return table.concat (acc)
end

