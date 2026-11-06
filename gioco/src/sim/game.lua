-- Partita completa: match, round, armi a terra, proiettili, morte improvvisa.
-- Nessuna dipendenza da LÖVE: si puo' simulare senza finestra.
--
-- Uso:
--   local g = Game.new{ players = 4, seed = 123 }
--   ogni frame (60 al secondo):  g:update(inputs)   -- inputs[i] = tabella input del giocatore i
--   eventi per grafica e audio:  for _, e in ipairs(g:drain_events()) do ... end
local data = require("src.sim.data")
local RNG = require("src.sim.rng")
local World = require("src.sim.world")
local Player = require("src.sim.player")
local Combat = require("src.sim.combat")
require("src.sim.fusion")
require("src.sim.recipes")      -- registra le ricette speciali nella fusione
local MapEvents = require("src.sim.mapevents")
local Movers = require("src.sim.movers")
local Gadgets = require("src.sim.gadgets")

local Game = {}
Game.__index = Game

local MAP_NAMES = { "arena", "fabbrica", "tetti", "miniera", "ghiacciaio", "vulcano", "tempio", "galeone", "laboratorio" }
local EMPTY = {}
local min, max = math.min, math.max

function Game.new(opts)
  opts = opts or {}
  local g = setmetatable({}, Game)
  g.n = opts.players or 2
  g.seed = opts.seed or 1
  g.rng = RNG.new(g.seed)
  g.frame = 0
  g.events = {}
  g.scores = {}
  for i = 1, g.n do g.scores[i] = 0 end
  g.wins_target = opts.wins or (g.n == 2 and data.round.wins_duel or data.round.wins)
  g.round = 0
  g.recent_maps = {}
  g.map_names = opts.maps or MAP_NAMES
  g.winners = {}
  g.match_winners = nil
  g.next_item_id = 1
  g:start_round(opts.first_map)
  return g
end

