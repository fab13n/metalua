require 'stream'

charstream_class = stream_class:inherit()

function charstream_class:from_string (string, filename)
   return self:new {
      src       = string; 
      srcinfo   = {
         offset = 1; 
         line   = 1;
         column = 1 }
      filename  = filename or "?" }
end

function charstream_class.methods:extract()
   -- offset, line and column are those of the next character to be extracted
   local si = self.srcinfo
   local k = self.src:sub (si.offset, si.offset)
   if not k then return end_of_stream end
   local token = { k }

   -- dump source info: single char --> first and last are the same
   srcinfo.first [token] =  
      { line=si.line, column=si.column, offset=si.offset }
   srcinfo.last [token] = src.first [token]

   -- update srcinfo 
   if k=='\n' then si.line, si.column = si.line + 1, 1
   else si.column = si.column + 1 end
   si.offset = si.offset + 1

   return token 
end

function charstream_class.methods:dup()
   local dup   = table.shallow_copy (self)
   dup.peeked  = table.shallow_copy (self.peeked)
   dup.srcinfo = table.shallow_copy (self.srcinfo)
   setmetatable (dup, getmetatable (self))
   return dup
end

-- comment fixer les lineinfo? Il faut pouvoir les retourner, mais ici
-- j'avais pas prevu de les incorporer dans l'objet.
-- je peux les mettre dans une table faible lineinfo:
--
--   srcinfo.(first|last).(line|column|char)[token]
--
-- mais a ce moment-la, il me faut vraiment un module lexer a part dont
-- herite tout le monde.
--
-- Qu'est-ce qu'il y aurait d'autre dans ce module? peut-etre le
-- mecanisme d'heritage? un lexstream_maker generique, qui supporterait
-- une method :extend()?
--
-- En fait ca regle rien: si je produit une string, je peux quand meme pas
-- l'utiliser comme clef d'une table srcinfo.
--
-- mais j'aime quand meme beaucoup l'idee du srcinfo global.
-- Il faudrait y ajouter srcinfo.comment.(before|after),
-- et peut-etre srcinfo.filename.
--
-- par contre, avoir src dans une table externe va me faire chier
-- pour le passer a travers des processes. Il va falloir un
-- get_srcinfo() recursif qui repompe le subset interessant de la table.