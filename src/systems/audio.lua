-- All sounds are synthesized here; no recordings, samples, or external assets.
local Audio = {}
local ready, muted, initialized = false, false, false
local sounds, notes, voices = {}, {}, {}
local clock, step, mode = 0, 0, 'title'
local SAMPLE_RATE, BEAT = 22050, 0.26
local sequences = {
  title = {64, 71, 76, 71, 67, 74, 79, 74, 62, 69, 74, 69, 60, 67, 72, 67},
  overworld = {60, 67, 72, 76, 62, 69, 74, 77, 64, 71, 76, 79, 62, 69, 74, 77},
  battle = {57, 64, 69, 72, 57, 67, 72, 76, 53, 60, 65, 69, 55, 62, 67, 71},
  ending = {60, 64, 67, 72, 65, 69, 72, 77, 67, 71, 74, 79, 60, 67, 72, 84}
}
local function frequency(note) return 440 * 2 ^ ((note - 69) / 12) end

local function tone(pitch, length, flavor, volume, endPitch)
  local data = love.sound.newSoundData(math.floor(length * SAMPLE_RATE), SAMPLE_RATE, 16, 1)
  local phase = 0
  for i = 0, data:getSampleCount() - 1 do
    local t = i / SAMPLE_RATE
    local progress = t / length
    local hz = endPitch and (pitch + (endPitch - pitch) * progress) or pitch
    phase = phase + hz / SAMPLE_RATE
    local wave
    if flavor == 'pluck' then
      wave = math.sin(phase * math.pi * 2) * 0.76 + math.sin(phase * math.pi * 4) * 0.16 + math.sin(phase * math.pi * 6) * 0.08
    elseif flavor == 'soft' then
      wave = math.sin(phase * math.pi * 2) * 0.88 + math.sin(phase * math.pi * 4) * 0.12
    else
      wave = (2 / math.pi) * math.asin(math.sin(phase * math.pi * 2))
    end
    local attack = math.min(1, t / 0.008)
    local release = math.min(1, (length - t) / math.min(0.09, length * 0.4))
    local envelope = attack * release * (flavor == 'pluck' and math.exp(-progress * 4.4) or 1)
    data:setSample(i, wave * envelope * (volume or 0.2))
  end
  return love.audio.newSource(data, 'static')
end

local function effect(pitches, length, volume)
  local segment = length / #pitches
  local data = love.sound.newSoundData(math.floor(length * SAMPLE_RATE), SAMPLE_RATE, 16, 1)
  for i = 0, data:getSampleCount() - 1 do
    local t = i / SAMPLE_RATE
    local slot = math.min(#pitches, math.floor(t / segment) + 1)
    local localTime = t - (slot - 1) * segment
    local p = localTime / segment
    local envelope = math.min(1, localTime / 0.004) * math.min(1, (segment - localTime) / 0.015)
    local phase = frequency(pitches[slot]) * localTime
    local sample = math.sin(phase * math.pi * 2) * 0.8 + math.sin(phase * math.pi * 4) * 0.2
    data:setSample(i, sample * envelope * math.exp(-p * 1.4) * (volume or 0.24))
  end
  return love.audio.newSource(data, 'static')
end

function Audio.init()
  if initialized then return ready end
  initialized = true
  if not (love and love.audio and love.sound) then return false end
  local ok = pcall(function()
    sounds.move = tone(150, 0.035, 'soft', 0.055, 110)
    sounds.confirm = effect({72, 79}, 0.12, 0.2)
    sounds.cancel = effect({67, 60}, 0.12, 0.15)
    sounds.hit = tone(120, 0.13, 'triangle', 0.21, 42)
    sounds.catch = effect({64, 67, 71, 76, 83}, 0.48, 0.24)
    sounds.win = effect({60, 64, 67, 72, 76, 79, 84}, 0.85, 0.24)
    sounds.heal = effect({72, 76, 79, 84}, 0.45, 0.2)
    -- Prebuild a small instrument bank, so gameplay doesn't allocate sound data.
    for note = 36, 84 do
      notes[note] = tone(frequency(note), 1.15, 'pluck', 0.14)
    end
    ready = true
  end)
  if not ok then ready = false; sounds, notes = {}, {} end
  return ready
end

local function trigger(source, volume)
  if not source or not ready or muted then return end
  local ok = pcall(function()
    local voice = source:clone()
    if volume then voice:setVolume(volume) end
    voice:play()
    voices[#voices + 1] = voice
  end)
  if not ok then ready = false end
end

function Audio.play(event)
  if not initialized then Audio.init() end
  trigger(sounds[event])
end

function Audio.update(dt, requestedMode)
  if not initialized then Audio.init() end
  if not ready then return end
  local nextMode = requestedMode or 'overworld'
  if nextMode == 'world' or nextMode == 'field' or nextMode == 'journal' then nextMode = 'overworld' end
  if nextMode == 'credits' then nextMode = 'ending' end
  if not sequences[nextMode] then nextMode = 'overworld' end
  if nextMode ~= mode then
    mode, step, clock = nextMode, 0, 0
    for _, source in ipairs(voices) do pcall(source.stop, source) end
    voices = {}
  end
  for i = #voices, 1, -1 do
    local ok, playing = pcall(voices[i].isPlaying, voices[i])
    if not ok or not playing then table.remove(voices, i) end
  end
  if muted then return end
  clock = clock + math.min(dt or 0, 0.25)
  local beat = mode == 'battle' and BEAT * 0.72 or BEAT * 1.16
  if clock < beat then return end
  clock = clock - beat
  step = step + 1
  local sequence = sequences[mode]
  local index = (step - 1) % #sequence + 1
  trigger(notes[sequence[index]], mode == 'battle' and 0.72 or 0.65)
  if index % 4 == 1 then
    trigger(notes[sequence[index] - 24], 0.65)
    trigger(notes[sequence[index] - 12], 0.23)
  end
end

function Audio.setMuted(value)
  muted = not not value
  if muted then
    for _, voice in ipairs(voices) do pcall(voice.stop, voice) end
    voices = {}
  end
end

function Audio.isMuted() return muted end
return Audio
