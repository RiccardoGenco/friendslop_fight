-- Effetti sonori generati dal codice (segnaposto): nessun file audio necessario.
-- Quando avrai suoni veri basta sostituire le voci di Audio.sources.

local Audio = { sources = {}, enabled = true, active = {} }

local RATE = 22050

local function make(freq, dur, wave, vol, sweep, noise)
  local n = math.floor(RATE * dur)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local phase = 0
  for i = 0, n - 1 do
    local t = i / n
    phase = phase + (freq + (sweep or 0) * t) / RATE
    local v
    if noise then
      v = love.math.random() * 2 - 1
    elseif wave == "square" then
      v = (phase % 1 < 0.5) and 1 or -1
    elseif wave == "saw" then
      v = (phase % 1) * 2 - 1
    else
      v = math.sin(phase * 2 * math.pi)
    end
    local env = (1 - t) * (1 - t)
    sd:setSample(i, v * vol * env)
  end
  return love.audio.newSource(sd, "static")
end

function Audio.load()
  local ok = pcall(function()
    local s = Audio.sources
    s.hit = make(220, 0.12, "square", 0.30, -160)
    s.parry = make(900, 0.14, "sine", 0.35, 500)
    s.clash = make(500, 0.14, "saw", 0.25, -300)
    s.shoot = make(0, 0.10, "square", 0.22, 0, true)
    s.jump = make(300, 0.08, "square", 0.12, 250)
    s.dash = make(0, 0.10, "square", 0.10, 0, true)
    s.death = make(160, 0.40, "saw", 0.35, -140)
    s.pickup = make(600, 0.10, "sine", 0.25, 400)
    s.telegraph = make(420, 0.18, "sine", 0.15, 200)
    s.spawn = make(700, 0.12, "square", 0.15, 300)
    s.round_start = make(440, 0.30, "square", 0.25, 440)
    s.round_end = make(330, 0.40, "sine", 0.30, -150)
    s.tick = make(800, 0.05, "square", 0.15, 0)
    s.break_ = make(120, 0.20, "saw", 0.30, -80)
    s.ricochet = make(1400, 0.07, "sine", 0.18, -700)
    s.explosion = make(0, 0.45, "square", 0.40, 0, true)
    s.sniper = make(90, 0.25, "saw", 0.35, -60)
  end)
  Audio.enabled = ok
end

function Audio.play(name, pitch, volume)
  if not Audio.enabled then return end
  local src = Audio.sources[name]
  if not src then return end
  -- limite di voci contemporanee
  local alive = {}
  for _, c in ipairs(Audio.active) do
    if c:isPlaying() then alive[#alive + 1] = c end
  end
  Audio.active = alive
  if #alive >= 12 then return end
  local c = src:clone()
  c:setPitch(pitch or 1)
  c:setVolume(volume or 0.8)
  c:play()
  Audio.active[#Audio.active + 1] = c
end

return Audio
