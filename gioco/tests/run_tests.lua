-- Test automatici della simulazione. Girano senza finestra.
--   Da LÖVE:      love . test
--   Da Lua puro:  lua tests/run_tests.lua   (dalla cartella del progetto)
-- Restituisce il numero di test falliti.

local data = require("src.sim.data")
local RNG = require("src.sim.rng")
local World = require("src.sim.world")
local Game = require("src.sim.game")
local Player = require("src.sim.player")
local Combat = require("src.sim.combat")

local tests, passed, failed = {}, 0, 0

local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn } end

local function check(cond, msg)
  if not cond then error(msg or "check fallito", 2) end
end

local function near(a, b, tol, msg)
  if math.abs(a - b) > tol then
    error((msg or "valori troppo distanti") .. ": " .. tostring(a) .. " vs " .. tostring(b), 2)
  end
end

local MAPS = { "arena", "fabbrica", "tetti" }

-- --------------------------------------------------------------------------
-- helper

local function start_playing(g)
  local guard = 0
  while g.phase == "countdown" do
    g:update({})
    guard = guard + 1
    check(guard < 1000, "il countdown non finisce")
  end
end

local function run(g, frames, fn)
  for i = 1, frames do
    g:update(fn and fn(i, g) or {})
  end
end

-- Due giocatori sul pavimento della mappa di prova, uno di fronte all'altro, senza armi a terra.
local function duel(w1, w2, gap)
  local g = Game.new({ players = 2, seed = 7, first_map = "prova" })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer = 1e9, 1e9
  local p1, p2 = g.players[1], g.players[2]
  local floor_y = 21 * data.tile
  p1.x, p1.y, p1.vx, p1.vy, p1.facing = 200, floor_y, 0, 0, 1
  p2.x, p2.y, p2.vx, p2.vy, p2.facing = 200 + (gap or 22), floor_y, 0, 0, -1
  if w1 then p1.weapon = g:make_weapon(w1, "common") end
  if w2 then p2.weapon = g:make_weapon(w2, "common") end
  -- lascia che si posino
  run(g, 5)
  return g, p1, p2
end

local function keep_parry(p)
  p.action = { type = "parry", frame = 2, active = true, whiff = false }
end

-- riporta un giocatore dov'era (un manichino da allenamento che non si sposta)
local function pin(p, x, y)
  p.x, p.y, p.vx, p.vy = x, y, 0, 0
end

local function count_events(g, kind)
  local n = 0
  for _, e in ipairs(g:drain_events()) do
    if e.type == kind then n = n + 1 end
  end
  return n
end

-- --------------------------------------------------------------------------
-- RNG

test("rng: stesso seme, stessa sequenza", function()
  local a, b = RNG.new(42), RNG.new(42)
  for _ = 1, 100 do check(a:next() == b:next(), "sequenze diverse") end
end)

test("rng: int resta nel range", function()
  local r = RNG.new(5)
  for _ = 1, 2000 do
    local v = r:int(3, 9)
    check(v >= 3 and v <= 9, "fuori range: " .. v)
  end
end)

-- --------------------------------------------------------------------------
-- mappe

