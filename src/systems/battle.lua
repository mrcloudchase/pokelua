-- The battle engine has no LÖVE dependency: all turns can be simulated in plain Lua.
local Data = require('src.data.creatures')
local Creature = require('src.systems.creature')
local B = {}
local matchup = {
  Leaf={Tide=2,Stone=2,Ember=0.5,Gale=0.5,Frost=0.5},
  Ember={Leaf=2,Frost=2,Tide=0.5,Stone=0.5},
  Tide={Ember=2,Stone=2,Leaf=0.5,Spark=0.5},
  Stone={Ember=2,Spark=2,Gale=2,Leaf=0.5,Tide=0.5},
  Gale={Leaf=2,Stone=0.5,Spark=0.5,Frost=0.5},
  Spark={Tide=2,Gale=2,Stone=0.5,Leaf=0.5},
  Shade={Astral=2,Shade=0.5,Ember=0.5},
  Frost={Leaf=2,Gale=2,Ember=0.5,Stone=0.5},
  Astral={Shade=2,Stone=0.5,Astral=0.5},
  Neutral={}
}
function B.effectiveness(attackType,defendType)
  return (matchup[attackType] or {})[defendType] or 1
end
local function log(s,message) s.log[#s.log+1]=message end
local function random(s)
  local n=s.rng()
  if type(n)~='number' then return 0.5 end
  return math.max(0,math.min(0.999999,n))
end
local function append(s,messages) for _,m in ipairs(messages) do log(s,m) end end
function B.new(party,enemies,opts)
  opts=opts or {}
  assert(type(party)=='table' and #party>0,'Battle needs a party')
  assert(type(enemies)=='table' and #enemies>0,'Battle needs an opponent')
  local s={party=party,enemies=enemies,active=Creature.firstAlive(party) or 1,
    enemyActive=Creature.firstAlive(enemies) or 1,log={},outcome=nil,turn=0,
    caught=nil,reward=opts.reward or 0,wild=opts.wild~=false,rng=opts.rng or math.random,
    trainerName=opts.trainerName,bossId=opts.bossId,guards={},rewarded={},runAttempts=0}
  if not Creature.firstAlive(party) then s.outcome='lose'
  elseif not Creature.firstAlive(enemies) then s.outcome='win' end
  local opponent=enemies[s.enemyActive]
  if s.wild then log(s,'A wild '..Creature.name(opponent)..' appeared!')
  else log(s,(s.trainerName or 'A traveler')..' challenges you!') end
  return s
end
local function awardXP(s,enemy,catch)
  local amount=catch and (enemy.level*10+12) or (enemy.level*24+24)
  for i,c in ipairs(s.party) do
    if c.hp>0 then
      local xp=math.floor(amount*(i==s.active and 1 or 0.75))
      log(s,Creature.name(c)..' gained '..xp..' experience.')
      append(s,Creature.gainXP(c,xp))
    end
  end
end
local function resolve(s)
  local enemy=s.enemies[s.enemyActive]
  if enemy.hp<=0 and not s.rewarded[s.enemyActive] then
    s.rewarded[s.enemyActive]=true
    log(s,Creature.name(enemy)..' is out of energy!')
    awardXP(s,enemy,false)
  end
  local nextEnemy=Creature.firstAlive(s.enemies)
  local nextAlly=Creature.firstAlive(s.party)
  if not nextAlly then
    s.outcome='lose'
    log(s,'Your companions need a rest. Return to a sanctuary.')
  elseif not nextEnemy then
    s.outcome='win'
    log(s,s.wild and 'The wild encounter is over!' or 'Victory! Your bond shines brighter.')
  else
    if s.enemies[s.enemyActive].hp<=0 then
      s.enemyActive=nextEnemy
      log(s,(s.trainerName or 'Your opponent')..' sends out '..Creature.name(s.enemies[nextEnemy])..'!')
    end
    if s.party[s.active].hp<=0 then
      local old=s.party[s.active]
      s.active=nextAlly
      log(s,Creature.name(old)..' needs a rest. Go, '..Creature.name(s.party[nextAlly])..'!')
    end
  end
end
local function technique(s,attacker,defender,id)
  if attacker.hp<=0 or defender.hp<=0 then return end
  local move=Data.moves[id]
  log(s,Creature.name(attacker)..' used '..move.name..'!')
  if move.kind=='heal' then
    local maximum=Creature.stats(attacker).hp
    local healed=math.min(maximum-attacker.hp,math.max(1,math.floor(maximum*0.38)))
    attacker.hp=attacker.hp+healed
    log(s,Creature.name(attacker)..' recovered '..healed..' energy.')
    return
  elseif move.kind=='guard' then
    s.guards[attacker]=true
    log(s,Creature.name(attacker)..' braces against the next attack.')
    return
  end
  if random(s)>move.accuracy then log(s,'The technique missed!'); return end
  local atk,def=Creature.stats(attacker),Creature.stats(defender)
  local effectiveness=B.effectiveness(move.type,Data.species[defender.species].type)
  local sameType=Data.species[attacker.species].type==move.type and 1.15 or 1
  local variance=0.90+random(s)*0.20
  local damage=math.floor(((2*attacker.level/5+2)*move.power*atk.attack/math.max(1,def.defense)/12+3)*sameType*effectiveness*variance)
  if s.guards[defender] then
    damage=math.floor(damage*0.35)
    s.guards[defender]=nil
    log(s,'Shelter softened the blow!')
  end
  damage=math.max(1,math.min(defender.hp,damage))
  defender.hp=math.max(0,defender.hp-damage)
  log(s,Creature.name(defender)..' lost '..damage..' energy.')
  if effectiveness>1 then log(s,'A powerful elemental match!')
  elseif effectiveness<1 then log(s,'The element was resisted.') end
  if move.effect=='drain' and attacker.hp>0 then
    local healed=math.min(atk.hp-attacker.hp,math.max(1,math.floor(damage*0.45)))
    attacker.hp=attacker.hp+healed
    if healed>0 then log(s,Creature.name(attacker)..' drew back '..healed..' energy.') end
  elseif move.effect=='recoil' then
    local recoil=math.max(1,math.floor(damage*0.18))
    attacker.hp=math.max(0,attacker.hp-recoil)
    log(s,Creature.name(attacker)..' took '..recoil..' recoil energy.')
  end
end
local function chooseEnemyMove(s,enemy,ally)
  local candidates={}
  for _,id in ipairs(enemy.moves) do
    local m=Data.moves[id]
    local score=1
    if m.kind=='damage' then
      score=(m.power or 1)*B.effectiveness(m.type,Data.species[ally.species].type)
      if m.type==Data.species[enemy.species].type then score=score*1.15 end
      score=score*(0.75+random(s)*0.5)
    elseif m.kind=='heal' then
      score=enemy.hp<Creature.stats(enemy).hp*0.4 and 90 or -1
    elseif m.kind=='guard' then
      score=(not s.guards[enemy] and s.turn%4==0) and 55 or -1
    end
    candidates[#candidates+1]={id=id,score=score}
  end
  table.sort(candidates,function(a,b) return a.score>b.score end)
  return candidates[1] and candidates[1].id or 'nudge'
end
local function fail(s,message) s.log={message}; return false end
function B.act(s,action,bag)
  if s.outcome then return false end
  if type(action)~='table' then return fail(s,'Choose an action.') end
  bag=bag or {}
  local ally,enemy=s.party[s.active],s.enemies[s.enemyActive]
  local kind=action.kind
  local move
  -- Validate before consuming resources, time, or random numbers.
  if kind=='move' then
    local index=action.index
    if type(index)~='number' or index%1~=0 or not ally.moves[index] then return fail(s,'Choose a technique from your companion’s list.') end
    move=Data.moves[ally.moves[index]]
    if not move then return fail(s,'That technique is unavailable.') end
    if move.kind=='heal' and ally.hp>=Creature.stats(ally).hp then return fail(s,Creature.name(ally)..' is already at full energy.') end
  elseif kind=='catch' then
    if not s.wild then return fail(s,'A traveler’s companion cannot be bonded.') end
    if (bag.orbs or 0)<1 then return fail(s,'You have no bond orbs left. Visit a supply stall.') end
  elseif kind=='item' then
    if action.item~='tonic' then return fail(s,'That item cannot be used in battle.') end
    if (bag.tonics or 0)<1 then return fail(s,'You have no tonics left.') end
    if ally.hp>=Creature.stats(ally).hp then return fail(s,Creature.name(ally)..' is already at full energy.') end
  elseif kind=='switch' then
    local index=action.index
    if type(index)~='number' or index%1~=0 or not s.party[index] then return fail(s,'Choose a companion in your party.') end
    if index==s.active then return fail(s,'That companion is already in battle.') end
    if s.party[index].hp<=0 then return fail(s,'That companion needs a sanctuary rest.') end
  elseif kind=='run' then
    if not s.wild then return fail(s,'Finish this challenge before leaving.') end
  else return fail(s,'Choose an action.') end
  s.log={}
  s.turn=s.turn+1
  if kind=='catch' then
    bag.orbs=bag.orbs-1
    log(s,'You cast a bond orb toward '..Creature.name(enemy)..'...')
    local health=enemy.hp/Creature.stats(enemy).hp
    local chance=math.max(0.12,math.min(0.95,0.22+(1-health)*0.70+(ally.level-enemy.level)*0.018))
    if enemy.species=='aetherion' then chance=chance*0.72 end
    if random(s)<chance then
      s.caught=enemy
      s.outcome='caught'
      log(s,'A new bond! '..Creature.name(enemy)..' joined your journey!')
      awardXP(s,enemy,true)
      return true
    else log(s,Creature.name(enemy)..' slipped free! Weaken it to strengthen your bond.') end
  elseif kind=='item' then
    bag.tonics=bag.tonics-1
    local healed=math.min(35,Creature.stats(ally).hp-ally.hp)
    ally.hp=ally.hp+healed
    log(s,'A tonic restored '..healed..' energy to '..Creature.name(ally)..'.')
  elseif kind=='switch' then
    s.active=action.index
    ally=s.party[s.active]
    log(s,'Come back! Go, '..Creature.name(ally)..'!')
  elseif kind=='run' then
    s.runAttempts=s.runAttempts+1
    local chance=0.68+(Creature.stats(ally).speed-Creature.stats(enemy).speed)*0.012+(s.runAttempts-1)*0.16
    if random(s)<chance then s.outcome='fled'; log(s,'You found a safe path away.'); return true
    else log(s,'You could not get away!') end
  end
  local enemyId=chooseEnemyMove(s,enemy,ally)
  if kind=='move' then
    local playerId=ally.moves[action.index]
    local pSpeed=Creature.stats(ally).speed+(move.effect=='quick' and 1000 or 0)
    local eMove=Data.moves[enemyId]
    local eSpeed=Creature.stats(enemy).speed+(eMove.effect=='quick' and 1000 or 0)
    if pSpeed>=eSpeed then
      technique(s,ally,enemy,playerId)
      technique(s,enemy,ally,enemyId)
    else
      technique(s,enemy,ally,enemyId)
      technique(s,ally,enemy,playerId)
    end
  else technique(s,enemy,ally,enemyId) end
  resolve(s)
  return true
end
return B
