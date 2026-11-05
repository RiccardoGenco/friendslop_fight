-- Effetti sonori generati dal codice (segnaposto): nessun file audio necessario.
-- Quando avrai suoni veri basta sostituire le voci di Audio.sources.

local Audio = { sources = {}, enabled = true, active = {}, sfx_vol = 0.64, music_mul = 0.48 }

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
    -- interfaccia
    s.ui_move = make(1200, 0.04, "square", 0.08, 300)
    s.ui_ok = Audio.notes({ 660, 990 }, 0.06, "square", 0.14)
    s.ui_back = Audio.notes({ 700, 440 }, 0.06, "square", 0.12)
    s.ui_error = make(110, 0.18, "saw", 0.22, -30)
    s.ui_coin = Audio.notes({ 988, 1319, 1760 }, 0.05, "square", 0.13)
    s.ui_unlock = Audio.notes({ 523, 659, 784, 1047 }, 0.09, "square", 0.15)
    s.ui_join = Audio.notes({ 392, 587 }, 0.07, "square", 0.14)
  end)
  Audio.enabled = ok
  pcall(Audio.load_music)
end

-- breve sequenza di note (pling dei menu)
function Audio.notes(freqs, each, wave, vol)
  local per = math.floor(RATE * each)
  local sd = love.sound.newSoundData(per * #freqs, RATE, 16, 1)
  for k, fq in ipairs(freqs) do
    local phase = 0
    for i = 0, per - 1 do
      local t = i / per
      phase = phase + fq / RATE
      local v = (wave == "square") and ((phase % 1 < 0.5) and 1 or -1) or math.sin(phase * 2 * math.pi)
      local env = (k == #freqs) and (1 - t) * (1 - t) or (1 - 0.4 * t)
      sd:setSample((k - 1) * per + i, v * vol * env)
    end
  end
  return love.audio.newSource(sd, "static")
end

-- Musica generata dal codice. Un brano e' un giro di accordi suonato con basso a triangolo,
-- arpeggio a impulso stretto, charleston di rumore ed eventuale cassa.
local function make_track(chords, bpm, opts)
  local eighth = 60 / bpm / 2
  local per = math.floor(RATE * eighth)
  local reps = opts.reps or 2
  local n = per * 8 * #chords * reps
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  local i = 0
  for rep = 1, reps do
    for _, ch in ipairs(chords) do
      for step = 0, 7 do
        local arp = ch[(step % 3) + 1] * ((step >= 4) and 2 or 1) * ((rep == 2 and step % 2 == 1) and 2 or 1)
        local bass = ch[1] / 2
        local bass_on = opts.drive or step % 2 == 0
        for j = 0, per - 1 do
          local t = j / per
          local tt = i / RATE
          local a = ((tt * arp) % 1 < (opts.duty or 0.25)) and 1 or -1
          local b = 1 - 4 * math.abs(((tt * bass) % 1) - 0.5)
          local v = a * (opts.lead or 0.05) * (1 - t) ^ 1.5 + b * 0.10 * (bass_on and (1 - 0.5 * t) or 0.6)
          if step % 4 == 2 or (opts.drive and step % 2 == 1) then
            v = v + (love.math.random() * 2 - 1) * 0.04 * (1 - t) ^ 6
          end
          if opts.kick and step % 4 == 0 then
            -- cassa: sinusoide che scende di frequenza
            local kf = 120 * (1 - t) ^ 3 + 40
            v = v + math.sin(2 * math.pi * kf * j / RATE) * 0.22 * (1 - t) ^ 4
          end
          sd:setSample(i, math.max(-1, math.min(1, v)))
          i = i + 1
        end
      end
    end
  end
  local src = love.audio.newSource(sd, "static")
  src:setLooping(true)
  src:setVolume(0)
  return src
end

function Audio.load_music()
  -- menu: La- Fa Do Sol, tranquillo
  Audio.tracks = {
    menu = make_track({ { 220, 261.6, 329.6 }, { 174.6, 220, 261.6 }, { 130.8, 164.8, 196 }, { 196, 246.9, 293.7 } },
      112, {}),
    -- battaglia: Mi- Do Re Si (tensione), piu' veloce, con cassa e basso continuo
    battle = make_track({ { 164.8, 196, 246.9 }, { 130.8, 164.8, 196 }, { 146.8, 185, 220 }, { 123.5, 155.6, 185 } },
      144, { kick = true, drive = true, lead = 0.035, duty = 0.125 }),
  }
  Audio.track_vol = { menu = 0, battle = 0 }
  Audio.music = Audio.tracks.menu
end

-- da chiamare ogni frame: mode "menu", "battle" o nil (silenzio). fast: morte improvvisa.
function Audio.update_music(dt, mode, fast, paused)
  if not Audio.tracks or not Audio.enabled then return end
  for name, src in pairs(Audio.tracks) do
    local target = 0
    if name == mode then target = Audio.music_mul * (name == "battle" and (paused and 0.25 or 0.6) or 1) end
    local v = Audio.track_vol[name] + (target - Audio.track_vol[name]) * math.min(1, dt * 2)
    Audio.track_vol[name] = v
    if v > 0.01 then
      if not src:isPlaying() then src:play() end
      src:setVolume(v)
      if name == "battle" then src:setPitch(fast and 1.12 or 1) end
    elseif src:isPlaying() then
      src:pause()
    end
  end
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
  if Audio.sfx_vol <= 0 then return end
  c:setVolume((volume or 0.8) * Audio.sfx_vol)
  c:play()
  Audio.active[#Audio.active + 1] = c
end

return Audio
