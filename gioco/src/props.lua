-- Oggetti di scena (solo decorazione, dietro ai giocatori), in pixel art alla scala delle mattonelle.
-- Look li posa sui pavimenti liberi quando prepara la mappa.

local Art = require("src.art")
local floor = math.floor

local P = {}

local PAL = Art.pal({
  o = "120e12", t = "c8703a", T = "8a4a24", y = "f0c070", s = "d8cbb4", S = "a8987e",
  b = "a87a44", B = "6e4e2a", d = "5a6a7a", D = "3e4a56", p = "8a929c", P = "5e6670", r = "c83a3a",
  a = "b8bcc4", A = "8a8e98", k = "3a3e46", g = "4f9a48", G = "2f6a2e", m = "9aa0aa", M = "5c626c",
  w = "8a5a30", W = "5a3a1c", c = "7ad8ff", C = "d8ffff", l = "6a4a24",
})
P.PAL = PAL

local G = {
  vase = {
    "...oooo...", "..oyyyyo..", "...oyyo...", "..ottttoo.", ".otTttttto", "otTtttttto",
    "otTttyyyto", "otTtyttyto", "otTttyyyto", ".otTtttto.", "..otTtto..", "...oooo...",
  },
  column = {
    "..oo.oooo..", ".ossossso..", "oSsssssssoo", "oSsSsssSsso", "oSsSsssSsso", "oSsSsssSsso",
    "oSsSsssSsso", "oSsSsssSsso", "oSsSsssSsso", "ooooooooooo", "oSsssssssso", "ooooooooooooo",
  },
  crate = {
    "oooooooooooo", "obbbbbbbbbbo", "obBbbbbbbBbo", "obbBbbbbBbbo", "obbbBbbBbbbo", "obbbbBBbbbbo",
    "obbbBbbBbbbo", "obbBbbbbBbbo", "obBbbbbbbBbo", "obbbbbbbbbbo", "oooooooooooo",
  },
  drum = {
    ".oooooooo.", "oddddddddo", "oDDDDDDDDo", "oddyyyyddo", "oddyyyyddo", "oDDDDDDDDo",
    "oddddddddo", "oddddddddo", "oDDDDDDDDo", ".oooooooo.",
  },
  valve = {
    "..oooo..", "..oppo..", "oooppooo", "orrrrrro", "oooppooo", "..oppo..", "..oppo..",
    "..oPpo..", "..oPpo..", "..oPpo..", ".oooooo.", ".oPPPPo.", "oooooooo",
  },
  ac = {
    "oooooooooooooooooooo", "oaaaaaaaaaaaaaaaaaao", "oaoooooooaAAAAAAAAao", "oaokkkkkoaAoooooAAao",
    "oaokokokoaAAAAAAAAao", "oaokkkkkoaAoooooAAao", "oaokokokoaAAAAAAAAao", "oaokkkkkoaAoooooAAao",
    "oaoooooooaAAAAAAAAao", "oaaaaaaaaaaaaaaaaaao", "oooooooooooooooooooo", ".oo..............oo.",
  },
  plant = {
    "...gg.g...", "..gGggGg..", ".gGgggGgg.", "..gGgGgg..", "...gggG...", "..oooooo..",
    "..otttto..", "...otto...", "...oooo...",
  },
  vent = {
    "oooooo.", "ommmmo.", "ooooooo", ".ommo..", ".ommo..", ".oMmo..", ".oMmo..", "oooooo.",
  },
  cart = {
    "......yy..yyy.........", "oooooooooooooooooooooo", "oMmmmmmmmmmmmmmmmmmmMo", ".oMwwwwwwwwwwwwwwwwMo.",
    ".oMwWwwwwwWwwwwwwWwMo.", ".oMwwwwwwwwwwwwwwwwMo.", "..oMMMMMMMMMMMMMMMMo..", "..oookko....okkoooo...",
    "....okkko..okkko......", ".....ooo....ooo.......",
  },
  crystal = {
    "....o.......", "...oco..o...", "...occo.oco..", ".o.occo.occo.", "ococcco.occo.", "occccCcoocco.",
    "occcCcccoccCo", "ooooooooooooo",
  },
  lantern = {
    "..oooo", "..oyyo", ".oyyyyo", ".oyyyyo", "..oyyo", "..oooo", "...ol.", "...ol.", "...ol.",
    "...ol.", "...ol.", "..oooo",
  },
}
P.G = G

-- oggetti per tema: nome della griglia, e se ha una luce
P.THEME = {
  arena = { { "vase" }, { "column" }, { "vase" } },
  factory = { { "crate" }, { "drum" }, { "valve" } },
  roofs = { { "ac" }, { "plant" }, { "vent" } },
  mine = { { "cart" }, { "crystal", glow = { 0.4, 0.85, 1 } }, { "lantern", glow = { 1, 0.75, 0.35 } } },
}

-- disegna l'oggetto con la base centrata in (x, y)
function P.draw(name, x, y)
  local g = G[name]
  local w, h = Art.size(g)
  Art.draw(g, PAL, floor(x - w / 2), y - h, 1)
  return w, h
end

return P
