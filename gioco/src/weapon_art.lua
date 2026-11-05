-- Armi in pixel art (scala 0.5, rivolte a destra). gx, gy = punto dell'impugnatura.
-- Lettere: o contorno, m/M metallo chiaro/scuro, s luce, w/W legno, g impugnatura, k nero,
--          y oro, r/R rosso, c/C/h colore dell'arma (base, ombra, luce)

local W = {}

W.sword = { gx = 3, gy = 3, grid = {
  "......yy",
  "......yyoooooooooooooooooooooooo",
  "ooo...yyssssssssssssssssssssssssoo",
  "owwwwwyymmmmmmmmmmmmmmmmmmmmmmmmmso",
  "ooo...yyMMMMMMMMMMMMMMMMMMMMMMMMoo",
  "......yyoooooooooooooooooooooooo",
  "......yy",
} }

W.katana = { gx = 4, gy = 2, grid = {
  "ooooooooyo",
  "ogkgkgkgyyoooooooooooooooooooooooooooooo",
  "okgkgkgkyysssssssssssssssssssssssssssssssoo",
  "ooooooooyymmmmmmmmmmmmmmmmmmmmmmmmmmmmmmmo",
  "........yoooooooooooooooooooooooooooooooo",
} }

W.hammer = { gx = 3, gy = 6, grid = {
  "..........................oooooooooooooo",
  "..........................oMmmmmmmmmmmMo",
  "..........................oMmssssmmmmmMo",
  "..........................oMmmmmmmmmmmMo",
  "..........................oMmmmmmmmmmmMo",
  "oooooooooooooooooooooooooooMmmmmmmmmmmMo",
  "owwwwwwwwwwwwwwwwwwwwwwwwwwMmmmmmmmmmmMo",
  "oWWWWWWWWWWWWWWWWWWWWWWWWWWMmmmmmmmmmmMo",
  "oooooooooooooooooooooooooooMmmmmmmmmmmMo",
  "..........................oMmmmmmmmmmmMo",
  "..........................oMMMMMMMMMMMMo",
  "..........................oooooooooooooo",
} }

W.spear = { gx = 10, gy = 3, grid = {
  "..................................................rr.ooo",
  "..................................................rroossoo",
  "oooooooooooooooooooooooooooooooooooooooooooooooooyyommssssoo",
  "owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwyyommmmmmmmmso",
  "oWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWyyoMMMMMMMoo",
  "oooooooooooooooooooooooooooooooooooooooooooooooooyyoMMMoo",
  "..................................................rrooo",
  "..................................................r",
} }

W.whip = { gx = 3, gy = 2, grid = {
  "ooooooo",
  "oWwwwWoooo",
  "oWwwwWwWwWoooo..........ooo",
  "ooooooooWwWwWWooo.....ooWWWo",
  "............ooWWWoooooWWWoo",
  "..............ooWWWWWWWoo",
  "................ooooooo",
} }

W.pistol = { gx = 4, gy = 4, grid = {
  "...oooooooooooooooo",
  "..occcccccccccccccco",
  "..ochhhhhhhhhhhhhcMo",
  "..occcccccccccccccMo",
  "..oCCCCCCCCCCCCCCCo",
  "..ogggoooMoooooooo",
  "..ogggo.oMo",
  ".ogggo..oo",
  ".ogggo",
  ".ooooo",
} }

W.shotgun = { gx = 7, gy = 4, grid = {
  "..........ooooooooooooooooooooooooooo",
  "ooooo....oMmmmmmmmmmmmmmmmmmmmmmmmmmMo",
  "owwwwooooomssssssssssssssssssssssssssMo",
  "owwwwwwwwwMMMMMMMMMMMMMMMMMMMMMMMMMMMo",
  "oWWWWWccccchoooowwwwwwwwwwoooooooooooo",
  "oWWWooccccco...oWWWWWWWWWo",
  "oooo.ooooooo...ooooooooooo",
} }

