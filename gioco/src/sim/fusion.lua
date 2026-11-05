-- Fusione delle armi (provvisorio: completato nel passo 2)
local Fusion = {}
function Fusion.can_fuse(a, b) return false end
function Fusion.fuse(a, b) return a end
function Fusion.name(w) return w.id end
return Fusion
