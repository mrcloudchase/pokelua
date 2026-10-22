-- Safe, deterministic saves. No loadstring, executable Lua, or external dependency.
local Save = {}
local path, useIO = 'journey.pokelua', false
local MAGIC = 'POKELUA-SAVE/1\n'
local MAX_BYTES, MAX_DEPTH, MAX_ENTRIES = 2 * 1024 * 1024, 48, 60000

local function checksum(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return string.format('%08x', b * 65536 + a)
end

function Save.encode(state)
  assert(type(state) == 'table', 'Save root must be a table')
  local pieces, visiting, count, bytes = {}, {}, 0, 0
  local function emit(s)
    bytes = bytes + #s
    assert(bytes <= MAX_BYTES, 'Save is too large')
    pieces[#pieces + 1] = s
  end
  local encode
  encode = function(value, depth)
    assert(depth <= MAX_DEPTH, 'Save nesting is too deep')
    local kind = type(value)
    if kind == 'string' then
      emit('s' .. #value .. ':' .. value)
    elseif kind == 'number' then
      assert(value == value and value ~= math.huge and value ~= -math.huge, 'Non-finite save number')
      emit('n' .. string.format('%.17g', value) .. ';')
    elseif kind == 'boolean' then
      emit(value and 'b1' or 'b0')
    elseif kind == 'table' then
      assert(not getmetatable(value), 'Save tables cannot have metatables')
      assert(not visiting[value], 'Cyclic save table')
      visiting[value] = true
      local keys = {}
      for key in pairs(value) do
        assert(type(key) == 'string' or type(key) == 'number', 'Unsupported save key')
        if type(key) == 'number' then
          assert(key == key and key ~= math.huge and key ~= -math.huge, 'Invalid save key')
        end
        keys[#keys + 1] = key
      end
      table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        return a < b
      end)
      count = count + #keys
      assert(count <= MAX_ENTRIES, 'Save has too many entries')
      emit('t' .. #keys .. ':')
      for _, key in ipairs(keys) do
        encode(key, depth + 1)
        encode(value[key], depth + 1)
      end
      visiting[value] = nil
    else
      error('Unsupported save value: ' .. kind)
    end
  end
  encode(state, 0)
  local body = table.concat(pieces)
  return MAGIC .. checksum(body) .. '\n' .. body
end

function Save.decode(encoded)
  if type(encoded) ~= 'string' then return nil, 'Save data must be text' end
  if #encoded > MAX_BYTES + #MAGIC + 9 then return nil, 'Save is too large' end
  local function parse()
    assert(encoded:sub(1, #MAGIC) == MAGIC, 'Unrecognized save format')
    local headerEnd = #MAGIC + 9
    local expected = encoded:sub(#MAGIC + 1, #MAGIC + 8)
    assert(expected:match('^[0-9a-f]+$') and encoded:sub(headerEnd, headerEnd) == '\n', 'Malformed save header')
    local body = encoded:sub(headerEnd + 1)
    assert(checksum(body) == expected, 'Save checksum failed')
    local position, count = 1, 0
    local function takeLength()
      local ending = body:find(':', position, true)
      assert(ending and ending - position <= 9, 'Invalid save length')
      local token = body:sub(position, ending - 1)
      assert(token:match('^%d+$'), 'Invalid save length')
      local length = tonumber(token)
      assert(length and length <= MAX_BYTES, 'Save length is too large')
      position = ending + 1
      return length
    end
    local decode
    decode = function(depth)
      assert(depth <= MAX_DEPTH, 'Save nesting is too deep')
      local tag = body:sub(position, position)
      position = position + 1
      if tag == 's' then
        local length = takeLength()
        assert(position + length - 1 <= #body, 'Truncated save string')
        local value = body:sub(position, position + length - 1)
        position = position + length
        return value
      elseif tag == 'n' then
        local ending = body:find(';', position, true)
        assert(ending and ending - position <= 32, 'Invalid save number')
        local token = body:sub(position, ending - 1)
        assert(token:match('^[%+%-%.%deE]+$'), 'Invalid save number')
        local number = tonumber(token)
        assert(number and number == number and number ~= math.huge and number ~= -math.huge, 'Invalid save number')
        position = ending + 1
        return number
      elseif tag == 'b' then
        local token = body:sub(position, position)
        assert(token == '0' or token == '1', 'Invalid save boolean')
        position = position + 1
        return token == '1'
      elseif tag == 't' then
        local length, result, keys = takeLength(), {}, {}
        count = count + length
        assert(count <= MAX_ENTRIES, 'Save has too many entries')
        for _ = 1, length do
          local key = decode(depth + 1)
          assert(type(key) == 'string' or type(key) == 'number', 'Invalid save key')
          assert(not keys[key], 'Duplicate save key')
          keys[key] = true
          result[key] = decode(depth + 1)
        end
        return result
      end
      error('Invalid save token')
    end
    local state = decode(0)
    assert(type(state) == 'table', 'Save root must be a table')
    assert(position == #body + 1, 'Unexpected trailing save data')
    return state
  end
  local ok, result = pcall(parse)
  if not ok then return nil, tostring(result):gsub('^.-:%d+: ', '') end
  return result
end

function Save.configure(options)
  options = options or {}
  if options.path then
    assert(type(options.path) == 'string' and #options.path > 0, 'Save path must be text')
    path, useIO = options.path, options.backend ~= 'love'
  else
    path, useIO = 'journey.pokelua', options.backend == 'io'
  end
end

local function loveFS()
  return not useIO and love and love.filesystem
end

local function readFile(file)
  if loveFS() then
    local info = love.filesystem.getInfo(file)
    if not info then return nil, 'No save file' end
    if info.size and info.size > MAX_BYTES + 100 then return nil, 'Save is too large' end
    return love.filesystem.read(file)
  end
  local handle, err = io.open(file, 'rb')
  if not handle then return nil, err end
  local data = handle:read(MAX_BYTES + 101)
  handle:close()
  if data and #data > MAX_BYTES + 100 then return nil, 'Save is too large' end
  return data
end

local function writeFile(file, data)
  if loveFS() then return love.filesystem.write(file, data) end
  local handle, err = io.open(file, 'wb')
  if not handle then return nil, err end
  local ok, writeErr = handle:write(data)
  local closed, closeErr = handle:close()
  if not ok or not closed then return nil, writeErr or closeErr end
  return true
end

local function removeFile(file)
  if loveFS() then
    if not love.filesystem.getInfo(file) then return true end
    return love.filesystem.remove(file)
  end
  local handle = io.open(file, 'rb')
  if not handle then return true end
  handle:close()
  return os.remove(file)
end

local function replaceFile(from, to)
  -- LÖVE exposes a writable per-game directory; os.rename makes promotion atomic.
  if loveFS() then
    local root = love.filesystem.getSaveDirectory()
    local source, destination = root .. '/' .. from, root .. '/' .. to
    local ok, err = os.rename(source, destination)
    -- Windows cannot rename over an existing file. The verified backup remains
    -- recoverable during this short promotion gap.
    if not ok and package.config:sub(1, 1) == '\\' then
      os.remove(destination)
      ok, err = os.rename(source, destination)
    end
    if not ok then return nil, err end
    return true
  end
  local ok, err = os.rename(from, to)
  if not ok and package.config:sub(1, 1) == '\\' then
    os.remove(to)
    ok, err = os.rename(from, to)
  end
  return ok, err
end

function Save.save(state)
  local ok, encoded = pcall(Save.encode, state)
  if not ok then return nil, tostring(encoded) end
  local written, err = writeFile(path .. '.tmp', encoded)
  if not written then return nil, err or 'Could not write save' end
  -- Verify the bytes before touching the current save.
  local pending = readFile(path .. '.tmp')
  if not pending or not Save.decode(pending) then return nil, 'Could not verify save' end
  local previous = readFile(path)
  if previous and Save.decode(previous) then
    local backed, backupErr = writeFile(path .. '.bak', previous)
    if not backed then return nil, backupErr or 'Could not back up save' end
  end
  local promoted, promoteErr = replaceFile(path .. '.tmp', path)
  if not promoted then return nil, promoteErr or 'Could not promote save' end
  return true
end

function Save.load()
  local primary, readErr = readFile(path)
  local state, decodeErr
  if primary then state, decodeErr = Save.decode(primary) end
  if state then return state end
  local backup = readFile(path .. '.bak')
  if backup then
    local restored = Save.decode(backup)
    if restored then return restored, 'Recovered previous save from backup' end
  end
  -- A complete temporary file is useful if power was lost before promotion.
  local pending = readFile(path .. '.tmp')
  if pending then
    local recovered = Save.decode(pending)
    if recovered then return recovered, 'Recovered interrupted save' end
  end
  return nil, decodeErr or readErr or 'No valid save file'
end

function Save.exists()
  -- A recoverable backup counts as a continuable journey.
  return Save.load() ~= nil
end

function Save.delete()
  local ok, err = removeFile(path)
  local backup, backupErr = removeFile(path .. '.bak')
  local pending, pendingErr = removeFile(path .. '.tmp')
  if not ok or not backup or not pending then return nil, err or backupErr or pendingErr end
  return true
end

return Save