W.autoshotgun = { gx = 7, gy = 4, grid = {
  "..........ooooooooooooooooooooooooooo",
  "ooooo....ocCcccccccccccccccccccccccccCo",
  "owwwwooooochhhhhhhhhhhhhhhhhhhhhhhhhhCo",
  "owwwwwwwwwMMMMMMMMMMMMMMMMMMMMMMMMMMMo",
  "oWWWWWccccooooooooooooooooooooooooooo",
  "oWWWoocccco.oooooo",
  "oooo.oooooooccCcco",
  "...........ocCkCco",
  "...........occccco",
  "............oooooo",
} }

W.smg = { gx = 7, gy = 3, grid = {
  "....oooooooooooooooooo",
  "..ooccccccccccccccccccoooo",
  "oocchhhhhhhhhhhhhhccccMMMo",
  "occcccccccccccccccccccoooo",
  "oooooooogggoooooMMoooo",
  "......oggo....oMMo",
  ".....oggo.....oMMo",
  "....oooo......oMMo",
  "...............oo",
} }

W.sniper = { gx = 9, gy = 5, grid = {
  "...........oooooooooooo",
  "..........oMMmmmmmmmmMMo",
  "..........oMsssssssssMMo",
  "...........ooooooMoooooo",
  "ooooooo.........oMo",
  "occcccooooooooooooooooooooooooooooooooooooooooooo",
  "ochhhhhccccccccccccccccccccMMMMMMMMMMMMMMMMMMMMMMMo",
  "oCCCCCCCCCcccccCCCCCCCCCCCCoooooooooooooooooooooooo",
  "oooooooooggooooooooooooooo",
  "........oggo",
  "........oooo",
} }

W.grenade = { gx = 7, gy = 4, grid = {
  "....ooooooooooooooooooooooo",
  "..ooccccccccccccccccccccMMMo",
  ".occhhhhhhhhhhhhhhhhhhhcMkMo",
  "occccccccccccccccccccccMkkMo",
  "oCCCCCCCCCCCCCCCCCCCCCCMkMo",
  ".oCCCooggooooooooooooooMMMo",
  "..ooooggo............oooo",
  "......oggo",
  "......oooo",
} }

W.bazooka = { gx = 15, gy = 5, grid = {
  "..............oooo",
  "..............oMMo",
  "ooooooooooooooooooooooooooooooooooooooooooooo",
  "oMMoccccccccccccccccccccccccccccccccccccccccMMMo",
  "oMkochhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhcMkkMo",
  "oMkocccccccccccccccccccccccccccccccccccccccccMkkMo",
  "oMMoCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCCMMMo",
  "ooooooooooooooogggooooooooooooooooooooooooooooo",
  "...............oggo",
  "...............oooo",
} }

W.boomerang = { gx = 3, gy = 7, grid = {
  "oooo",
  "owwoo",
  "oWwwwoo",
  ".oWwwwwoo",
  "..oWwccwwoo",
  "...oWwwwwwoo",
  "....oWwwwwwwo",
  ".....oWwwwwwwo",
  "....oWwwwwwwo",
  "...oWwwwwwoo",
  "..oWwccwwoo",
  ".oWwwwwoo",
  "oWwwwoo",
  "owwoo",
  "oooo",
} }

W.hook = { gx = 6, gy = 3, grid = {
  "....oooooooooooooooo......ooo",
  "..ooccccccccccccccccoo...oMMo",
  "oocchhhhhhhhhhhhhhhhcoooooMo",
  "occcccccccccccccccccckkkkkkMMMo",
  "oCCCCCCCCCCCCCCCCCCCcoooooMo",
  ".oooogggoooooooooooooo...oMMo",
  "....oggo..................ooo",
  "....oooo",
} }

