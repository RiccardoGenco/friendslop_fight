-- Gestione controller e tastiera. Ogni "slot" e' un giocatore (un joystick o uno schema di tastiera).
-- La simulazione gira a passo fisso, quindi le pressioni dei tasti si accumulano
-- finche' un passo di simulazione non le consuma: nessun input viene perso.

local Input = {}
Input.slots = {}
Input.mouse = { active = false, x = 0, y = 0 }   -- mira col mouse per la tastiera 1

local DEADZONE = 0.25          -- zona morta radiale dello stick sinistro
local AIM_DEADZONE = 0.3       -- zona morta della levetta destra (mira)
local TRIGGER_ON = 0.5

local KEYBOARD = {
  { name = "Tastiera 1",
    help = "WASD muovi, Spazio salta, mouse mira, click attacca, click destro o Q parry, Shift scatto, E scambia (tieni: fondi), G lancia",
    left = "a", right = "d", up = "w", down = "s", jump = { "w", "space" },
    attack = "j", dash = { "lshift", "k" }, parry = { "q", "l" }, pickup = { "e", "u" }, throw = "g",
    start = "return" },
  { name = "Tastiera 2",
    help = "Frecce muovi e salta, Z attacco, X scatto, C parry, V scambia (tieni: fondi), B lancia",
    left = "left", right = "right", up = "up", down = "down", jump = { "up" },
    attack = "z", dash = "x", parry = "c", pickup = "v", throw = "b", start = "rshift" },
}

local BUTTONS = { "jump", "attack", "dash", "parry", "pickup", "throw", "start" }

local function new_slot(kind)
  return {
    kind = kind, prev = {}, cur = { mx = 0, my = 0 }, pending = {}, disconnected = false,
  }
end

function Input.reset()
  Input.slots = {}
end

function Input.count()
  return #Input.slots
end

function Input.has_joystick(joy)
  for _, s in ipairs(Input.slots) do
    if s.joy == joy then return true end
  end
  return false
end

function Input.has_keyboard(index)
  for _, s in ipairs(Input.slots) do
    if s.kb == index then return true end
  end
  return false
end