function Game:emit(kind, x, y, extra)
  local e = extra or {}
  e.type, e.x, e.y = kind, x, y
  self.events[#self.events + 1] = e
end

function Game:drain_events()
  local ev = self.events
  self.events = {}
  return ev
end

-- ---------------------------------------------------------------------------
-- Round

function Game:pick_map(forced)
  if forced then return forced end
  local candidates = {}
  for _, name in ipairs(self.map_names) do
    local recent = false
    for _, r in ipairs(self.recent_maps) do
      if r == name then recent = true end
    end
    if not recent then candidates[#candidates + 1] = name end
  end
  if #candidates == 0 then candidates = self.map_names end
  return self.rng:pick(candidates)
end

function Game:start_round(forced_map)
  local R = data.round
  self.round = self.round + 1
  self.map_name = self:pick_map(forced_map)
  self.recent_maps[#self.recent_maps + 1] = self.map_name
  while #self.recent_maps > R.map_repeat_block do table.remove(self.recent_maps, 1) end

  self.world = World.new(require("src.maps." .. self.map_name))
  self.tnt_queue = {}
  local world = self.world

  local spawns = {}
  for _, s in ipairs(world.spawns) do spawns[#spawns + 1] = s end
  self.rng:shuffle(spawns)

  self.players = {}
  for i = 1, self.n do
    local s = spawns[((i - 1) % #spawns) + 1]
    self.players[i] = Player.new(i, s, data.colors[((i - 1) % #data.colors) + 1])
  end

  self.items, self.projectiles, self.telegraphs, self.fields = {}, {}, {}, {}
  -- armi iniziali: meno dei giocatori, in punti diversi della mappa, cosi' si fa a gara
  local pts = {}
  for _, s in ipairs(world.weapon_spawns) do pts[#pts + 1] = s end
  self.rng:shuffle(pts)
  local count = min(#pts, max(1, self.n - R.start_items_less))
  for k = 1, count do
    local it = self:add_item(pts[k].x, pts[k].y - 6, self:random_weapon(data.start_tier))
    it.life = it.life + R.countdown
  end

  self.phase = "countdown"
  self.timer = R.countdown
  self.round_frame = 0
  self.lava_on = false
  self.lava_y = world.height
  self.spawn_timer = self.rng:int(R.spawn_min, R.spawn_max)
  self.crate_timer = self.rng:int(R.crate_min, R.crate_max)
  self.winners = {}
  MapEvents.reset(self)
  Movers.reset(self)
  self:emit("round_setup", 0, 0, { round = self.round, map = world.name })
end

function Game:alive_count()
  local n = 0
  for _, p in ipairs(self.players) do
    if p.alive then n = n + 1 end
  end
  return n
end

function Game:check_round_end()
  local R = data.round
  local alive = {}
  for _, p in ipairs(self.players) do
    if p.alive then alive[#alive + 1] = p end
  end
  if #alive > 1 then return end
  local winners = {}
  if #alive == 1 then
    winners[1] = alive[1].id
  else
    local last = 0
    for _, p in ipairs(self.players) do
      if p.death_frame and p.death_frame > last then last = p.death_frame end
    end
    for _, p in ipairs(self.players) do
      if p.death_frame and p.death_frame >= last - R.simultaneous_window then
        winners[#winners + 1] = p.id
      end
    end
  end
  for _, id in ipairs(winners) do self.scores[id] = self.scores[id] + 1 end
  self.winners = winners
  self.phase = "roundend"
  self.timer = R.end_delay
  local fused = {}
  for _, id in ipairs(winners) do
    local w = self.players[id].weapon
    if w and w.fused then fused[id] = true end
  end
  self:emit("round_end", 0, 0, { winners = winners, fused = fused })
end

function Game:finish_round_end()
  local best = 0
  for _, s in ipairs(self.scores) do best = max(best, s) end
  if best >= self.wins_target then
    local w = {}
    for i, s in ipairs(self.scores) do
      if s == best then w[#w + 1] = i end
    end
    self.match_winners = w
    self.phase = "matchend"
    self:emit("match_end", 0, 0, { winners = w })
  else
    self:start_round()
  end
end

-- ---------------------------------------------------------------------------
-- Armi a terra

-- Crea un'arma nuova (piena di munizioni o colpi). Il secondo argomento e' ignorato:
-- resta per compatibilita' con il codice della v0.2.
function Game:make_weapon(id)
  local def = data.weapons[id]
  local w = { id = id, tier = def.tier or 1, dmg_mul = 1 }
  if def.uses then w.uses = def.uses end
  if def.ammo then w.ammo = def.ammo end
  return w
end

-- Probabilita' dei livelli in questo momento del round (si spostano verso i livelli alti)
function Game:tier_weights()
  local k = min(1, max(0, (self.round_frame or 0) / data.tier_ramp_frames))
  local out = {}
  for t, tier in ipairs(data.tiers) do
    out[#out + 1] = { key = t, weight = tier.weight_start + (tier.weight_end - tier.weight_start) * k }
  end
  return out
end

-- Arma a caso: prima il livello (se non e' dato), poi l'arma dentro il livello
function Game:random_weapon(tier)
  if type(tier) ~= "number" then tier = self.rng:weighted(self:tier_weights()) end
  local entries = {}
  for _, id in ipairs(data.tiers[tier].weapons) do
    entries[#entries + 1] = { key = id, weight = data.weapons[id].weight or 10 }
  end
  return self:make_weapon(self.rng:weighted(entries))
end

-- Contenuto della cassa centrale: solo livelli alti
function Game:crate_weapon()
  local entries = {}
  for _, c in ipairs(data.crate_tiers) do entries[#entries + 1] = { key = c.tier, weight = c.weight } end
  return self:random_weapon(self.rng:weighted(entries))
end

-- true se l'arma ha ancora munizioni o colpi (le armi consumate si rompono)
function Game.charged(w)
  if not w then return false end
  if w.ammo then return w.ammo > 0 end
  if w.uses then return w.uses > 0 end
  return true
end

function Game:add_item(x, y, weapon, vx, vy)
  local it = {
    id = self.next_item_id, x = x, y = y, w = 10, h = 8,
    vx = vx or 0, vy = vy or 0, weapon = weapon,
    life = data.round.item_life, grounded = false, pickup_delay = 0,
  }
  self.next_item_id = self.next_item_id + 1
  self.items[#self.items + 1] = it
  -- troppe armi a terra: sparisce la piu' vecchia
  while #self.items > data.round.max_ground do table.remove(self.items, 1) end
  return it
end

-- Lascia a terra un'arma (scambio, lancio, eliminazione). Un'arma consumata si rompe.
function Game:drop_item(x, y, weapon, vx, vy)
  if not Game.charged(weapon) then
    self:emit("break", x, y, { weapon = weapon and weapon.id })
    return nil
  end
  weapon.out = nil
  local it = self:add_item(x, y, weapon, vx or 0, vy or -120)
  it.pickup_delay = 20
  it.dropped = true
  return it
end

-- Arma a terra piu' vicina che il giocatore tocca (nil se nessuna)
function Game:item_near(p)
  local x1, y1, x2, y2 = Player.box(p)
  local best, bd
  for _, it in ipairs(self.items) do
    if it.pickup_delay <= 0
       and Combat.overlap(x1 - 3, y1 - 3, x2 + 3, y2 + 3, it.x - 5, it.y - 8, it.x + 5, it.y) then
      local d = math.abs(it.x - p.x)
      if not bd or d < bd then best, bd = it, d end
    end
  end
  return best
end

function Game:remove_item(item)
  for i, it in ipairs(self.items) do
    if it == item then table.remove(self.items, i); return true end
  end
  return false
end

-- Prende l'arma a terra; quella che si aveva in mano resta a terra intatta
function Game:take_item(p, it)
  self:remove_item(it)
  if p.weapon then self:drop_item(p.x, p.y - 6, p.weapon, 0, -60) end
  p.weapon = it.weapon
  self:emit("pickup", p.x, p.y - 12, { id = p.id, weapon = p.weapon.id })
end

-- La fusione e' possibile tra l'arma in mano e quella a terra?
function Game:can_fuse(p, it)
  return require("src.sim.fusion").can_fuse(p.weapon, it.weapon)
end

function Game:update_items()
  local world = self.world
  local dt = data.dt
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    it.life = it.life - 1
    if it.pickup_delay > 0 then it.pickup_delay = it.pickup_delay - 1 end
    it.vy = min(it.vy + 700 * dt, 400)
    if it.grounded then it.vx = it.vx * 0.8 end
    world:move_x(it, it.vx * dt)
    local landed = world:move_y(it, it.vy * dt)
    if landed then it.vy = 0; it.grounded = true else it.grounded = false end
    if it.life <= 0 or it.y > world.height + 40 or (self.lava_on and it.y > self.lava_y) then
      -- chi la stava fondendo perde la fusione
      for _, p in ipairs(self.players) do
        if p.fusing and p.fusing.item == it then self:cancel_fusion(p, "sparita") end
      end
      table.remove(self.items, i)
    end
  end
end

function Game:update_spawner()
  local R = data.round
  local world = self.world
  self.spawn_timer = self.spawn_timer - 1
  if self.spawn_timer <= 0 then
    self.spawn_timer = self.rng:int(R.spawn_min, R.spawn_max)
    local pts = world.weapon_spawns
    local spawned = 0
    for _, it in ipairs(self.items) do if not it.dropped then spawned = spawned + 1 end end
    if #pts > 0 and (spawned + #self.telegraphs) < R.max_items then
      local pt = self.rng:pick(pts)
      self.telegraphs[#self.telegraphs + 1] = { x = pt.x, y = pt.y - 6, t = R.telegraph,
                                                weapon = self:random_weapon() }
      self:emit("telegraph", pt.x, pt.y)
    end
  end
  self.crate_timer = self.crate_timer - 1
  if self.crate_timer <= 0 then
    self.crate_timer = self.rng:int(R.crate_min, R.crate_max)
    local c = world.crate
    self.telegraphs[#self.telegraphs + 1] = { x = c.x, y = c.y, t = R.telegraph,
                                              weapon = self:crate_weapon(), crate = true }
    self:emit("telegraph", c.x, c.y, { crate = true })
  end
  for i = #self.telegraphs, 1, -1 do
    local t = self.telegraphs[i]
    t.t = t.t - 1
    if t.t <= 0 then
      self:add_item(t.x, t.y, t.weapon)
      self:emit("item_spawn", t.x, t.y, { crate = t.crate })
      table.remove(self.telegraphs, i)
    end
  end
end

-- Raccolta, scambio, fusione e lancio.
--   mani vuote: si raccoglie passando sopra un'arma
--   tasto raccogli toccato (rilasciato entro tap_frames): scambio con l'arma a terra
--   tasto raccogli tenuto: fusione, se possibile (altrimenti scambio al termine del tocco);
--     la fusione richiede fuse_frames, il giocatore resta fermo e un colpo la interrompe
--   tasto lancia: lancia l'arma in mano
function Game:update_pickups(inputs)
  local R = data.round
  for i, p in ipairs(self.players) do
    local inp = (inputs and inputs[i]) or EMPTY
    local busy = not p.alive or p.hitstun > 0 or p.clash > 0 or p.bubble > 0
                 or (p.action and p.action.type == "attack")
    if busy then
      if p.fusing then self:cancel_fusion(p, "interrotta") end
      p.grab_t = 0
    else
      local held = inp.pickup_held
      if p.fusing then
        local it = p.fusing.item
        local still = held and self:item_near(p) == it
        if not still then
          self:cancel_fusion(p, held and "lontano" or "rilasciata")
        else
          p.fusing.t = p.fusing.t + 1
          if p.fusing.t >= R.fuse_frames then self:complete_fusion(p, it) end
        end
      elseif held then
        p.grab_t = (p.grab_t or 0) + 1
        local it = self:item_near(p)
        if it and p.weapon and p.grab_t == R.tap_frames then
          if self:can_fuse(p, it) then
            p.fusing = { item = it, t = p.grab_t }
            self:emit("fuse_start", p.x, p.y - 12, { id = p.id })
          else
            self:take_item(p, it)          -- niente fusione possibile: tenere premuto scambia
          end
        end
      else
        if (p.grab_t or 0) > 0 and p.grab_t < R.tap_frames and p.weapon then
          local it = self:item_near(p)
          if it then self:take_item(p, it) end
        end
        p.grab_t = 0
      end
      -- mani vuote: raccolta automatica
      if not p.weapon and not p.fusing then
        local it = self:item_near(p)
        if it then self:take_item(p, it) end
      end
      -- lancio
      if inp.throw_pressed and p.weapon and not p.action and not p.fusing then
        Combat.throw_weapon(self, p)
      end
    end
  end
end

function Game:cancel_fusion(p, why)
  p.fusing = nil
  p.grab_t = 0
  self:emit("fuse_cancel", p.x, p.y - 12, { id = p.id, why = why })
end

-- Completa la fusione (la logica dell'arma risultante e' in fusion.lua)
function Game:complete_fusion(p, it)
  local Fusion = require("src.sim.fusion")
  p.fusing = nil
  p.grab_t = -1e9            -- finche' non si rilascia il tasto non riparte niente
  local fused = Fusion.fuse(p.weapon, it.weapon)
  self:remove_item(it)
  p.weapon = fused
  self:emit("fused", p.x, p.y - 12, { id = p.id, weapon = fused.id, recipe = fused.fused.recipe,
                                       body = fused.fused.body, donor = fused.fused.donor,
                                       name = Fusion.name(fused) })
end

-- ---------------------------------------------------------------------------
-- Pericoli

-- Chi cade nel vuoto (mappa Tetti) muore, in qualunque fase del round.
function Game:update_void()
  local limit = self.world.height + data.player.fall_death_margin
  for _, p in ipairs(self.players) do
    if p.alive and p.y > limit then
      Combat.kill(self, p, nil, "void")
    end
  end
end

function Game:update_hazards()
  local P = data.player
  local world = self.world
  for _, p in ipairs(self.players) do
    if p.alive then
      local x1, y1, x2, y2 = Player.box(p)
      -- margine di 3 px: chi sta sul bordo accanto agli spuntoni non si punge
      if p.spike_cd == 0 and p.invuln == 0 and world:rect_touches(x1 + 3, y2 - 8, x2 - 3, y2, "^") then
        p.spike_cd = P.spike_cooldown
        Combat.hazard_hit(self, p, P.spike_damage, "spikes")
      end
      if p.alive and self.lava_on and p.y > self.lava_y then
        Combat.kill(self, p, nil, "lava")
      end
    end
  end
  self:update_void()
end

function Game:update_lava()
  local R = data.round
  if self.round_frame == R.sudden_death_warning then
    self:emit("sudden_death_warning", 0, 0)
  end
  if self.round_frame >= R.sudden_death then
    if not self.lava_on then
      self.lava_on = true
      self:emit("sudden_death", 0, 0)
    end
    self.lava_y = self.lava_y - R.lava_speed
  end
end

-- ---------------------------------------------------------------------------
-- Aggiornamento

function Game:step_players(inputs, idle)
  local n = #self.players
  for k = 0, n - 1 do
    local i = ((self.frame + k) % n) + 1
    Player.update(self.players[i], idle and EMPTY or (inputs[i] or EMPTY), self)
  end
end

function Game:update(inputs)
  inputs = inputs or EMPTY
  self.frame = self.frame + 1
  local ph = self.phase
  Movers.update(self)
  if ph == "countdown" then
    self:step_players(inputs, true)
    self:update_void()
    self.timer = self.timer - 1
    if self.timer <= 0 then
      self.phase = "playing"
      self.round_frame = 0
      self:emit("round_start", 0, 0)
    end
  elseif ph == "playing" then
    self.round_frame = self.round_frame + 1
    self:step_players(inputs, false)
    Gadgets.update(self)
    Combat.update_projectiles(self)
    Combat.update_fields(self)
    Combat.update_tnt(self)
    Combat.blocks_broken(self, self.world:update_crumble(self.players), 0, 0)
    self:update_items()
    self:update_pickups(inputs)
    self:update_hazards()
    self:update_lava()
    MapEvents.update(self)
    self:update_spawner()
    self:check_round_end()
  elseif ph == "roundend" then
    self:step_players(inputs, true)
    Gadgets.update(self)
    Combat.update_projectiles(self)
    Combat.update_fields(self)
    self:update_items()
    self:update_void()
    self.timer = self.timer - 1
    if self.timer <= 0 then self:finish_round_end() end
  end
end

-- Riassunto numerico dello stato, utile per i test di determinismo
function Game:checksum()
  local s = 0
  for _, p in ipairs(self.players) do
    s = s + p.x * 1.3 + p.y * 1.7 + p.hp * 0.3 + p.vx * 0.01 + p.vy * 0.02
  end
  s = s + #self.items * 11 + #self.projectiles * 7 + self.frame * 0.001
  return string.format("%.4f", s)
end

return Game
