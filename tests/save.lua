-- Run with require('tests.save')(). The codec never executes file contents.
return function()
  local Save = require('src.systems.save')
  local checks = 0
  local function check(value, message)
    checks = checks + 1
    assert(value, message)
  end
  local state = {
    version = 1, player = {zone = 'hearth', x = 7, y = 9, direction = 'down'},
    party = {{species = 'spriglet', hp = 27, level = 4, xp = 12, moves = {'tackle', 'leafcut'}}},
    storage = {}, bag = {orbs = 8, tonics = 3}, money = 215,
    badges = {'hearth'}, defeated = {warden_iris = true}, seen = {spriglet = true},
    caught = {spriglet = true}, starter = 'spriglet', steps = 139,
    playtime = 91.25, ending = false, text = 'PokéLua\n:;\000\255'
  }
  local encoded = Save.encode(state)
  local decoded, err = Save.decode(encoded)
  check(decoded and not err, 'Roundtrip must decode')
  check(decoded.player.zone == 'hearth' and decoded.player.x == 7, 'Nested state roundtrip')
  check(decoded.party[1].moves[2] == 'leafcut', 'Arrays roundtrip')
  check(decoded.ending == false and decoded.defeated.warden_iris, 'Boolean roundtrip')
  check(decoded.text == state.text, 'Arbitrary string bytes roundtrip')
  check(decoded.playtime == 91.25, 'Fractional numbers roundtrip')
  check(Save.encode(decoded) == encoded, 'Encoding is deterministic')
  local sparse = Save.decode(Save.encode({[1] = 'one', [9] = 'nine', name = 'mixed'}))
  check(sparse[9] == 'nine' and sparse.name == 'mixed', 'Sparse and mixed keys roundtrip')
  local reverse = {z = 2, a = 1}
  check(Save.encode(reverse) == Save.encode({a = 1, z = 2}), 'Map insertion order is irrelevant')
  check(not Save.decode(encoded:sub(1, -2)), 'Truncation must fail')
  check(not Save.decode(encoded:gsub('spriglet', 'cindercub')), 'Tampering must fail checksum')
  check(not Save.decode(encoded .. 't0:'), 'Trailing bytes must fail')
  check(not Save.decode('return os.execute("echo unsafe")'), 'Executable Lua must be rejected')
  check(not Save.decode(nil), 'Non-string input must be rejected')
  check(not Save.decode(string.rep('x', 2 * 1024 * 1024 + 100)), 'Oversized input must be rejected')
  local cycle = {}; cycle.self = cycle
  check(not pcall(Save.encode, cycle), 'Cycles must be rejected')
  check(not pcall(Save.encode, {bad = function() end}), 'Functions must be rejected')
  check(not pcall(Save.encode, {number = 0 / 0}), 'NaN must be rejected')
  check(not pcall(Save.encode, {number = math.huge}), 'Infinity must be rejected')
  local deep, cursor = {}, nil; cursor = deep
  for _ = 1, 60 do cursor.child = {}; cursor = cursor.child end
  check(not pcall(Save.encode, deep), 'Excessive nesting must be rejected')
  local function wrap(body)
    local a, b = 1, 0
    for i = 1, #body do a = (a + body:byte(i)) % 65521; b = (b + a) % 65521 end
    return 'POKELUA-SAVE/1\n' .. string.format('%08x', b * 65536 + a) .. '\n' .. body
  end
  check(not Save.decode(wrap('t2:s1:an1;s1:an2;')), 'Duplicate keys are rejected even with a valid checksum')
  check(not Save.decode(wrap('t1:b1n1;')), 'Boolean table keys are rejected')
  check(not Save.decode(wrap('t1:s1:an1e999;')), 'Overflowing decoded number is rejected')
  check(not Save.decode(wrap('t1:s1:as999:short')), 'Truncated inner string is rejected')
  check(not Save.decode(wrap('t999999:')), 'Excessive entry count is rejected')
  check(not Save.decode(wrap('n42;')), 'Non-table root is rejected')
  check(not Save.decode(wrap('t0:x')), 'Trailing data is rejected with valid checksum')
  check(not Save.decode(wrap(string.rep('t1:s1:a', 60) .. 't0:')), 'Excessive decoded nesting is rejected')
  local shared = {name = 'shared'}
  local repeated = Save.decode(Save.encode({one = shared, two = shared}))
  check(repeated.one.name == repeated.two.name, 'Acyclic shared tables are accepted')
  local file = os.tmpname()
  os.remove(file)
  Save.configure({path = file})
  check(not Save.exists(), 'Empty save slot must not exist')
  local ok, saveErr = Save.save(state)
  check(ok, saveErr)
  check(Save.exists(), 'Written save must exist')
  local loaded = Save.load()
  check(loaded and loaded.money == 215, 'File roundtrip')
  state.money = 999
  check(Save.save(state), 'Second save must rotate valid backup')
  loaded = Save.load()
  check(loaded and loaded.money == 999, 'Latest save is used')
  local handle = assert(io.open(file, 'wb')); handle:write('corrupted'); handle:close()
  local recovered, recoveryMessage = Save.load()
  check(recovered and recovered.money == 215, 'Corrupt save recovers previous valid backup')
  check(recoveryMessage and recoveryMessage:find('backup'), 'Recovery is reported')
  check(Save.exists(), 'Recoverable backup counts as an existing save')
  check(Save.delete(), 'Delete removes all save generations')
  check(not Save.exists(), 'Deleted slot must not exist')
  -- Simulate interruption after a verified temporary file was fully written.
  handle = assert(io.open(file .. '.tmp', 'wb')); handle:write(encoded); handle:close()
  local interrupted, interruptedMessage = Save.load()
  check(interrupted and interrupted.money == 215, 'Interrupted save can be recovered')
  check(interruptedMessage and interruptedMessage:find('interrupted'), 'Interrupted recovery is reported')
  check(Save.delete(), 'Temporary save is deleted')
  Save.configure()
  return checks
end