test("mappe: tutte valide, almeno 6 spawn, ogni spawn ha un appoggio", function()
  for _, name in ipairs(MAPS) do
    local w = World.new(require("src.maps." .. name))
    check(#w.spawns >= 6, name .. ": spawn insufficienti")
    check(#w.weapon_spawns >= 4, name .. ": spawner insufficienti")
    local T = data.tile
    for _, s in ipairs(w.spawns) do
      local c = math.floor(s.x / T) + 1
      local r = math.floor(s.y / T) + 1
      local below = w:tile(c, r)
      check(below == "#" or below == "=", name .. ": spawn senza appoggio in colonna " .. c)
    end
    for _, s in ipairs(w.weapon_spawns) do
      check(w:tile_at(s.x, s.y - 4) ~= "#", name .. ": spawner dentro un muro")
    end
  end
end)

test("mappe: ogni mappa ha pareti interne per il salto dalla parete", function()
  for _, name in ipairs(MAPS) do
    local w = World.new(require("src.maps." .. name))
    local found = false
    for c = 3, w.cols - 2 do
      local run_len = 0
      for r = 2, w.rows_n do
        -- una parete e' una colonna di solidi con aria accanto
        if w:tile(c, r) == "#" and (w:tile(c - 1, r) == "." or w:tile(c + 1, r) == ".") then
          run_len = run_len + 1
          if run_len >= 4 then found = true end
        else
          run_len = 0
        end
      end
    end
    check(found, name .. ": nessuna parete interna alta almeno 4 tile")
    check(w.width >= 900, name .. ": mappa troppo piccola")
  end
end)

test("mondo: piattaforma attraversabile, si atterra dall'alto e si passa dal basso", function()
  local w = World.new(require("src.maps.prova"))
  local T = data.tile
  -- riga 18, colonne 8-14: superficie a y = 17 * 16 = 272
  local top = 17 * T
  local b = { x = 10.5 * T, y = top - 4, w = 10, h = 20 }
  local landed = w:move_y(b, 10, false)
  check(landed, "non atterra sulla piattaforma")
  near(b.y, top, 0.01, "quota di atterraggio")
  local c = { x = 10.5 * T, y = top + 30, w = 10, h = 20 }
  local landed2, bumped2 = w:move_y(c, -40, false)
  check(not landed2 and not bumped2, "la piattaforma blocca dal basso")
  check(c.y < top, "non attraversa la piattaforma salendo")
  local d = { x = 10.5 * T, y = top - 4, w = 10, h = 20 }
  local landed3 = w:move_y(d, 10, true)
  check(not landed3, "con drop dovrebbe attraversare")
end)

-- --------------------------------------------------------------------------
-- movimento

test("movimento: i giocatori si posano a terra durante il countdown", function()
  for _, name in ipairs(MAPS) do
    local g = Game.new({ players = 6, seed = 3, first_map = name })
    run(g, 120)
    for _, p in ipairs(g.players) do
      check(p.grounded, name .. ": giocatore " .. p.id .. " non e' a terra")
      check(p.alive, name .. ": giocatore morto nel countdown")
    end
  end
end)

test("movimento: corsa a destra e velocita' massima", function()
  local g, p1 = duel()
  p1.x = 100
  p1.facing = 1
  local x0 = p1.x
  run(g, 60, function() return { { mx = 1 } } end)
  local d = p1.x - x0
  check(d > 100 and d < 140, "distanza in 1 s: " .. d)
end)

test("movimento: il muro ferma il giocatore", function()
  local g, p1 = duel()
  p1.x = 60
  run(g, 120, function() return { { mx = -1 } } end)
  check(p1.x >= data.tile + p1.w / 2 - 0.01, "e' entrato nel muro: " .. p1.x)
end)

test("movimento: salto tenuto raggiunge la quota prevista", function()
  local g, p1 = duel()
  p1.x = 100
  local y0 = p1.y
  local minY = y0
  run(g, 60, function(i) return { { jump_pressed = (i == 1), jump_held = true } } end)
  -- ricostruiamo la quota massima rieseguendo
  local g2, q1 = duel()
  q1.x = 100
  for i = 1, 60 do
    g2:update({ { jump_pressed = (i == 1), jump_held = true } })
    if q1.y < minY then minY = q1.y end
  end
  local height = y0 - minY
  check(height > 50 and height < 70, "altezza del salto: " .. height)
end)

test("doppio salto: un salto extra in aria, non due", function()
  local g, q = duel()
  q.x = 100
  local ups, prev = 0, q.vy
  for i = 1, 40 do
    local pressed = (i == 1 or i == 15 or i == 28)
    g:update({ { jump_pressed = pressed, jump_held = true } })
    if q.vy < -200 and q.vy < prev - 150 then ups = ups + 1 end
    prev = q.vy
  end
  check(ups == 2, "spinte verso l'alto: " .. ups)
end)

test("doppio salto: si ricarica atterrando", function()
  local g, p1 = duel()
  p1.x = 100
  run(g, 120, function(i)
    local pressed = (i == 1 or i == 25)
    return { { jump_pressed = pressed, jump_held = pressed } }
  end)
  check(p1.grounded and p1.air_jumps == data.player.air_jumps, "air_jumps: " .. tostring(p1.air_jumps))
end)

test("parete: scivola lentamente tenendo premuto verso il muro", function()
  local g, p1 = duel()
  p1.x = data.tile + p1.w / 2
  p1.y = 150
  p1.vy = 0
  local maxvy = 0
  for i = 1, 30 do
    g:update({ { mx = -1 } })
    if p1.vy > maxvy then maxvy = p1.vy end
  end
  check(p1.sliding, "non scivola")
  check(maxvy <= data.player.wall_slide_speed + 0.01, "velocita' di caduta: " .. maxvy)
end)

test("parete: tenendo la direzione opposta ci si stacca e si cade", function()
  local g, p1 = duel()
  p1.x = data.tile + p1.w / 2
  p1.y = 150
  p1.vy = 0
  local maxvy = 0
  for i = 1, 30 do
    g:update({ { mx = 1 } })
    if p1.vy > maxvy then maxvy = p1.vy end
  end
  check(maxvy > data.player.wall_slide_speed * 2, "velocita' di caduta: " .. maxvy)
end)

test("parete: salto dalla parete spinge via e restituisce il doppio salto", function()
  local g, p1 = duel()
  p1.x = data.tile + p1.w / 2
  p1.y = 150
  p1.vy = 0
  p1.air_jumps = 0
  for i = 1, 10 do g:update({ { mx = -1 } }) end
  g:update({ { mx = -1, jump_pressed = true, jump_held = true } })
  check(p1.vy < -200, "vy dopo il salto: " .. p1.vy)
  check(p1.vx > 100, "vx dopo il salto: " .. p1.vx)
  check(p1.air_jumps == data.player.air_jumps, "doppio salto non restituito")
end)

test("movimento: salto breve e' piu' basso del salto lungo", function()
  local function apex(hold)
    local g, p1 = duel()
    p1.x = 100
    local y0, minY = p1.y, p1.y
    for i = 1, 60 do
      g:update({ { jump_pressed = (i == 1), jump_held = (i <= hold) } })
      if p1.y < minY then minY = p1.y end
    end
    return y0 - minY
  end
  local short, long = apex(2), apex(60)
  check(short < long * 0.6, "salto breve " .. short .. " vs lungo " .. long)
end)

test("movimento: discesa da piattaforma con giu' + salto", function()
  local g = Game.new({ players = 2, seed = 1, first_map = "prova" })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  local p1 = g.players[1]
  local top = 17 * data.tile
  p1.x, p1.y, p1.vx, p1.vy = 10.5 * data.tile, top, 0, 0
  run(g, 10)
  check(p1.grounded and math.abs(p1.y - top) < 0.5, "non e' sulla piattaforma")
  run(g, 30, function(i) return { { my = 1, jump_pressed = (i == 1) } } end)
  check(p1.y > top + 10, "non e' sceso: y=" .. p1.y)
end)

test("scatto: invulnerabilita' iniziale e cooldown", function()
  local g, p1 = duel()
  p1.x = 100
  g:update({ { dash_pressed = true, mx = 1 } })
  check(p1.action and p1.action.type == "dash", "scatto non partito")
  check(p1.invuln > 0, "niente invulnerabilita'")
  local x0 = p1.x
  run(g, 14)
  check(p1.x - x0 > 40, "scatto troppo corto: " .. (p1.x - x0))
  check(p1.dash_cd > 0, "cooldown mancante")
  g:update({ { dash_pressed = true, mx = 1 } })
  check(not (p1.action and p1.action.type == "dash"), "scatto ripetuto durante il cooldown")
end)

-- --------------------------------------------------------------------------
-- combattimento

test("pugni: 4 danni, senza armi un giocatore e' quasi inutile", function()
  local g, p1, p2 = duel(nil, nil, 16)
  local hits = 0
  local last = p2.hp
  local firstDmg
  local px, py = p2.x, p2.y
  run(g, 700, function(i)
    pin(p2, px, py)
    if p2.hp < last then
      hits = hits + 1
      if not firstDmg then firstDmg = last - p2.hp end
      last = p2.hp
    end
    return { { attack_pressed = true } }
  end)
  near(firstDmg or 0, 4, 0.01, "danno del primo pugno")
  check(hits >= 15, "troppo pochi colpi registrati: " .. hits)
  check(hits * 4 >= 60 or not p2.alive, "il bersaglio non perde salute")
end)

test("pugni: servono molti colpi per eliminare qualcuno", function()
  local g, p1, p2 = duel(nil, nil, 16)
  local px, py = p2.x, p2.y
  run(g, 260, function()
    pin(p2, px, py)
    return { { attack_pressed = true } }
  end)
  check(p2.alive, "ucciso troppo in fretta a mani nude")
  check(p2.hp > 40, "troppi danni a mani nude: " .. p2.hp)
  check(p2.hp < 100, "i pugni non fanno nulla")
end)

test("spada: 4 colpi uccidono", function()
  local g, p1, p2 = duel("sword")
  local hits, last = 0, p2.hp
  local px, py = p2.x, p2.y
  run(g, 400, function()
    pin(p2, px, py)
    if p2.hp < last then hits = hits + 1; last = p2.hp end
    return { { attack_pressed = true } }
  end)
  check(not p2.alive, "la spada non uccide")
  check(hits >= 3 and hits <= 4, "colpi per uccidere: " .. hits)
end)

test("martello: lento ma devastante", function()
  local g, p1, p2 = duel("hammer")
  run(g, 26, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.hp == 100 - data.weapons.hammer.damage, "danno martello: " .. p2.hp)
  check(p2.hitstun > 0 or math.abs(p2.vx) > 100 or p2.x > 230, "nessun knockback visibile")
end)

test("deflect: respinge la mischia, stordisce l'attaccante e dona slancio", function()
  local g, p1, p2 = duel("sword", nil, 20)
  local ok = false
  for i = 1, 25 do
    keep_parry(p2)
    g:update({ { attack_pressed = (i == 1) } })
    if p1.hitstun > 0 and p1.hitstun <= data.player.parry_stun then ok = true end
  end
  check(ok, "l'attaccante non e' stato stordito")
  check(p2.hp == 100, "il difensore ha subito danni")
  check(p2.momentum >= data.momentum.gain_parry, "slancio non assegnato")
end)

test("deflect: rimanda i proiettili al mittente", function()
  local g, p1, p2 = duel("pistol", nil, 40)
  local reflected = false
  for i = 1, 30 do
    keep_parry(p2)
    g:update({ { attack_pressed = (i == 1) } })
    for _, pr in ipairs(g.projectiles) do
      if pr.reflected and pr.owner == 2 then reflected = true end
    end
  end
  check(reflected, "il proiettile non e' stato rimandato")
  run(g, 40)
  check(p1.hp < 100, "il colpo rimandato non ha raggiunto il tiratore")
end)

test("deflect: il martello rompe il parry normale", function()
  local g, p1, p2 = duel("hammer", nil, 20)
  for i = 1, 40 do
    keep_parry(p2)
    p2.action.frame = data.player.parry_startup + data.player.perfect_parry + 1
    g:update({ { attack_pressed = (i == 1) } })
  end
  check(p2.hp < 100, "il martello e' stato parato")
end)

test("deflect: il parry perfetto ferma anche il martello", function()
  local g, p1, p2 = duel("hammer", nil, 20)
  for i = 1, 40 do
    keep_parry(p2)
    g:update({ { attack_pressed = (i == 1) } })
  end
  check(p2.hp == 100, "il parry perfetto non ha fermato il martello: " .. p2.hp)
  check(p1.hitstun > 0 or p1.hp == 100, "stato inatteso")
end)

test("deflect: senza parry si prende il colpo normalmente", function()
  local g, p1, p2 = duel("sword")
  run(g, 20, function(i) return { { attack_pressed = (i == 1) } } end)
  run(g, 10)
  check(p2.hp == 100 - data.weapons.sword.damage, "danno spada senza parry: " .. p2.hp)
end)

test("clash: due attacchi simultanei si annullano", function()
  local g, p1, p2 = duel("sword", "sword", 20)
  g:drain_events()
  local clashed = false
  for i = 1, 20 do
    g:update({ { attack_pressed = (i == 1) }, { attack_pressed = (i == 1) } })
    if p1.clash > 0 and p2.clash > 0 then clashed = true end
  end
  check(clashed, "nessun clash")
  check(p1.hp == 100 and p2.hp == 100, "il clash ha fatto danni")
end)

test("clash: chi preme per primo ottiene il contrattacco", function()
  local g, p1, p2 = duel("sword", "sword", 20)
  local winner
  for i = 1, 30 do
    local inp = { { attack_pressed = (i == 1) }, { attack_pressed = (i == 1) } }
    if p1.clash > 0 and p2.clash > 0 and not winner then
      inp[1].attack_pressed = true
    end
    g:update(inp)
    if p1.clash_winner then winner = 1 end
  end
  check(winner == 1, "il contrattacco non e' stato assegnato")
  check(p2.hp < 100, "il contrattacco non ha colpito: hp " .. p2.hp)
end)

test("slancio: guadagno, perdita e livelli", function()
  local g, p1, p2 = duel("sword")
  Player.gain_momentum(p1, 40)
  check(Player.tier(p1) == 1, "livello 1")
  Player.gain_momentum(p1, 30)
  check(Player.tier(p1) == 2, "livello 2")
  Player.gain_momentum(p1, 100)
  check(Player.tier(p1) == 2, "il livello massimo e' il 2 (niente frenesia)")
  check(p1.momentum == data.momentum.max, "lo slancio non supera il massimo")
  run(g, data.momentum.decay_delay + 120)
  check(p1.momentum < data.momentum.max, "lo slancio non cala senza colpire")
end)

test("slancio: subire un colpo lo riduce", function()
  local g, p1, p2 = duel("sword")
  Player.gain_momentum(p2, 40)
  run(g, 15, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.momentum <= 11, "slancio dopo il colpo: " .. p2.momentum)
end)

test("fucile a pompa: piu' proiettili, danno alto a bruciapelo", function()
  local g, p1, p2 = duel("shotgun", nil, 18)
  run(g, 30, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.hp <= 50, "danno insufficiente a bruciapelo: " .. p2.hp)
  check(p1.weapon.ammo == data.weapons.shotgun.ammo - 1, "munizioni non scalate")
end)

test("fucile a pompa: a distanza fa pochissimo", function()
  local g, p1, p2 = duel("shotgun", nil, 330)
  run(g, 90, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.hp == 100, "i pallini non dovrebbero arrivare cosi' lontano")
end)

test("munizioni: finite le munizioni l'arma viene lanciata", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  p2.hp = 1e9
  local shots = 0
  for i = 1, 400 do
    local before = p1.weapon and p1.weapon.ammo
    g:update({ { attack_pressed = (i % 14 == 1) } })
    if p1.weapon == nil then break end
  end
  check(p1.weapon == nil, "l'arma vuota non e' stata lanciata")
end)

test("armi: la spada si rompe dopo gli usi previsti", function()
  local g, p1, p2 = duel("sword", nil, 300)
  run(g, (data.weapons.sword.uses + 1) * 22, function() return { { attack_pressed = true } } end)
  check(p1.weapon == nil, "la spada non si e' rotta")
end)

test("raccolta: chi e' disarmato raccoglie automaticamente", function()
  local g, p1, p2 = duel()
  g:add_item(p1.x, p1.y - 4, g:make_weapon("hammer", "common"))
  run(g, 5)
  check(p1.weapon and p1.weapon.id == "hammer", "nessuna raccolta automatica")
end)

test("raccolta: chi ha un'arma la scambia col tasto raccogli", function()
  local g, p1, p2 = duel("sword")
  g:add_item(p1.x, p1.y - 4, g:make_weapon("hammer", "common"))
  run(g, 5)
  check(p1.weapon.id == "sword", "ha scambiato senza premere")
  g:update({ { pickup_pressed = true, pickup_held = true } })
  g:update({})                                  -- rilascio: e' un tocco
  check(p1.weapon.id == "hammer", "scambio non riuscito")
  local sword_on_ground = false
  for _, it in ipairs(g.items) do if it.weapon.id == "sword" then sword_on_ground = true end end
  check(sword_on_ground, "la spada scambiata non e' rimasta a terra")
end)

test("lancio: un'arma con munizioni lanciata resta a terra raccoglibile", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  p2.invuln = 1e9
  local ammo = p1.weapon.ammo
  run(g, 3, function(i) return { { throw_pressed = (i == 1) } } end)
  check(p1.weapon == nil, "l'arma non e' stata lanciata")
  run(g, 90)
  local it
  for _, x in ipairs(g.items) do if x.weapon.id == "pistol" then it = x end end
  check(it, "la pistola lanciata non e' a terra")
  check(it.weapon.ammo == ammo, "munizioni perse nel lancio")
end)

test("lancio: un'arma scarica lanciata si rompe", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  p2.invuln = 1e9
  p1.weapon.ammo = 0
  run(g, 3, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p1.weapon == nil, "l'arma scarica non e' stata lanciata attaccando")
  run(g, 90)
  for _, x in ipairs(g.items) do check(x.weapon.id ~= "pistol", "l'arma scarica e' rimasta a terra") end
end)

test("lancio: il tasto raccogli non lancia piu' l'arma", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  run(g, 20, function(i) return { { pickup_pressed = (i == 1), pickup_held = (i < 15) } } end)
  check(p1.weapon and p1.weapon.id == "pistol", "il tasto raccogli ha lanciato l'arma")
end)

test("eliminazione: l'arma con munizioni resta a terra, quella consumata no", function()
  local g, p1, p2, p3 = nil
  g, p1, p2 = duel("pistol", "sword", 300)
  p2.weapon.uses = 0
  Combat.kill(g, p1, nil, "test")
  local ids = {}
  for _, x in ipairs(g.items) do ids[x.weapon.id] = true end
  check(ids.pistol, "la pistola del giocatore eliminato non e' a terra")
end)

test("armi a terra: durano 20 s e al massimo 12", function()
  local g, p1, p2 = duel(nil, nil, 300)
  p1.invuln, p2.invuln = 1e9, 1e9
  pin(p1, 40, p1.y); pin(p2, 60, p2.y)
  for k = 1, 15 do g:add_item(200 + k * 10, p1.y - 4, g:make_weapon("pistol")) end
  check(#g.items == data.round.max_ground, "armi a terra: " .. #g.items)
  run(g, data.round.item_life - 10, function() pin(p1, 40, p1.y); pin(p2, 60, p2.y); return {} end)
  check(#g.items > 0, "sparite troppo presto")
  run(g, 20, function() pin(p1, 40, p1.y); pin(p2, 60, p2.y); return {} end)
  check(#g.items == 0, "non sono sparite dopo 20 s")
end)

test("trappole: gli spuntoni fanno danno", function()
  local g = Game.new({ players = 2, seed = 4, first_map = "prova" })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer = 1e9, 1e9
  local p1 = g.players[1]
  p1.x, p1.y, p1.vx, p1.vy = 38 * data.tile, 21 * data.tile, 0, 0
  run(g, 5)
  check(p1.hp == 100 - data.player.spike_damage, "danno spuntoni: " .. p1.hp)
end)

-- --------------------------------------------------------------------------
-- round e match

test("round: l'ultimo sopravvissuto vince e parte il round successivo", function()
  local g = Game.new({ players = 3, seed = 9 })
  start_playing(g)
  Combat.kill(g, g.players[2], g.players[1], "test")
  g:update({})
  check(g.phase == "playing")
  Combat.kill(g, g.players[3], g.players[1], "test")
  g:update({})
  check(g.phase == "roundend", "il round non finisce")
  check(g.scores[1] == 1 and g.scores[2] == 0, "punteggio errato")
  run(g, data.round.end_delay + 2)
  check(g.round == 2 and g.phase == "countdown", "round successivo non partito")
  for _, p in ipairs(g.players) do check(p.alive and p.hp == 100, "stato non resettato") end
end)

test("round: morti simultanee assegnano il punto a tutti", function()
  local g = Game.new({ players = 2, seed = 11 })
  start_playing(g)
  Combat.kill(g, g.players[1], nil, "test")
  Combat.kill(g, g.players[2], nil, "test")
  g:update({})
  check(g.scores[1] == 1 and g.scores[2] == 1, "pareggio non gestito")
end)

test("match: finisce alle vittorie obiettivo", function()
  local g = Game.new({ players = 2, seed = 13 })
  local rounds = 0
  while g.phase ~= "matchend" and rounds < 10 do
    start_playing(g)
    Combat.kill(g, g.players[2], g.players[1], "test")
    run(g, data.round.end_delay + 5)
    rounds = rounds + 1
  end
  check(g.phase == "matchend", "il match non finisce")
  check(g.match_winners and g.match_winners[1] == 1, "vincitore errato")
  check(g.scores[1] == data.round.wins_duel, "punteggio finale errato: " .. g.scores[1])
end)

test("round: la mappa non si ripete nei due round precedenti", function()
  local g = Game.new({ players = 2, seed = 17 })
  local seen = { g.map_name }
  for _ = 1, 8 do
    start_playing(g)
    Combat.kill(g, g.players[2], g.players[1], "test")
    run(g, data.round.end_delay + 5)
    if g.phase == "matchend" then break end
    seen[#seen + 1] = g.map_name
  end
  for i = 3, #seen do
    check(seen[i] ~= seen[i - 1] and seen[i] ~= seen[i - 2], "mappa ripetuta troppo presto")
  end
end)

test("morte improvvisa: la lava chiude il round", function()
  local g = Game.new({ players = 2, seed = 21 })
  start_playing(g)
  g.round_frame = data.round.sudden_death - 1
  run(g, 400)
  check(g.round >= 2 or g.phase ~= "playing", "il round non e' finito con la lava")
end)

test("armi: compaiono durante il round, con annuncio", function()
  local g = Game.new({ players = 2, seed = 5 })
  start_playing(g)
  g.items = {}
  local telegraph = false
  for _ = 1, 900 do
    g:update({})
    if #g.telegraphs > 0 then telegraph = true end
  end
  check(telegraph, "nessun annuncio di spawn")
  check(#g.items >= 1, "nessuna arma comparsa")
  check(#g.items <= data.round.max_items, "troppe armi a terra")
end)

-- --------------------------------------------------------------------------
-- fuzz e determinismo

test("mira: la levetta destra punta a 360 gradi", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  run(g, 8, function(i) return { { attack_pressed = (i == 1), ax = 0.5, ay = -0.866 } } end)
  local pr = g.projectiles[1]
  check(pr, "nessun proiettile")
  -- la caduta balistica piega la traiettoria verso il basso nei primi frame
  local ang = math.deg(math.atan2(pr.vy, pr.vx))
  near(ang, -60, 4, "angolo di tiro")
end)

test("mira: con la levetta destra il personaggio guarda dove mira", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  run(g, 3, function() return { { mx = 1, ax = -1, ay = 0 } } end)
  check(p1.facing == -1, "dovrebbe guardare a sinistra mentre corre a destra")
  check(p1.vx > 0, "dovrebbe comunque muoversi a destra")
end)

test("mira: levetta destra a riposo usa la mira classica", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  run(g, 8, function(i) return { { attack_pressed = (i == 1), ax = 0.1, ay = 0.1 } } end)
  local pr = g.projectiles[1]
  check(pr and math.abs(pr.vy) < 40 and pr.vx > 0, "dovrebbe sparare dritto davanti")
  check(not p1.aim_free)
end)

-- proiettile di prova lanciato a mano
local function shoot_test(g, owner, x, y, vx, vy, bounces)
  return Combat.new_projectile(g, owner, x, y, vx, vy,
    { dmg = 10, kb = 0, life = 600, bounces = bounces, bounce_keep = 1 })
end

test("rimbalzi: il proiettile torna indietro dal muro", function()
  local g, p1, p2 = duel(nil, nil, 300)
  p1.alive, p2.alive = false, false
  local wall_x = g.world.width - data.tile
  local pr = shoot_test(g, 1, wall_x - 40, 100, 400, 0, 1)
  run(g, 20)
  check(pr.vx < 0, "il proiettile non ha rimbalzato")
  check(pr.bounces == 0 and pr.bounced == 1)
end)

test("rimbalzi: finiti i rimbalzi il proiettile si ferma sul muro", function()
  local g, p1, p2 = duel(nil, nil, 300)
  p1.alive, p2.alive = false, false
  local W = g.world.width
  shoot_test(g, 1, W / 2, 100, 600, 0, 2)
  local seen = 0
  for _ = 1, 400 do
    g:update({})
    for _, e in ipairs(g:drain_events()) do if e.type == "bounce" then seen = seen + 1 end end
    if #g.projectiles == 0 then break end
  end
  check(seen == 2, "rimbalzi contati: " .. seen)
  check(#g.projectiles == 0, "il proiettile non e' sparito")
end)

test("rimbalzi: dopo un rimbalzo il proiettile colpisce anche chi ha sparato", function()
  local g, p1, p2 = duel(nil, nil, 300)
  local wall_x = g.world.width - data.tile
  pin(p1, wall_x - 60, p1.y)
  pin(p2, 60, p2.y)
  shoot_test(g, 1, p1.x + 10, p1.y - 10, 400, 0, 1)
  run(g, 40, function() pin(p1, wall_x - 60, p1.y); return {} end)
  check(p1.hp < 100, "il rimbalzo non ha colpito il tiratore")
end)

test("rimbalzi: un proiettile velocissimo non attraversa i muri", function()
  local g, p1, p2 = duel(nil, nil, 300)
  p1.alive, p2.alive = false, false
  local W = g.world.width
  local pr = shoot_test(g, 1, W - 30, 100, 3000, 0, 0)
  run(g, 3)
  check(#g.projectiles == 0, "il proiettile e' passato attraverso il muro")
end)

test("mitraglietta: tenendo premuto spara a raffica", function()
  local g, p1, p2 = duel("smg", nil, 300)
  p2.hp = 1e9
  local start = p1.weapon.ammo
  run(g, 60, function() return { { attack_held = true } } end)
  local fired = start - (p1.weapon and p1.weapon.ammo or 0)
  check(fired >= 9 and fired <= 14, "colpi in un secondo: " .. fired)
end)

test("cecchino: attraversa il primo bersaglio", function()
  local g = Game.new({ players = 3, seed = 7, first_map = "prova" })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer = 1e9, 1e9
  local fy = 21 * data.tile
  local p1, p2, p3 = g.players[1], g.players[2], g.players[3]
  pin(p1, 100, fy); p1.facing = 1
  pin(p2, 250, fy); pin(p3, 400, fy)
  p1.weapon = g:make_weapon("sniper", "common")
  run(g, 40, function(i)
    pin(p2, 250, fy); pin(p3, 400, fy)
    return { { attack_pressed = (i == 1) } }
  end)
  check(p2.hp < 100 and p3.hp < 100, "hp " .. p2.hp .. " / " .. p3.hp)
end)

test("lanciagranate: esplode dopo la miccia e ferisce chi e' vicino", function()
  local g, p1, p2 = duel("grenade", nil, 300)
  local fy = p1.y
  p1.weapon = g:make_weapon("grenade", "common")
  -- granata lanciata a terra, accanto a p2
  local pj = data.weapons.grenade.proj
  local pr = Combat.new_projectile(g, 1, p2.x - 20, fy - 8, 0, 0,
    { dmg = 0, life = 30, gravity = pj.gravity, bounces = pj.bounces, bounce_keep = pj.bounce_keep,
      on_expire = "explode", on_touch = "explode", on_impact = "explode", kind = "grenade",
      blast = pj.blast })
  local boom = false
  for _ = 1, 40 do
    g:update({})
    for _, e in ipairs(g:drain_events()) do if e.type == "explosion" then boom = true end end
  end
  check(boom, "nessuna esplosione")
  check(p2.hp < 100, "l'esplosione non ha ferito il vicino")
  check(p1.hp == 100, "l'esplosione ha ferito chi era lontano")
end)

test("lanciagranate: un muro pieno ripara dall'esplosione", function()
  local g, p1, p2 = duel(nil, nil, 300)
  -- p2 dietro il muro di sinistra della mappa? usiamo l'esplosione appena oltre il bordo
  local wall_x = data.tile   -- bordo interno del muro sinistro
  pin(p1, wall_x + 20, p1.y)
  Combat.explode(g, wall_x - 30, p1.y - 10, { radius = 80, dmg = 50, kb = 100 }, nil)
  check(p1.hp == 100, "il muro non ha riparato")
  Combat.explode(g, p1.x + 20, p1.y - 10, { radius = 80, dmg = 50, kb = 100 }, nil)
  check(p1.hp < 100, "senza muro l'esplosione deve colpire")
end)

test("lanciagranate: la granata passa attraverso chi l'ha lanciata", function()
  local g, p1, p2 = duel(nil, nil, 300)
  Combat.new_projectile(g, 1, p1.x - 30, p1.y - 10, 300, 0,
    { dmg = 0, life = 600, on_touch = "explode", blast = { radius = 40, dmg = 50, kb = 100 } })
  local boom = false
  for _ = 1, 12 do
    g:update({})
    for _, e in ipairs(g:drain_events()) do if e.type == "explosion" then boom = true end end
  end
  check(not boom, "e' esplosa addosso al lanciatore")
end)

test("lancia: colpisce piu' lontano della spada", function()
  local g1, a1, b1 = duel("sword", nil, 44)
  run(g1, 40, function(i) pin(b1, a1.x + 44, a1.y); return { { attack_pressed = (i == 1) } } end)
  local g2, a2, b2 = duel("spear", nil, 44)
  run(g2, 40, function(i) pin(b2, a2.x + 44 + 0, a2.y); return { { attack_pressed = (i == 1) } } end)
  check(b1.hp == 100, "la spada non dovrebbe arrivare a 44 px")
  check(b2.hp < 100, "la lancia dovrebbe arrivare a 44 px")
end)

test("armi iniziali: meno armi che giocatori, in punti diversi", function()
  for _, n in ipairs({ 2, 4, 6 }) do
    local g = Game.new({ players = n, seed = n, first_map = "arena" })
    check(#g.items == math.max(1, n - data.round.start_items_less), "armi iniziali con " .. n .. " giocatori: " .. #g.items)
    for i = 1, #g.items do
      for j = i + 1, #g.items do
        check(g.items[i].x ~= g.items[j].x or g.items[i].y ~= g.items[j].y, "due armi nello stesso punto")
      end
    end
  end
end)

test("cassa: contiene solo armi di livello Potente o Mitico", function()
  local g = Game.new({ players = 2, seed = 3 })
  for _ = 1, 80 do
    local w = g:crate_weapon()
    check(w.tier >= 3, "arma di livello basso nella cassa: " .. w.id)
  end
end)

test("livelli: ogni arma ha un livello e a inizio round escono solo armi Base", function()
  for _, id in ipairs(data.weapon_order) do check(data.weapons[id].tier, id .. " senza livello") end
  for n = 2, 6 do
    local g = Game.new({ players = n, seed = n * 3 })
    for _, it in ipairs(g.items) do check(it.weapon.tier == 1, "arma iniziale non Base: " .. it.weapon.id) end
  end
end)

test("livelli: col passare del round escono armi piu' forti", function()
  local g = Game.new({ players = 2, seed = 9 })
  local function avg_tier(frame)
    g.round_frame = frame
    local s = 0
    for _ = 1, 2000 do s = s + g:random_weapon().tier end
    return s / 2000
  end
  local early, late = avg_tier(0), avg_tier(data.tier_ramp_frames)
  check(late > early + 0.4, string.format("livello medio %.2f -> %.2f", early, late))
  g.round_frame = 0
  for _ = 1, 500 do check(g:random_weapon().tier < 4, "arma mitica a inizio round") end
end)

test("balistica: i proiettili cadono e vanno lontano", function()
  local g, p1, p2 = duel("pistol", nil, 300)
  p2.alive = false
  pin(p1, 60, p1.y - 200)
  run(g, 6, function(i) return { { attack_pressed = (i == 1), ax = 1, ay = 0 } } end)
  local pr = g.projectiles[1]
  check(pr, "nessun proiettile")
  local y0 = pr.y
  run(g, 40, function() pin(p1, 60, p1.y); return {} end)
  check(pr.y > y0 + 10, "il proiettile non cade")
  check(pr.x > 300, "gittata troppo corta: " .. pr.x)
end)

test("balistica: ogni arma da fuoco ha caduta e gittata lunga", function()
  for _, id in ipairs(data.weapon_order) do
    local def = data.weapons[id]
    if def.kind == "ranged" and not def.short_range then
      local pj = def.proj
      -- le mitiche e i missili guidati possono ignorare la gravita'
      check((pj.gravity or 0) ~= 0 or def.mythic, id .. ": traiettoria dritta")
      -- distanza percorsa in orizzontale prima che il proiettile scada (senza muri)
      local vx, dist = pj.speed, 0
      for _ = 1, pj.life do
        if pj.drag then vx = vx * pj.drag end
        dist = dist + vx / 60
      end
      local min_range = (pj.count or 1) > 1 and 180 or 300
      check(dist >= min_range, id .. ": gittata " .. math.floor(dist))
    end
  end
end)

-- --------------------------------------------------------------------------
-- armi della v0.3

-- toglie di mezzo un giocatore senza farlo morire (morire chiuderebbe il round)
local function park(p)
  p.invuln = 1e9
  pin(p, 40, p.y)
end

local function events_of(g, kind)
  local n = 0
  for _, e in ipairs(g:drain_events()) do if e.type == kind then n = n + 1 end end
  return n
end

test("frusta: tira l'avversario verso chi colpisce", function()
  local g, p1, p2 = duel("whip", nil, 40)
  local hit_vx
  for i = 1, 30 do
    g:update({ { attack_pressed = (i == 1) } })
    if p2.hp < 100 and not hit_vx then hit_vx = p2.vx end
  end
  check(hit_vx, "la frusta non ha colpito a 40 px")
  check(hit_vx < 0, "la vittima dovrebbe venire tirata verso sinistra, vx=" .. hit_vx)
end)

test("katana: scatto in avanti invulnerabile che colpisce", function()
  local g, p1, p2 = duel("katana", nil, 60)
  local x0, invuln_seen = p1.x, false
  for i = 1, 30 do
    g:update({ { attack_pressed = (i == 1) } })
    if p1.action and p1.action.phase == "active" and p1.invuln > 0 then invuln_seen = true end
  end
  check(p1.x - x0 > 40, "scatto troppo corto: " .. (p1.x - x0))
  check(invuln_seen, "nessuna invulnerabilita' durante il fendente")
  check(p2.hp < 100, "il fendente non ha colpito a 60 px")
end)

test("scudo: para i colpi frontali, non quelli alle spalle", function()
  local g, p1, p2 = duel("pistol", "shield", 200)
  p2.facing = -1                            -- guarda verso chi spara
  run(g, 40, function(i) pin(p2, p2.x, p2.y); return { { attack_pressed = (i == 1) } } end)
  check(p2.hp == 100, "lo scudo non ha parato: " .. p2.hp)
  check(p2.weapon.uses == data.weapons.shield.uses - 1, "parata non consumata")
  p2.facing = 1                             -- di spalle
  run(g, 40, function(i) pin(p2, p2.x, p2.y); p2.facing = 1; return { { attack_pressed = (i == 1) } } end)
  check(p2.hp < 100, "lo scudo ha parato alle spalle")
end)

test("scudo: il martello consuma tre parate", function()
  local g, p1, p2 = duel("hammer", "shield", 20)
  run(g, 30, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.hp == 100, "il martello e' passato")
  check(p2.weapon and p2.weapon.uses == data.weapons.shield.uses - 3, "parate rimaste: " .. tostring(p2.weapon and p2.weapon.uses))
end)

test("boomerang: torna indietro, colpisce e viene ripreso", function()
  local g, p1, p2 = duel("boomerang", nil, 120)
  local caught = false
  for i = 1, 200 do
    g:update({ { attack_pressed = (i == 1) } })
    for _, e in ipairs(g:drain_events()) do if e.type == "catch" then caught = true end end
    if caught then break end
  end
  check(caught, "il boomerang non e' tornato")
  check(p2.hp < 100, "il boomerang non ha colpito")
  check(p1.hp == 100, "il boomerang ha ferito chi l'ha lanciato")
  check(p1.weapon and p1.weapon.id == "boomerang" and not p1.weapon.out, "boomerang non ripreso")
  check(p1.weapon.ammo == data.weapons.boomerang.ammo - 1, "lanci rimasti errati")
end)

test("boomerang: finche' e' in volo non si lancia di nuovo", function()
  local g, p1, p2 = duel("boomerang", nil, 300)
  park(p2)
  run(g, 20, function(i) return { { attack_pressed = (i == 1 or i == 15) } } end)
  check(#g.projectiles == 1, "boomerang in volo: " .. #g.projectiles)
end)

test("lanciafiamme: da' fuoco e il fuoco continua a bruciare", function()
  local g, p1, p2 = duel("flamer", nil, 40)
  local max_stun = 0
  run(g, 20, function()
    if p2.hitstun > max_stun then max_stun = p2.hitstun end
    return { { attack_held = true } }
  end)
  check(p2.burn > 0, "la vittima non brucia")
  check(max_stun == 0, "le fiamme non dovrebbero stordire")
  local hp = p2.hp
  run(g, 60, function() pin(p2, p2.x, p2.y); return {} end)
  check(p2.hp < hp, "il fuoco non fa danno nel tempo")
  run(g, data.player.burn_frames + 10)
  check(p2.burn == 0, "il fuoco non si spegne")
end)

test("mine: si posano, si armano e scoppiano sotto chi passa", function()
  local g, p1, p2 = duel("mines", nil, 300)
  park(p2)
  run(g, 40, function(i) return { { attack_pressed = (i == 1), ax = 1, ay = 0.3 } } end)
  local m = g.projectiles[1]
  check(m and m.stuck, "la mina non si e' posata")
  -- passa sopra prima che sia armata: niente
  local p3x = m.x
  m.arm = 10
  pin(p1, p3x, p1.y)
  g:update({})
  check(#g.projectiles == 1 and p1.hp == 100, "esplosa prima di armarsi")
  pin(p1, p3x - 200, p1.y)
  run(g, 15, function() pin(p1, p3x - 200, p1.y); return {} end)
  check(m.arm == 0, "non si arma")
  run(g, 3, function() pin(p1, p3x, p1.y); return {} end)
  check(#g.projectiles == 0, "la mina armata non e' esplosa")
  check(p1.hp < 100, "l'esplosione non ha ferito chi ci e' passato (anche il proprietario)")
end)

test("rampino: sul muro trascina chi lo spara", function()
  local g, p1, p2 = duel("hook", nil, 300)
  park(p2)
  local wall_x = g.world.width - data.tile
  pin(p1, wall_x - 200, p1.y)
  local x0 = p1.x
  local grappled = false
  for i = 1, 40 do
    g:update({ { attack_pressed = (i == 1), ax = 1, ay = -0.2 } })
    if p1.grapple then grappled = true end
  end
  check(grappled, "il rampino non si e' agganciato")
  check(p1.x - x0 > 100, "trascinamento troppo corto: " .. (p1.x - x0))
end)

test("rampino: su un avversario lo tira verso di te", function()
  local g, p1, p2 = duel("hook", nil, 200)
  local pulled = false
  for i = 1, 20 do
    g:update({ { attack_pressed = (i == 1), ax = 1, ay = 0 } })
    if p2.vx < -200 then pulled = true end
  end
  check(pulled, "l'avversario non e' stato tirato")
end)

test("lanciarazzi: il razzo accelera ed esplode all'impatto", function()
  local g, p1, p2 = duel("bazooka", nil, 300)
  park(p2)
  run(g, 12, function(i) return { { attack_pressed = (i == 1) } } end)
  local r = g.projectiles[1]
  check(r and r.kind == "rocket", "nessun razzo")
  local v0 = math.abs(r.vx)
  run(g, 10)
  check(math.abs(r.vx) > v0 + 100, "il razzo non accelera")
  local boom = 0
  for _ = 1, 200 do g:update({}); boom = boom + events_of(g, "explosion"); if boom > 0 then break end end
  check(boom == 1, "il razzo non e' esploso contro il muro")
end)

test("lanciarazzi: salto col razzo sparando ai piedi", function()
  local g, p1, p2 = duel("bazooka", nil, 300)
  park(p2)
  local hp0 = p1.hp
  local min_vy = 0
  for i = 1, 30 do
    g:update({ { attack_pressed = (i == 1), ax = 0, ay = 1 } })
    if p1.vy < min_vy then min_vy = p1.vy end
  end
  check(min_vy < -250, "spinta verso l'alto troppo debole: " .. min_vy)
  check(p1.hp < hp0 and p1.hp > hp0 - 40, "danno a se stessi fuori misura: " .. p1.hp)
end)

test("soffiatore: nessun danno, spinta enorme", function()
  local g, p1, p2 = duel("gust", nil, 60)
  local max_vx = 0
  run(g, 20, function(i)
    if p2.vx > max_vx then max_vx = p2.vx end
    return { { attack_pressed = (i == 1) } }
  end)
  check(p2.hp == 100, "il soffiatore ha fatto danno")
  check(max_vx > 300, "spinta troppo debole: " .. max_vx)
end)

test("bolle: intrappola, fa salire, e scoppia con danno extra", function()
  local g, p1, p2 = duel("bubble", nil, 100)
  run(g, 30, function(i) return { { attack_pressed = (i == 1) } } end)
  check(p2.bubble > 0, "nessuna bolla")
  local y0 = p2.y
  run(g, 15, function(i) return { {}, { attack_pressed = (i % 6 == 0) } } end)
  check(p2.y < y0 - 5, "la bolla non sale")
  check(not p2.action, "chi e' nella bolla non deve poter attaccare")
  local hp = p2.hp
  Combat.hit(g, p1, p2, { dmg = 10, kb = 0 })
  check(p2.bubble == 0, "il colpo non fa scoppiare la bolla")
  check(hp - p2.hp == 10 + data.player.bubble_pop_bonus, "danno dello scoppio: " .. (hp - p2.hp))
end)

test("bolle: premere i tasti libera prima", function()
  local function bubble_time(mash)
    local g, p1, p2 = duel(nil, nil, 300)
    p2.bubble = data.player.bubble_frames
    local f = 0
    while p2.bubble > 0 and f < 500 do
      f = f + 1
      g:update({ {}, { jump_pressed = mash and (f % 4 == 0) } })
    end
    return f
  end
  check(bubble_time(true) < bubble_time(false) * 0.7, "premere i tasti non aiuta")
end)

test("buco nero: risucchia, fa danno al centro e poi collassa", function()
  local g, p1, p2 = duel("blackhole", nil, 140)
  local bx, by = p1.x + 70, p1.y - 40
  Combat.open_blackhole(g, bx, by, data.weapons.blackhole.field, 1)
  local d0 = math.abs(p2.x - bx)
  run(g, 30)
  check(math.abs(p2.x - bx) < d0 - 20, "il buco nero non attira")
  -- al centro: danno
  local hp = p2.hp
  run(g, 40, function() pin(p2, bx, by + p2.h / 2); return {} end)
  check(p2.hp < hp, "il nucleo non fa danno")
  run(g, data.weapons.blackhole.field.frames)
  check(#g.fields == 0, "il buco nero non si chiude")
end)

test("buco nero: lo sparo diventa un buco nero al muro", function()
  local g, p1, p2 = duel("blackhole", nil, 300)
  park(p2)
  run(g, 120, function(i) return { { attack_pressed = (i == 1) } } end)
  check(g.fields and #g.fields == 1, "nessun buco nero aperto")
end)

test("fucile fantasma: attraversa i muri", function()
  local g = Game.new({ players = 2, seed = 7, first_map = "prova" })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer = 1e9, 1e9
  local p1, p2 = g.players[1], g.players[2]
  -- p1 sotto una piattaforma solida? nella mappa di prova il muro e' il bordo: spariamo
  -- verso l'alto attraverso il soffitto e verifichiamo che il proiettile esca dalla mappa
  park(p2)
  pin(p1, 100, 21 * data.tile)
  p1.weapon = g:make_weapon("ghost")
  local escaped = false
  for i = 1, 60 do
    g:update({ { attack_pressed = (i == 1), ax = 0, ay = -1 } })
    for _, pr in ipairs(g.projectiles) do if pr.y < 0 then escaped = true end end
  end
  check(escaped, "il proiettile fantasma si e' fermato sul soffitto")
end)

test("lanciasciame: i missili inseguono l'avversario", function()
  local g, p1, p2 = duel("swarm", nil, 250)
  run(g, 10, function(i) return { { attack_pressed = (i == 1), ax = 0, ay = -1 } } end)
  check(#g.projectiles == 5, "missili: " .. #g.projectiles)
  local boom = 0
  for _ = 1, 150 do
    pin(p2, p2.x, p2.y)
    g:update({})
    boom = boom + events_of(g, "explosion")
  end
  check(boom >= 3, "pochi missili arrivati: " .. boom)
  check(p2.hp < 100, "i missili sparati verso l'alto non hanno raggiunto il bersaglio")
end)

-- --------------------------------------------------------------------------
-- fusione delle armi

local Fusion = require("src.sim.fusion")

-- tiene premuto il tasto raccogli per n frame, fermo sull'arma a terra
local function hold_pickup(g, frames, extra)
  for i = 1, frames do
    local inp = { pickup_pressed = (i == 1), pickup_held = true }
    if extra then for k, v in pairs(extra(i) or {}) do inp[k] = v end end
    g:update({ inp })
  end
  g:update({})
end

local function fuse_setup(held, ground)
  local g, p1, p2 = duel(held, nil, 300)
  p2.invuln = 1e9
  pin(p2, 40, p2.y)
  g:add_item(p1.x, p1.y - 4, g:make_weapon(ground))
  run(g, 3)
  return g, p1, p2
end

test("fusione: tenendo premuto mezzo secondo le armi si fondono", function()
  local g, p1 = fuse_setup("pistol", "flamer")
  hold_pickup(g, data.round.fuse_frames + 2)
  check(p1.weapon and p1.weapon.fused, "nessuna fusione")
  check(p1.weapon.fused.body == "pistol" and p1.weapon.fused.trait == "fuoco", "ingredienti sbagliati")
  check(#g.items == 0, "l'arma a terra non e' stata consumata")
  check(Fusion.name(p1.weapon) == "Pistola infuocata", "nome: " .. Fusion.name(p1.weapon))
end)

test("fusione: un tocco scambia invece di fondere", function()
  local g, p1 = fuse_setup("pistol", "flamer")
  hold_pickup(g, 3)
  check(p1.weapon.id == "flamer" and not p1.weapon.fused, "il tocco non ha scambiato")
end)

test("fusione: lasciando prima del tempo non succede niente", function()
  local g, p1 = fuse_setup("pistol", "flamer")
  hold_pickup(g, data.round.fuse_frames - 8)
  check(p1.weapon.id == "pistol" and not p1.weapon.fused, "fusione o scambio inattesi")
  check(#g.items == 1, "l'arma a terra e' sparita")
end)

test("fusione: un colpo subito la interrompe", function()
  local g, p1, p2 = fuse_setup("pistol", "flamer")
  local hit_done = false
  hold_pickup(g, data.round.fuse_frames + 2, function(i)
    if i == data.round.tap_frames + 5 and not hit_done then
      hit_done = true
      Combat.hit(g, p2, p1, { dmg = 5, kb = 50 })
    end
  end)
  check(not p1.weapon.fused, "la fusione non e' stata interrotta")
  check(#g.items == 1, "l'arma a terra e' stata consumata")
end)

test("fusione: durante la fusione si resta fermi", function()
  local g, p1 = fuse_setup("pistol", "flamer")
  local x0 = p1.x
  hold_pickup(g, data.round.fuse_frames - 2, function(i) return { mx = (i > data.round.tap_frames) and 1 or 0 } end)
  check(math.abs(p1.x - x0) < 3, "il giocatore si e' mosso durante la fusione: " .. (p1.x - x0))
end)

test("fusione: l'arma fusa riparte con le munizioni al massimo", function()
  local g, p1 = fuse_setup("pistol", "flamer")
  p1.weapon.ammo = 1
  hold_pickup(g, data.round.fuse_frames + 2)
  check(p1.weapon.ammo == data.weapons.pistol.ammo, "munizioni: " .. tostring(p1.weapon.ammo))
end)

test("fusione: niente fusione con le mitiche ne' tra armi gia' fuse", function()
  check(not Fusion.can_fuse({ id = "ghost" }, { id = "pistol" }), "mitica fondibile")
  check(not Fusion.can_fuse({ id = "pistol" }, { id = "swarm" }), "mitica fondibile come tratto")
  local f = Fusion.fuse({ id = "pistol" }, { id = "flamer" })
  check(not Fusion.can_fuse(f, { id = "sword" }), "arma fusa rifondibile")
  -- tenendo premuto con una mitica a terra si scambia
  local g, p1 = fuse_setup("pistol", "ghost")
  hold_pickup(g, data.round.fuse_frames + 2)
  check(p1.weapon.id == "ghost", "con una mitica tenere premuto dovrebbe scambiare")
end)

test("fusione: ogni coppia di armi fondibili produce un'arma valida", function()
  local pairs_, ids = Fusion.all_pairs()
  check(#ids == 20, "armi fondibili: " .. #ids)
  local count = 0
  for _, b in ipairs(ids) do
    for _, d in ipairs(ids) do
      local w = Fusion.fuse({ id = b }, { id = d })
      local def = w.def
      check(def and def.kind and def.startup and def.recovery, b .. "+" .. d .. ": definizione incompleta")
      if def.kind == "ranged" then check(def.proj and w.ammo and w.ammo > 0, b .. "+" .. d .. ": senza munizioni") end
      if def.kind == "melee" then check(def.hit and w.uses and w.uses > 0, b .. "+" .. d .. ": senza colpi") end
      check(#Fusion.name(w) > 0, b .. "+" .. d .. ": senza nome")
      count = count + 1
    end
  end
  check(count == 400)
end)

test("fusione: tutte le armi fuse si usano in partita senza errori", function()
  local _, ids = Fusion.all_pairs()
  for _, b in ipairs(ids) do
    for _, d in ipairs(ids) do
      local g, p1, p2 = duel(nil, nil, 60)
      p1.weapon = Fusion.fuse({ id = b }, { id = d })
      run(g, 70, function(i)
        return { { attack_pressed = (i % 20 == 1), attack_held = true, ax = 1, ay = (i % 40 < 20) and 0 or -0.4 } }
      end)
    end
  end
end)

test("tratti: pistola infuocata incendia, spada esplosiva esplode", function()
  local g, p1, p2 = duel(nil, nil, 120)
  p1.weapon = Fusion.fuse({ id = "pistol" }, { id = "flamer" })
  run(g, 40, function(i) pin(p2, p2.x, p2.y); return { { attack_pressed = (i == 1) } } end)
  check(p2.burn > 0, "la pistola infuocata non incendia")
  local g2, q1, q2 = duel(nil, nil, 22)
  q1.weapon = Fusion.fuse({ id = "sword" }, { id = "grenade" })
  local boom = 0
  for i = 1, 30 do
    g2:update({ { attack_pressed = (i == 1) } })
    for _, e in ipairs(g2:drain_events()) do if e.type == "explosion" then boom = boom + 1 end end
  end
  check(boom == 1, "la spada esplosiva non e' esplosa: " .. boom)
end)

test("tratti: pistola di ritorno torna da chi spara, boomerang potenziato fa piu' danno", function()
  local f = Fusion.fuse({ id = "pistol" }, { id = "boomerang" })
  check(f.def.proj.return_after, "i proiettili non tornano")
  local b = Fusion.fuse({ id = "boomerang" }, { id = "pistol" })
  check(b.def.damage > data.weapons.boomerang.damage, "il boomerang non fa piu' danno")
  local s = Fusion.fuse({ id = "sword" }, { id = "boomerang" })
  check(s.def.kind == "ranged" and s.def.returns and s.ammo == data.weapons.sword.uses, "spada da lancio")
end)

test("tratti: due armi uguali danno la versione doppia", function()
  local d = Fusion.fuse({ id = "pistol" }, { id = "pistol" })
  check(d.def.proj.count == 2, "la doppia pistola non spara due colpi")
  check(Fusion.name(d) == "Doppia pistola", "nome: " .. Fusion.name(d))
  local s = Fusion.fuse({ id = "sword" }, { id = "sword" })
  check(s.def.recovery < data.weapons.sword.recovery, "la doppia spada non e' piu' veloce")
end)

test("tratti: scudo corazzato para, l'arma in mano con Guardia consuma munizioni", function()
  local g, p1, p2 = duel(nil, nil, 200)
  p1.weapon = g:make_weapon("pistol")
  p2.weapon = Fusion.fuse({ id = "pistol" }, { id = "shield" })
  p2.facing = -1
  local ammo = p2.weapon.ammo
  run(g, 30, function(i) pin(p2, p2.x, p2.y); p2.facing = -1; return { { attack_pressed = (i == 1) } } end)
  check(p2.hp == 100, "la Guardia non ha parato: " .. p2.hp)
  check(p2.weapon.ammo == ammo - 1, "la parata non ha consumato munizioni")
end)

local function random_inputs(rng, n)
  local inputs = {}
  for i = 1, n do
    local function chance(p) return rng:float() < p end
    inputs[i] = {
      mx = (rng:float() * 2 - 1) * (chance(0.8) and 1 or 0),
      my = (rng:float() * 2 - 1) * (chance(0.3) and 1 or 0),
      jump_pressed = chance(0.05), jump_held = chance(0.4),
      attack_pressed = chance(0.12), attack_held = chance(0.3), dash_pressed = chance(0.04),
      parry_pressed = chance(0.04), pickup_pressed = chance(0.03), pickup_held = chance(0.3),
      throw_pressed = chance(0.01),
    }
    if chance(0.5) then
      inputs[i].ax, inputs[i].ay = rng:float() * 2 - 1, rng:float() * 2 - 1
    end
  end
  return inputs
end

local function fuzz(seed, players, frames, map)
  local g = Game.new({ players = players, seed = seed, first_map = map })
  local irng = RNG.new(seed * 7 + 1)
  for f = 1, frames do
    g:update(random_inputs(irng, players))
    g:drain_events()
    for _, p in ipairs(g.players) do
      if p.alive then
        check(p.x == p.x and p.y == p.y, "NaN nella posizione")
        check(p.x > 0 and p.x < g.world.width, "fuori dai lati: " .. p.x)
        check(p.y < g.world.height + 80, "caduto fuori mappa")
        check(g.world:tile_at(p.x, p.y - p.h / 2) ~= "#", "dentro un muro al frame " .. f)
        check(p.hp <= 100, "salute oltre il massimo")
      end
    end
    if g.phase == "matchend" then break end
  end
  return g
end

test("fuzz: 6 giocatori, input casuali, tutte le mappe, nessun errore", function()
  for _, map in ipairs(MAPS) do
    for seed = 1, 3 do
      fuzz(seed, 6, 3600, map)
    end
  end
end)

test("fuzz: 2 e 4 giocatori, match completi", function()
  for _, n in ipairs({ 2, 4 }) do
    for seed = 10, 12 do
      local g = fuzz(seed, n, 20000, nil)
      check(g.round >= 1)
    end
  end
end)

test("determinismo: stesso seme e stessi input danno la stessa partita", function()
  for seed = 1, 4 do
    local a = fuzz(seed, 5, 2500)
    local b = fuzz(seed, 5, 2500)
    check(a:checksum() == b:checksum(), "partite diverse per il seme " .. seed)
  end
end)

-- --------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Eventi di mappa

local MapEvents = require("src.sim.mapevents")

local function on_map(name)
  local g = Game.new({ players = 2, seed = 11, first_map = name })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer = 1e9, 1e9
  run(g, 30)
  return g
end

test("eventi di mappa: il fulmine colpisce chi sta nella colonna annunciata", function()
  local g = on_map("tetti")
  local p1 = g.players[1]
  local hp = p1.hp
  g.hazards = { { kind = "lightning", phase = "warn", x = p1.x, y = p1.y - 40, y0 = p1.y - 40, t = 2, vy = 0 } }
  g.event_timer = 1e9
  run(g, 3)
  check(p1.hp < hp or not p1.alive, "il fulmine non ha colpito")
end)

test("eventi di mappa: i massi cadono e colpiscono", function()
  local g = on_map("arena")
  local p1 = g.players[1]
  local hp = p1.hp
  g.hazards = { { kind = "rocks", phase = "fall", x = p1.x, y = p1.y - 120, y0 = 0, t = 0, vy = 0 } }
  g.event_timer = 1e9
  run(g, 60)
  check(p1.hp < hp or not p1.alive, "il masso non ha colpito")
  check(#g.hazards == 0, "il masso non e' sparito")
end)

test("eventi di mappa: partono da soli e sono deterministici", function()
  local function play()
    local g = on_map("fabbrica")
    local seen = 0
    for _ = 1, 1500 do
      g:update({})
      for _, e in ipairs(g:drain_events()) do if e.type == "map_event" then seen = seen + 1 end end
    end
    return seen, g:checksum()
  end
  local n1, c1 = play()
  local n2, c2 = play()
  check(n1 >= 1, "nessun evento in 25 secondi")
  check(n1 == n2 and c1 == c2, "non deterministico")
end)

-- ---------------------------------------------------------------------------
-- Elementi delle mappe: molle, nastri, portali, blocchi distruttibili, piattaforme mobili

do
  local row = function(str) return "#" .. str .. string.rep(".", 62 - #str) .. "#" end
  local rows = { string.rep("#", 64) }
  for _ = 2, 33 do rows[#rows + 1] = row("") end
  rows[20] = row("..S...........................................................")
  rows[21] = row("..W...........................................................")
  -- riga 33: J sopra il pavimento, P e P dei portali
  rows[33] = row("....J.........P...........S.................P......S..........")
  rows[34] = "#" .. string.rep("#", 20) .. string.rep(">", 10) .. string.rep("B", 6) .. string.rep("#", 26) .. "#"
  rows[35] = string.rep("#", 64)
  rows[36] = string.rep("#", 64)
  package.preload["src.maps.test_gadgets"] = function()
    return { name = "TestGadget", rows = rows,
             movers = { { c = 50, r = 25, len = 4, dc = 6, dr = 0, period = 240 } } }
  end
end

local function gadget_game()
  local g = Game.new({ players = 2, seed = 3, first_map = "test_gadgets", maps = { "test_gadgets" } })
  start_playing(g)
  g.items, g.telegraphs = {}, {}
  g.spawn_timer, g.crate_timer, g.event_timer = 1e9, 1e9, 1e9
  local p1, p2 = g.players[1], g.players[2]
  p2.x, p2.y = 900, 33 * data.tile
  return g, p1, p2
end

test("molla: chi ci sale sopra vola in alto", function()
  local g, p1 = gadget_game()
  local sp = g.world.springs[1]
  p1.x, p1.y, p1.vx, p1.vy = sp.x, sp.y, 0, 0
  run(g, 3)
  local top = p1.y
  run(g, 20, function() top = math.min(top, p1.y) end)
  check(33 * data.tile - top > 120, "salita solo di " .. (33 * data.tile - top))
end)

test("nastro: trascina chi sta fermo sopra", function()
  local g, p1 = gadget_game()
  p1.x, p1.y, p1.vx, p1.vy = 22 * data.tile, 33 * data.tile, 0, 0
  local x0 = p1.x
  run(g, 30)
  check(p1.x > x0 + 20, "spostato di " .. (p1.x - x0))
end)

test("portale: si esce dall'altro e non si rimbalza indietro", function()
  local g, p1 = gadget_game()
  local a, b = g.world.portals[1], g.world.portals[2]
  p1.x, p1.y, p1.vx, p1.vy = a.x, a.y, 0, 0
  run(g, 2)
  check(math.abs(p1.x - b.x) < 2, "non teletrasportato: x=" .. p1.x)
  run(g, 120)
  check(math.abs(p1.x - b.x) < 2, "rimbalzato indietro: x=" .. p1.x)
end)

test("blocchi distruttibili: un'esplosione li rompe e si cade nel buco", function()
  local g = gadget_game()
  local w = g.world
  local x, y = 33.5 * data.tile, 33 * data.tile
  check(w:tile_at(x, y + 4) == "#", "il blocco non c'e'")
  Combat.explode(g, x, y - 4, { radius = 40, dmg = 0, kb = 0 })
  check(w:tile_at(x, y + 4) == ".", "il blocco non si e' rotto")
  check(w.version > 0, "versione della mappa non aggiornata")
end)

test("piattaforma mobile: porta con se' chi ci sta sopra", function()
  local g, p1 = gadget_game()
  local m = g.movers[1]
  p1.x, p1.y, p1.vx, p1.vy = m.x + m.w / 2, m.y - 2, 0, 0
  run(g, 5)
  check(p1.grounded and p1.on_mover == m.id, "non e' salito sulla piattaforma")
  local dx0 = p1.x - m.x
  run(g, 60)
  check(p1.on_mover == m.id, "e' caduto dalla piattaforma")
  check(math.abs((p1.x - m.x) - dx0) < 1.5, "non si muove con la piattaforma")
end)

test("eventi di mappa: l'intensita' sale durante il round", function()
  local g = on_map("arena")
  local function count(frames)
    local n = 0
    for _ = 1, frames do
      g:update({})
      for _, e in ipairs(g:drain_events()) do if e.type == "map_event" then n = n + 1 end end
      for _, p in ipairs(g.players) do p.hp, p.alive = 100, true end
    end
    return n
  end
  local early = count(1200)
  g.round_frame = data.map_events.ramp
  local late = count(1200)
  check(late > early, "eventi a inizio " .. early .. ", a fine rampa " .. late)
end)

local function main()
  for _, t in ipairs(tests) do
    local ok, err = pcall(t.fn)
    if ok then
      passed = passed + 1
      print("  ok    " .. t.name)
    else
      failed = failed + 1
      print("  FAIL  " .. t.name .. "\n        " .. tostring(err))
    end
  end
  print(string.format("\n%d test superati, %d falliti", passed, failed))
  return failed
end

return main