function Input.add_joystick(joy)
  if #Input.slots >= 6 or Input.has_joystick(joy) then return nil end
  local s = new_slot("pad")
  s.joy = joy
  s.guid = joy:getGUID()
  s.name = "Controller " .. (#Input.slots + 1)
  Input.slots[#Input.slots + 1] = s
  return s
end

function Input.add_keyboard(index)
  if #Input.slots >= 6 or Input.has_keyboard(index) then return nil end
  local s = new_slot("kb")
  s.kb = index
  s.name = KEYBOARD[index].name
  s.help = KEYBOARD[index].help
  Input.slots[#Input.slots + 1] = s
  return s
end

function Input.add_bot()
  if #Input.slots >= 6 then return nil end
  local s = new_slot("bot")
  s.name = "Bot " .. (#Input.slots + 1)
  Input.slots[#Input.slots + 1] = s
  return s
end

function Input.remove_last()
  table.remove(Input.slots)
end

function Input.remove_joystick(joy)
  for i, s in ipairs(Input.slots) do
    if s.joy == joy then table.remove(Input.slots, i); return true end
  end
  return false
end

-- Un controller scollegato e poi ricollegato torna al suo slot
function Input.joystick_added(joy)
  for _, s in ipairs(Input.slots) do
    if s.kind == "pad" and s.disconnected and s.guid == joy:getGUID() then
      s.joy = joy
      s.disconnected = false
      return s
    end
  end
  return nil
end

function Input.joystick_removed(joy)
  for _, s in ipairs(Input.slots) do
    if s.joy == joy then s.disconnected = true end
  end
end

function Input.any_disconnected()
  for i, s in ipairs(Input.slots) do
    if s.disconnected then return i, s end
  end
  return nil
end

local function read_pad(s)
  local j = s.joy
  local r = { mx = 0, my = 0 }
  if not j or not j:isConnected() then
    s.disconnected = true
    return r
  end
  if not j:isGamepad() then return r end
  local lx, ly = j:getGamepadAxis("leftx"), j:getGamepadAxis("lefty")
  local len = math.sqrt(lx * lx + ly * ly)
  if len > DEADZONE then
    local k = math.min(1, (len - DEADZONE) / (1 - DEADZONE)) / len
    r.mx, r.my = lx * k, ly * k
  end
  -- levetta destra: mira libera. Se e' a riposo la simulazione usa la mira classica.
  local rx, ry = j:getGamepadAxis("rightx"), j:getGamepadAxis("righty")
  if math.sqrt(rx * rx + ry * ry) > AIM_DEADZONE then r.ax, r.ay = rx, ry end
  if j:isGamepadDown("dpleft") then r.mx = -1 end
  if j:isGamepadDown("dpright") then r.mx = 1 end
  if j:isGamepadDown("dpup") then r.my = -1 end
  if j:isGamepadDown("dpdown") then r.my = 1 end
  r.jump = j:isGamepadDown("a")
  r.attack = j:isGamepadDown("x") or j:getGamepadAxis("triggerright") > TRIGGER_ON
  r.dash = j:isGamepadDown("b")
  r.parry = j:isGamepadDown("leftshoulder") or j:getGamepadAxis("triggerleft") > TRIGGER_ON
  r.pickup = j:isGamepadDown("y")             -- tocco: scambia; tenuto: fonde
  r.throw = j:isGamepadDown("rightshoulder")  -- lancia l'arma (RB / R1)
  r.start = j:isGamepadDown("start")
  return r
end

local function any_down(keys)
  if type(keys) == "string" then return love.keyboard.isDown(keys) end
  for _, k in ipairs(keys) do
    if love.keyboard.isDown(k) then return true end
  end
  return false
end

local function read_kb(s)
  local k = KEYBOARD[s.kb]
  local r = { mx = 0, my = 0 }
  if love.keyboard.isDown(k.left) then r.mx = r.mx - 1 end
  if love.keyboard.isDown(k.right) then r.mx = r.mx + 1 end
  if love.keyboard.isDown(k.up) then r.my = r.my - 1 end
  if love.keyboard.isDown(k.down) then r.my = r.my + 1 end
  r.jump = any_down(k.jump)
  r.attack = love.keyboard.isDown(k.attack) or (s.kb == 1 and Input.mouse.active and Input.mouse_held())
  r.dash = any_down(k.dash)
  r.parry = any_down(k.parry)
  r.pickup = any_down(k.pickup)
  r.throw = any_down(k.throw)
  r.start = false   -- la tastiera usa Esc/Invio, gestiti da main
  return r
end

-- Da chiamare una volta per frame di rendering
function Input.poll()
  for _, s in ipairs(Input.slots) do
    if s.kind ~= "bot" then
      local r = (s.kind == "pad") and read_pad(s) or read_kb(s)
      for _, b in ipairs(BUTTONS) do
        if r[b] and not s.prev[b] then s.pending[b] = true end
      end
      s.prev = r
      s.cur = r
    end
  end
end

-- Input per un passo di simulazione; azzera le pressioni accumulate
function Input.consume(s)
  local c, p = s.cur, s.pending
  local out = {
    mx = c.mx, my = c.my, ax = c.ax, ay = c.ay, jump_held = c.jump or false,
    attack_held = c.attack or false,
    jump_pressed = p.jump or false, attack_pressed = p.attack or false,
    dash_pressed = p.dash or false, parry_pressed = p.parry or false,
    pickup_pressed = p.pickup or false, pickup_held = c.pickup or p.pickup or false,
    throw_pressed = p.throw or false,
  }
  p.jump, p.attack, p.dash, p.parry, p.pickup, p.throw = nil, nil, nil, nil, nil, nil
  return out
end

-- Pressione di "start" da un controller (pausa, avvio); consuma l'evento
function Input.start_pressed()
  for _, s in ipairs(Input.slots) do
    if s.pending.start then
      s.pending.start = nil
      return true
    end
  end
  return false
end

-- Tastiera 1: click sinistro attacca, click destro para
function Input.mouse_held()
  return love.mouse.isDown(1)
end

function Input.mouse_button(button)
  for _, s in ipairs(Input.slots) do
    if s.kind == "kb" and s.kb == 1 then
      if button == 1 then s.pending.attack = true
      elseif button == 2 then s.pending.parry = true end
    end
  end
end

function Input.clear_pending()
  for _, s in ipairs(Input.slots) do s.pending = {} end
end

Input.KEYBOARD = KEYBOARD

return Input
