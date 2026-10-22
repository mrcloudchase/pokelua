local Data = require('src.data.creatures')
local C = {MAX_LEVEL = 50}
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
function C.stats(c)
  local s = assert(Data.species[c.species], 'Unknown species: '..tostring(c.species))
  local l = c.level or 1
  return {hp=s.base.hp+l*4,attack=s.base.attack+l*2,defense=s.base.defense+l*2,speed=s.base.speed+l*2}
end
function C.name(c) return c.nickname or Data.species[c.species].name end
function C.xpNeeded(level) return 22 + level*18 end
local function knownMoves(id,level)
  local moves, seen = {}, {}
  for _,entry in ipairs(Data.species[id].learnset) do
    if entry[1] <= level and not seen[entry[2]] then
      seen[entry[2]] = true
      moves[#moves+1] = entry[2]
      if #moves > 4 then table.remove(moves,1) end
    end
  end
  return moves
end
function C.create(id,level,rng)
  assert(Data.species[id], 'Unknown species: '..tostring(id))
  local c = {species=id,level=clamp(math.floor(level or 1),1,C.MAX_LEVEL),xp=0}
  c.moves=knownMoves(id,c.level)
  c.hp=C.stats(c).hp
  return c
end
function C.heal(c) c.hp=C.stats(c).hp; return c end
function C.firstAlive(party)
  for i,c in ipairs(party) do if c.hp>0 then return i end end
end
function C.gainXP(c,amount)
  local messages={}
  if c.level>=C.MAX_LEVEL then c.xp=0; return messages end
  c.xp=(c.xp or 0)+math.max(0,math.floor(amount or 0))
  while c.level<C.MAX_LEVEL and c.xp>=C.xpNeeded(c.level) do
    local oldHP=C.stats(c).hp
    c.xp=c.xp-C.xpNeeded(c.level)
    c.level=c.level+1
    messages[#messages+1]=C.name(c)..' reached level '..c.level..'!'
    local evolution=Data.species[c.species].evolution
    if evolution and c.level>=evolution.level then
      local before=C.name(c)
      c.species=evolution.into
      messages[#messages+1]=before..' evolved into '..C.name(c)..'!'
    end
    if c.hp>0 then c.hp=math.min(C.stats(c).hp,c.hp+(C.stats(c).hp-oldHP)) end
    local old={}
    for _,id in ipairs(c.moves) do old[id]=true end
    c.moves=knownMoves(c.species,c.level)
    for _,id in ipairs(c.moves) do
      if not old[id] then messages[#messages+1]=C.name(c)..' learned '..Data.moves[id].name..'!' end
    end
  end
  if c.level>=C.MAX_LEVEL then c.xp=0 end
  return messages
end
return C