W.bubble = { gx = 6, gy = 3, grid = {
  "...ooooooooooooooo.....oooo",
  "..occcccccccccccccoo..ossssoo",
  ".occhhhhhhhhhhhhcccMoos....so",
  ".occccccccccccccccckMos....so",
  ".oCCCCCCCCCCCCCCCCCMoos....so",
  "..oooooggoooooooooooo.ossssoo",
  "......oggo.............oooo",
  "......oooo",
} }

W.gust = { gx = 6, gy = 5, grid = {
  "......................oooo",
  "....................oocccco",
  "..oooooooooooooooooocccccco",
  ".occccccccccccccccccccccccco",
  ".occhhhhhhhhhhhhhhhhccccccco",
  ".occcccccccccccccccccccccco",
  ".oCCCCCCCCCCCCCCCCCCCcccco",
  "..ooooggoooooooooooooCCCCo",
  "......oggo...........oooo",
  "......oooo",
} }

W.flamer = { gx = 17, gy = 3, grid = {
  "...ooooooooooooooooooooooo",
  "..occcccccccccccccccccccccMMMo",
  ".occhhhhhhhhhhhhhhhhhhhhhcMkkMo",
  ".occcccccccccccccccccccccMkkMo",
  ".oCCCCCCCCCCCCCCCCCCCCCCCMMMo",
  "..oorrrrrrrroooooggoooooooo",
  "..orrhrrrrrrro..oggo",
  "..orrrrrrrrrro..oooo",
  "...oooooooooo",
} }

W.mines = { gx = 6, gy = 3, grid = {
  "....oooooooooo",
  "...oMMMMMMMMMMo",
  "..oMmmmmmmmmmmMo",
  "..oMmmmrrmmmmmMo",
  "..oMmmmrrmmmmmMo",
  "..oMMMMMMMMMMMMo",
  "...oooooooooooo",
} }

W.assault = { gx = 12, gy = 4, grid = {
  "..........oooooo",
  "..........oMMMMo",
  "ooooooooooooooooooooooooooooooooo",
  "occccccccccccccccccccccccccccMMMMMMMMMo",
  "oCChhhhhhhhhhhhhhhhhhhhhhhhhcMMMMMMMMMo",
  "oCCCCCCCCCCCCCCCCCCCCCCCCCCCCooooooooo",
  "oooooooooooggooooCCoooooooooo",
  "..........oggo..oCCo",
  "..........oooo..oCCo",
  "................oooo",
} }

W.blackhole = { gx = 8, gy = 3, grid = {
  "....ooooooooooooooooooo....oooooo",
  "..oocccccccccccccccccccooooohhhhoo",
  ".occhhhhhhhhhhhhhhhhhccccohhkkkkhho",
  ".occcccccccccccccccccccccohkkkkkkho",
  ".oCCCCCCCCCCCCCCCCCCCCcccohkkkkkkho",
  "..ooooooggooooooooooooooohhkkkkhho",
  "........oggo.............oohhhhoo",
  "........oooo...............oooooo",
} }

W.ghost = { gx = 6, gy = 2, alpha = 0.8, grid = {
  "..oooooooooooooooooooooooooooooooooooo",
  ".occhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhhco",
  "occcccccccccccccccccccccccccccccccccco",
  ".oCCCCCCooooooooooooooooooooooooooooo",
  "..oCCCCo",
  "..oooooo",
} }

W.swarm = { gx = 7, gy = 4, grid = {
  "..oooooooooooooooooooooooo",
  ".occcccccccccccccccccccccoo",
  ".ochhhhhhhhhhhhhhhhhhhhhcorro",
  ".occccccccccccccccccccccoooo",
  ".occccccccccccccccccccccorro",
  ".occccccccccccccccccccccoooo",
  ".oCCCCCCCCCCCCCCCCCCCCCCorro",
  "..oooooggooooooooooooooooo",
  "......oggo",
  "......oooo",
} }

-- scudo: forma a goccia disegnata in codice (troppo alta per una griglia comoda)
W.shield = { gx = 0, gy = 0, custom = true }

return W
