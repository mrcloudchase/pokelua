-- Headless integration checks for campaign, economy, and persisted gameplay state.
return function()
  local Data = require('src.data.creatures')
  local Creature = require('src.systems.creature')
  local World = require('src.data.world')
  local Save = require('src.systems.save')
  local originals = {love = love, screens = package.loaded['src.render.screens'], audio = package.loaded['src.systems.audio'], game = package.loaded['src.game']}
  local silent = {init = function() end, play = function() end, update = function() end, setMuted = function() end, isMuted = function() return true end}
  local order = {}; for id in pairs(Data.species) do order[#order + 1] = id end
  package.loaded['src.render.screens'] = {speciesOrder = order, draw = function() end}
  package.loaded['src.systems.audio'] = silent
  package.loaded['src.game'] = nil
  love = {keyboard = {isDown = function() return false end}}
  local file = os.tmpname(); os.remove(file); Save.configure({path = file})
  local checks = 0
  local function check(value, message) checks = checks + 1; assert(value, message) end
  local function run()
    local Game = require('src.game')
    local g = Game.new()
    check(g.scene == 'title' and not g.hasSave, 'An empty slot starts at the title')
    g:startNew()
    check(g.scene == 'starter' and #g.state.party == 0, 'New journey requires starter selection')
    g:chooseStarter(1)
    check(g.scene == 'world' and g.dialogue ~= nil, 'Starter selection begins the introduction')
    check(#g.state.party == 1 and g.state.party[1].species == Data.starters[1], 'Chosen starter joins party')
    check(g.state.seen[Data.starters[1]] and g.state.caught[Data.starters[1]], 'Starter is recorded in journal')
    check(Save.exists(), 'Starter selection autosaves')
    local before = g.state.steps; g.moveCooldown = 0; g:move('right')
    check(g.state.steps == before, 'Dialogue blocks field movement')
    while g.dialogue do g:advanceDialogue() end
    g.state.party[1].hp = 1
    g:heal()
    check(g.state.party[1].hp == Creature.stats(g.state.party[1]).hp, 'Caretakers fully restore the party')
    local money, orbs = g.state.money, g.state.bag.orbs
    g:buy(1)
    check(g.state.money == money - 25 and g.state.bag.orbs == orbs + 1, 'Shop charges once and adds one orb')
    g.state.money = 0; orbs = g.state.bag.orbs; g:buy(1)
    check(g.state.money == 0 and g.state.bag.orbs == orbs, 'An unaffordable purchase changes no resources')
    local tonics = g.state.bag.tonics
    g:useTonic(1)
    check(g.state.bag.tonics == tonics, 'A full-health companion does not consume a tonic')
    g.state.party[1].hp = 1; g:useTonic(1)
    check(g.state.party[1].hp == 36 and g.state.bag.tonics == tonics - 1, 'Field tonic restores 35 HP and consumes one')
    for i = 2, 6 do g:addCompanion(Creature.create('budpip', 3)) end
    check(#g.state.party == 6 and #g.state.storage == 0, 'Party fills before sanctuary storage')
    g:addCompanion(Creature.create('sparkit', 4))
    check(#g.state.party == 6 and #g.state.storage == 1, 'The seventh companion enters sanctuary storage')
    g.scene = 'journal';g.journalTab = 1;g.storageMode = true;g.selectedParty = 2
    g:journalAction(1)
    check(g.state.party[2].species == 'sparkit' and g.state.storage[1].species == 'budpip', 'Sanctuary exchange preserves both companions')
    g.scene = 'journal';g.journalTab = 4;g:journalAction(6)
    check(g.state.player.zone == World.start.zone, 'Unvisited regions cannot be reached by fast travel')
    g.state.money = 100;for _,c in ipairs(g.state.party) do c.hp = 0 end
    g:rescue()
    check(g.state.money == 90 and g.state.player.zone == World.start.zone, 'Rescue charges ten percent and returns home')
    check(Creature.firstAlive(g.state.party) == 1, 'Rescue guarantees a healthy party')
    while g.dialogue do g:advanceDialogue() end
    -- Complete every warden through the same reward transition used by combat.
    for index, boss in ipairs(World.bosses) do
      local npc
      for _,entry in ipairs(World.zones[boss.zone].npcs) do if entry.bossIndex == index then npc = entry end end
      check(npc ~= nil, 'Each campaign warden has a battle NPC')
      if index > 1 then check(g:badgeCount() == index - 1, 'Campaign seals remain sequential') end
      g:startTrainer(npc)
      check(g.battle and not g.battle.wild, 'A warden starts a trainer battle')
      g.battle.outcome = 'win';local crowns = g.state.money;local startingOrbs = g.state.bag.orbs
      g:finishBattle()
      check(g:badgeCount() == index and g.state.defeated[npc.id], 'Warden victory records one seal and defeat')
      check(g.state.money == crowns + npc.reward and g.state.bag.orbs == startingOrbs + 4, 'Warden rewards are credited once')
      check(g.state.party[1].hp == Creature.stats(g.state.party[1]).hp, 'Warden victory restores party health')
      while g.dialogue do g:advanceDialogue() end
      if index < 4 then check(g.scene == 'world', 'Early wardens return to exploration') end
    end
    check(g.state.ending and g.scene == 'ending', 'Fourth warden completes the campaign')
    g:keypressed('return')
    check(g.scene == 'world', 'Completed journey remains explorable')
    local fourth = World.bosses[4];local oldCrowns = g.state.money
    local finalNPC
    for _,npc in ipairs(World.zones[fourth.zone].npcs) do if npc.bossIndex == 4 then finalNPC = npc end end
    g:interactNPC(finalNPC)
    while g.dialogue do g:advanceDialogue() end
    check(g.scene == 'world' and g.state.money == oldCrowns and g:badgeCount() == 4, 'Defeated wardens cannot award duplicate rewards')
    local function fresh() return assert(Save.decode(Save.encode(g.state))) end
    local valid = fresh()
    check(g:validateState(valid), 'A complete campaign roundtrips through state validation')
    local invalid = fresh();invalid.version = 999
    check(not g:validateState(invalid), 'Unknown save versions are rejected')
    invalid = fresh();invalid.party[1].species = 'missing'
    check(not g:validateState(invalid), 'Unknown saved species are rejected')
    invalid = fresh();invalid.party[1].moves = {'missing'}
    check(not g:validateState(invalid), 'Unknown saved moves are rejected')
    invalid = fresh();invalid.player.zone = 'missing'
    check(not g:validateState(invalid), 'Unknown saved zones are rejected')
    for _,field in ipairs({'storage', 'bag'}) do
      for _,badValue in ipairs({42, 'malformed', true}) do
        invalid = fresh();invalid[field] = badValue
        local ok, result = pcall(g.validateState, g, invalid)
        check(ok, 'Malformed '..field..' must not crash validation')
        check(not result, 'Malformed '..field..' must be rejected')
      end
    end
    invalid = fresh();invalid.party[1].nickname = true
    local ok, result = pcall(g.validateState, g, invalid)
    check(ok and (not result or type(Creature.name(result.party[1])) == 'string'), 'Saved nicknames cannot break text rendering')
    -- An old encounter cooldown must not survive a fresh journey.
    g.lastEncounter = 5000;g:startNew()
    check(not g.lastEncounter or g.lastEncounter <= g.state.steps, 'New journeys reset the wild-encounter step cooldown')
    return checks
  end
  local ok, result = pcall(run)
  Save.delete();Save.configure()
  love = originals.love
  package.loaded['src.render.screens'] = originals.screens
  package.loaded['src.systems.audio'] = originals.audio
  package.loaded['src.game'] = originals.game
  if not ok then error(result, 0) end
  return result
end
